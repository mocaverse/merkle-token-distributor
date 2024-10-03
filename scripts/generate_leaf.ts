/* eslint-disable no-console */
import hre from 'hardhat'
import fs from 'fs'
import csv from 'csv-parse'

const PROJECT_ID = 'AD_KJWN2E8HWUt0' //neko
const TOKEN_TABLE_DOMAIN =
    process.env.TOKEN_TABLE_DOMAIN || 'https://moca-claim.tokentable.xyz'

async function loadCSV(
    filePath: string
): Promise<{Recipient: string; 'Token Allocated': string}[]> {
    const results: {Recipient: string; 'Token Allocated': string}[] = []

    return new Promise((resolve, reject) => {
        fs.createReadStream(filePath)
            .pipe(
                csv.parse({
                    delimiter: ',',
                    columns: true,
                    ltrim: true
                })
            )
            .on('data', (data: any) => results.push(data))
            .on('end', () => {
                resolve(results)
            })
            .on('error', reject)
    })
}

async function requestProofs(
    tokenIds: string[],
    projectId: string
): Promise<ClaimData[]> {
    const myHeaders = new Headers()
    myHeaders.append('Content-Type', 'application/json')

    const ids: number[] = tokenIds?.map((it) =>
        it.length < 2 ? it.padStart(2, '0') : it
    )

    const raw = JSON.stringify({
        recipients: ids,
        projectId
    })

    const requestOptions = {
        method: 'POST',
        headers: myHeaders,
        body: raw
    }

    return fetch(
        `${TOKEN_TABLE_DOMAIN}/api/airdrop-open/batch-query`,
        requestOptions
    )
        .then((response) => response.json())
        .then((res) => {
            return res.data.claims
        })
}

interface ClaimData {
    recipient: string
    proof: string[]
    group: string
    data: string
    leaf: string
    amount: string
    unlockingAt: number
    expiryTimetamp: number
}

async function run(batchSize = 50, startAt = 0, endAt = 0) {
    const distributorAddress = '0x96a95810C7D28245f64D6E065584500328897531' //neko

    const distributor = await hre.ethers.getContractAt(
        'NFTGatedMerkleDistributor',
        distributorAddress
        // signer
    )

    const [startTime, endTime] = await distributor.getTime()

    // eslint-disable-next-line no-console
    console.log('Contract start time: ', startTime, ' end time: ', endTime)

    // load csv from file path
    const csvPath = process.env.CSV_PATH || ''
    const userRecords = await loadCSV(csvPath)
    const executeTime = Date.now()

    console.log(
        'Script started for validting merkle contract: ',
        distributorAddress,
        ' at ',
        executeTime
    )

    const end = endAt === 0 ? userRecords.length : endAt

    // do convertion all at once in begining
    const allNFTTokenIds = userRecords.map((record) => record.Recipient)

    const filePath = `output/leafs_${Date.now()}.csv`
    fs.appendFileSync(filePath, '"nft id","leaf","isClaimed"\n')

    for (let i = startAt; i < end; i += batchSize) {
        const tokenIds = allNFTTokenIds.slice(i, i + batchSize)

        console.log(
            `Validating from ${i} to ${i + batchSize} of ${userRecords.length}`
        )

        // batch request claims
        const claims = await requestProofs(tokenIds, PROJECT_ID)

        for (let j = 0; j < claims.length; j++) {
            /*
             * const coder = new AbiCoder()
             * coder.decode([], claims[j].data)
             */

            const leaf = '0x' + claims[j].leaf
            const isClaimed = await distributor.isLeafUsed(leaf)

            const idx = tokenIds.indexOf(claims[j].recipient)
            idx === -1 &&
                console.error(`Token ID not found: ${claims[j].recipient}`)

            console.log(claims[j].recipient)

            const csvOutput = `${claims[j].recipient},"${leaf}",${isClaimed}\n`

            fs.appendFileSync(filePath, csvOutput)
        }
    }

    console.log(`Script finished, total time: ${Date.now() - executeTime} ms`)
}

const BATCH_SIZE = 50

run(BATCH_SIZE, 0, 0).catch((error) => {
    console.error(error)
    process.exitCode = 1
})
