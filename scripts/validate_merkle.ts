/* eslint-disable no-console */
import hre from 'hardhat'
import fs from 'fs'
import csv from 'csv-parse'

const PROJECT_ID = process.env.PROJECT_ID || 'AD_S91weJPDfAwv'
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
    const distributorAddress = process.env.DISTRIBUTOR_CONTRACT || ''

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
    const allAmounts = userRecords
        .map((record) => record['Token Allocated'])
        .map((amount) => hre.ethers.parseEther(amount))

    fs.appendFileSync(
        `output/${PROJECT_ID}_proofs.csv`,
        '"nft id","claim","proof (bytes32[])","group (byte32)","data (bytes)"\n'
    )

    for (let i = startAt; i < end; i += batchSize) {
        const tokenIds = allNFTTokenIds.slice(i, i + batchSize)
        const amounts = allAmounts.slice(i, i + batchSize)

        console.log(
            `Validating from ${i} to ${i + batchSize} of ${userRecords.length}`
        )

        // batch request claims
        const claims = await requestProofs(tokenIds, PROJECT_ID)

        console.log('claims response', claims)

        for (let j = 0; j < claims.length; j++) {
            /*
             * const coder = new AbiCoder()
             * coder.decode([], claims[j].data)
             */

            const leafData = await distributor.decodeMOCALeafData(
                claims[j].data
            )

            const idx = tokenIds.indexOf(claims[j].recipient)
            idx === -1 &&
                console.error(`Token ID not found: ${claims[j].recipient}`)

            const expectedAmount = amounts[idx]

            console.log(
                leafData.base.claimableAmount,
                expectedAmount,
                leafData.expiryTimestamp
            )

            let writeContent = `${claims[j].recipient} data matched`
            if (leafData.base.claimableAmount !== expectedAmount) {
                console.error(
                    `${claims[j].recipient} Amount mismatch: ${leafData.base.claimableAmount} != ${expectedAmount}`
                )
                writeContent = `${claims[j].recipient} data mismatch: ${leafData.base.claimableAmount} != ${expectedAmount}`
            }
            const proofString = claims[j].proof.join(',')
            const csvOutput = `${claims[j].recipient},${0},"${proofString}",${claims[j].group},${claims[j].data}\n`

            fs.appendFileSync(`output/${PROJECT_ID}_proofs.csv`, csvOutput)

            fs.appendFileSync(
                `validate_merkle_${PROJECT_ID}_${executeTime}.log`,
                writeContent + '\n'
            )
        }
    }

    console.log(`Script finished, total time: ${Date.now() - executeTime} ms`)
}

const BATCH_SIZE = 50

run(BATCH_SIZE, 5374, 5375).catch((error) => {
    console.error(error)
    process.exitCode = 1
})
