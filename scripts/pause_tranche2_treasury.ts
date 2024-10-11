/* eslint-disable no-console */
import hre from 'hardhat'
import fs from 'fs'
import csv from 'csv-parse'
import dbData from '../db_0x2016554065E392d5DB0734519a4Bc836CcBfe459.json'
import apiData from '../0x2016554065E392d5DB0734519a4Bc836CcBfe459.json'
import {ethers, Signer} from 'ethers'
const PROJECT_ID = process.env.PROJECT_ID
const TOKEN_TABLE_DOMAIN = process.env.TOKEN_TABLE_DOMAIN
import {Multicall} from 'ethereum-multicall'

const pauseStreamsABI = [
    'function pauseStreams(uint256[] calldata tokenIds) external'
]

const getStreamsABI = {
    inputs: [{internalType: 'uint256', name: 'tokenId', type: 'uint256'}],
    stateMutability: 'view',
    type: 'function',
    name: 'streams',
    outputs: [
        {internalType: 'uint128', name: 'claimed', type: 'uint128'},
        {
            internalType: 'uint128',
            name: 'lastClaimedTimestamp',
            type: 'uint128'
        },
        {internalType: 'bool', name: 'isPaused', type: 'bool'}
    ]
}

async function getOwnedNFTs(walletAddress: string): Promise<string[]> {
    const etherscanAPI = `https://api.etherscan.io/api?module=account&action=tokennfttx&contractaddress=0x59325733eb952a92e069c87f0a6168b29e80627f&address=${walletAddress}&page=1&offset=3000&apikey=WXEEF9MY41DTTN8A8N6J9MZ68JA3JCGT6K`

    const response = await fetch(etherscanAPI)
    const data = await response.json()
    const nft_txns = data.result

    console.log(nft_txns.length)

    const transferOut = nft_txns.filter(
        (r: {from: string}) => r.from === walletAddress
    )
    const transferIn = nft_txns.filter(
        (r: {to: string}) => r.to === walletAddress
    )

    console.log(transferIn.length)
    console.log(transferOut.length)
    const owningNfts = transferIn.filter(
        (r: {tokenID: any; blockNumber: number}) =>
            transferOut.find(
                (r2: {tokenID: any; blockNumber: number}): boolean =>
                    r2.tokenID === r.tokenID && r.blockNumber < r2.blockNumber
            ) === undefined
    )

    return owningNfts.map((r: {tokenID: any}) => r.tokenID)
}

async function fetchTreasuryNFTs() {
    const treasuryAddress1 =
        '0x2016554065E392d5DB0734519a4Bc836CcBfe459'.toLowerCase()
    const treasuryAddress2 =
        '0x9c339C363D9099E695B16D2aF9cF0E0fd669d542'.toLowerCase()

    const treasuryNFTs = [treasuryAddress1, treasuryAddress2]

    const treasuryNFTIds = []

    for (const treasuryAddress of treasuryNFTs) {
        const nftIds = await getOwnedNFTs(treasuryAddress)
        treasuryNFTIds.push(...nftIds)
        fs.writeFileSync(treasuryAddress + '.json', JSON.stringify(nftIds))
    }

    return treasuryNFTIds
}

function compareTreasuryNFTs(
    file1: string[],
    file2: string[]
): {added: string[]; removed: string[]} {
    const set1 = new Set(file1)
    const set2 = new Set(file2)

    const added = file2.filter((id) => !set1.has(id))
    const removed = file1.filter((id) => !set2.has(id))
    console.log('file2', file2.length)
    console.log('added', added.length)
    return {added, removed}
}

async function pauseTranche2Treasury(
    signer: Signer,
    contractAddress: string,
    tokenIds: string[]
) {
    // Create a contract instance with just the function we need

    const contract = new ethers.Contract(
        contractAddress,
        pauseStreamsABI,
        signer
    )

    console.log(`Pausing streams for ${tokenIds.length} tokens...`)

    try {
        // Convert string tokenIds to BigNumber
        const tokenIdsBigNumber = tokenIds.map((id) => ethers.toBigInt(id))

        const tx = await contract.pauseStreams(tokenIdsBigNumber)
        console.log(`Transaction sent: ${tx.hash}`)
        const receipt = await tx.wait()
        console.log(
            `Transaction confirmed. Streams paused successfully. Gas used: ${receipt.gasUsed.toString()}`
        )
    } catch (error) {
        console.error(`Error pausing streams:`, error)
    }
}

const RPC_URL = `https://eth-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_ETH_API!}`

async function validatePaused(
    signer: Signer,
    contractAddress: string,
    tokenIds: string[]
) {
    const multicall = new Multicall({
        nodeUrl: RPC_URL,
        tryAggregate: true
    })
    const calls = tokenIds.map((id) => ({
        reference: 'streams',
        methodName: 'streams',
        methodParameters: [id]
    }))

    const contractCallContext = [
        {
            reference: 'getStreams',
            contractAddress: contractAddress,
            abi: [getStreamsABI],
            calls: calls
        }
    ]
    const {results} = await multicall.call(contractCallContext)

    results.getStreams.callsReturnContext.forEach((call, idx) => {
        if (call.returnValues[2] === false) {
            throw new Error(
                'stream is not paused for tokenId: ' + tokenIds[idx]
            )
        }
    })
}

async function run(batchSize = 500, startAt = 0, endAt = 0) {
    const allTokenIds = await fetchTreasuryNFTs()

    // console.log(compareTreasuryNFTs(dbData, apiData))

    const end = endAt === 0 ? allTokenIds.length : endAt
    const operatorPrivateKey = process.env.TRANCHE2_OPERATOR_PRIVATE_KEY || ''

    const signer = new hre.ethers.Wallet(
        operatorPrivateKey,
        hre.ethers.provider
    )
    // // loop thought all the nft ids
    for (let i = startAt; i < end; i += batchSize) {
        const tokenIds = allTokenIds.slice(i, i + batchSize)
        const contractAddress = '0xb46f2634fcb79fa2f73899487d04acfb0252a457' //prod
        // const contractAddress = '0x29eea54a67f0ca2a531d008943298be7444ee898'
        await pauseTranche2Treasury(signer, contractAddress, tokenIds)
        console.log('pauseTranche2Treasury', tokenIds)
        await validatePaused(signer, contractAddress, tokenIds)
    }
}

run().catch((e) => console.error(e))
