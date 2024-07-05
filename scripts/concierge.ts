/* eslint-disable no-console */
import hre from 'hardhat'
import fs from 'fs'

import {OwnedNft, OwnedNftsResponse} from 'alchemy-sdk'
import {
    batchFetchClaimed,
    getDelegateAddresses,
    loadCSV,
    requestOwnerNfts,
    requestProofs
} from './concierge_helper'

const PROJECT_ID = process.env.PROJECT_ID || ''

interface ClaimData {
    recipient: string
    proof: string[]
    group: string
    data: string
    leaf: string
    amount: string
    unlockingAt: number
    expiryTimetamp: number
    index: number
    expiryTimestamp: number
}

export interface IAirdropClaim {
    claimable?: boolean
    recipient: string
    index: number
    proof: string[]
    amount: string
    unlockingAt: number
    group: string
    data: string
    leaf: string
    claimed?: boolean
    expiryTimestamp: number
    expired?: boolean
    nft?: OwnedNft
}

function chunk<T>(array: T[], chunkSize: number): T[][] {
    const chunkedArray: T[][] = []
    let index = 0

    while (index < array.length) {
        chunkedArray.push(array.slice(index, index + chunkSize))
        index += chunkSize
    }

    return chunkedArray
}

async function run() {
    const delegatedAccountPk = process.env.CONCIERGE_PRIVATE_KEY || ''
    const distributorAddress = process.env.DISTRIBUTOR_CONTRACT || ''

    const signer = new hre.ethers.Wallet(
        delegatedAccountPk,
        hre.ethers.provider
    )

    const delegatingAddresses = await getDelegateAddresses(
        signer.address as `0x${string}`
    )

    const executeTime = Date.now()
    console.log(
        `Script started for NFT airdrop claiming on behalf: project ${PROJECT_ID}, contract ${distributorAddress} @ ${executeTime}`
    )

    const csvPath = 'concierge_address.csv'
    const csvUsers = await loadCSV(csvPath)

    console.log(csvUsers)

    const userAddresses =
        delegatingAddresses?.filter((add) => csvUsers.includes(add.toLowerCase())) || []

    console.log('processing addresses', userAddresses)

    const distributor = await hre.ethers.getContractAt(
        'NFTGatedMerkleDistributor',
        distributorAddress,
        signer
    )

    const [startTime, endTime] = await distributor.getTime()

    console.log('Contract start time: ', startTime, ' end time: ', endTime)

    for (let i = 0; i < userAddresses.length; i += 1) {
        const ownedNfts = await requestOwnerNfts(
            (await signer.provider?.getNetwork())?.chainId.toString() || '1',
            userAddresses[i],
            '0x59325733eb952a92e069c87f0a6168b29e80627f' // MOCA NFT address
        )

        const tokenIDs: number[] = ownedNfts?.map((it) =>
            it.tokenId.length < 2 ? it.tokenId.padStart(2, '0') : it.tokenId
        ) as number[]

        console.log(
            'tokenids',
            tokenIDs,
            (await signer.provider?.getNetwork())?.chainId.toString(),
            userAddresses[i],
            distributorAddress
        )

        const chunkArr = chunk(tokenIDs, 50)

        let claimArr: ClaimData[] = []

        const requestArr = chunkArr?.map((ids) =>
            requestProofs(ids, PROJECT_ID)
        )

        const res = await Promise.all(requestArr)
        claimArr = res.flat()

        const claimedData = await batchFetchClaimed(
            signer,
            distributorAddress,
            claimArr.map((c) => c.leaf)
        )

        const claims = claimArr.filter((a, idx) => !claimedData[idx])

        // console.log('user ', userAddresses[i], 'claims', claims)

        for (let j = 0; j < claims.length; j++) {
            /*
             * const coder = new AbiCoder()
             * coder.decode([], claims[j].data)
             */

            const txn = await distributor
                .connect(signer)
                .claim(claims[j].proof, claims[j].group, claims[j].data)

            await txn.wait()

            console.log(`claimed for nft ${claims[j].recipient} ${txn.hash}`)

            const writeContent = `${claims[j].recipient} claimed, txn: ${txn.hash}`

            fs.appendFileSync(
                `concierge_${PROJECT_ID}_${executeTime}.log`,
                writeContent + '\n'
            )
        }
    }

    console.log(`Script finished, total time: ${Date.now() - executeTime} ms`)
}

run().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
