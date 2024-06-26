const hre = require('hardhat')
const fs = require('fs')
const csv = require('csv-parse')

const ethereumMulticall = require('ethereum-multicall')

const REQUIRE_PARSE = true

const PROJECT_ID = 'AD_2fSv9K1GHoUG'

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

    const raw = JSON.stringify({
        recipients: tokenIds,
        projectId
    })

    const requestOptions = {
        method: 'POST',
        headers: myHeaders,
        body: raw
    }

    return fetch(
        'https://moca-claim.tokentable.xyz/api/airdrop-open/batch-query',
        requestOptions
    )
        .then((response) => response.json())
        .then((res) => res.data.claims)
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
    // const deployerPrivateKey = process.env.PRIVATE_KEY
    const distributorAddress = process.env.DISTRIBUTOR_CONTRACT
    const tokenAddress = process.env.TOKEN_CONTRACT

    // const signer = new hre.ethers.Wallet(
    //     deployerPrivateKey,
    //     hre.ethers.provider
    // )

    const distributor = await hre.ethers.getContractAt(
        'NFTGatedMerkleDistributor',
        distributorAddress
        // signer
    )
    const token = await hre.ethers.getContractAt('IERC20', tokenAddress)

    const isPaused = await distributor.paused()

    if (isPaused) {
        console.error('Contract is paused, unable to stake')
        return
    }

    // load csv from file path
    // const csvPath = process.env.CSV_PATH
    const csvPath = '../moca_0625_e2e.csv'
    const userRecords = await loadCSV(csvPath)
    const executeTime = Date.now()

    console.log(
        'Script started for claim contract: ',
        distributorAddress,
        ' at ',
        executeTime
    )

    const end = endAt === 0 ? userRecords.length : endAt

    // do convertion all at once in begining
    const allNFTTokenIds = userRecords.map((record) => record.Recipient)
    const allAmounts = userRecords
        .map((record) => record['Token Allocated'])
        .map((amount) =>
            REQUIRE_PARSE ? hre.ethers.parseEther(amount) : amount
        )

    for (let i = startAt; i < end; i += batchSize) {
        const tokenIds = allNFTTokenIds.slice(i, i + batchSize)
        const amounts = allAmounts.slice(i, i + batchSize)

        console.log(
            `Validating from ${i} to ${i + batchSize} of ${userRecords.length}`
        )

        // batch request claims
        const claims = await requestProofs(tokenIds, PROJECT_ID)

        for (let j = 0; j < claims.length; j++) {
            const leafData = await distributor.decodeMOCALeafData(
                claims[j].data
            )

            const idx = tokenIds.indexOf(claims[j].recipient)
            idx === -1 &&
                console.error(`Token ID not found: ${claims[j].recipient}`)

            const expectedAmount = amounts[idx]

            if (
                leafData.base.claimableAmount !==
                hre.ethers.formatEther(expectedAmount)
            ) {
                console.error(
                    `Amount mismatch: ${leafData.base.claimableAmount} != ${expectedAmount}`
                )
            }
        }
    }

    console.log(`Script finished, total time: ${Date.now() - executeTime} ms`)
}

const BATCH_SIZE = 50

run(BATCH_SIZE, 0, 0).catch((error) => {
    console.error(error)
    process.exitCode = 1
})
