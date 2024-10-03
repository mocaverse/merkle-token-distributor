/* eslint-disable no-console */
import hre from 'hardhat'
import fs from 'fs'
import csv from 'csv-parse'

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

interface LeafData {
    nftId: string
    leaf: string
    isClaimed: boolean
}

/*
 * Verify that all leafs in the current merkle tree are also present in the new merkle tree.
 * Verify that there are no duplicate nft ids in the new merkle tree.
 * Verify that there are no more than 8888 leafs, and that the number of leafs in the new tree should be more than or equal to the current tree.
 * Print out sum of total tokens claimable for the new merkle tree. The difference between the new and current tree should be transferred to the token table contract
 * Update the phase 2 contract with the new merkle tree.
 */

const PROJECT_ID = process.env.PROJECT_ID
const TOKEN_TABLE_DOMAIN = process.env.TOKEN_TABLE_DOMAIN

async function loadCSV<T>(filePath: string): Promise<T[]> {
    const results: T[] = []

    return new Promise((resolve, reject) => {
        fs.createReadStream(filePath)
            .pipe(
                csv.parse({
                    delimiter: ',',
                    columns: true,
                    ltrim: true
                })
            )
            .on('data', (data: T) => results.push(data))
            .on('end', () => {
                resolve(results)
            })
            .on('error', reject)
    })
}

async function loadLeafs(week: number): Promise<LeafData[]> {
    if (week === 0) {
        return Promise.resolve([])
    }
    const filePath = `output/${PROJECT_ID}_leafs_${week}.csv`
    return loadCSV<LeafData>(filePath)
}

async function loadNFTIds(): Promise<string[]> {
    const nftIds = await loadCSV<{token_id: string}>(
        process.env.NFT_LIST_PATH || ''
    )
    return nftIds.map((it) => it.token_id)
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
            if (!res.data || !Array.isArray(res.data.claims)) {
                throw new Error('Invalid response format')
            }
            return res.data.claims as ClaimData[]
        })
}

// Verify that there are no duplicate nft ids in the new merkle tree
function validateClaimsDuplicatedRecipients(claims: ClaimData[]) {
    const recipientSet = new Set()
    for (const claim of claims) {
        if (recipientSet.has(claim.recipient)) {
            throw new Error('Duplicate NFT ID in the claim data')
        }
        recipientSet.add(claim.recipient)
    }
    return true
}

// Verify that all leafs in the current merkle tree are also present in the new merkle tree.
async function validateLeafs(
    previousLeafs: LeafData[],
    currentWeek: number,
    currentLeafs: LeafData[],
    totalNumberOfNFTs: number
) {
    // Verify All leafs in the previous week merkle tree are also present in the new merkle tree
    const currentLeafSet = new Set(currentLeafs.map((leaf) => leaf.leaf))

    for (const prevLeaf of previousLeafs) {
        if (!currentLeafSet.has(prevLeaf.leaf)) {
            throw new Error(
                `Leaf ${prevLeaf.leaf} from week ${currentWeek - 1} is missing in week ${currentWeek}`
            )
        }
    }

    console.log(
        `All leafs from week ${currentWeek - 1} are present in week ${currentWeek}`
    )

    // Verify that the number of leafs in the new tree is more than or equal to the current tree
    if (currentLeafs.length < previousLeafs.length) {
        throw new Error(
            `Number of leafs in week ${currentWeek} (${currentLeafs.length}) is less than week ${currentWeek - 1} (${previousLeafs.length})`
        )
    }

    // Verify that there are no more than 8888 leafs
    if (currentLeafs.length > totalNumberOfNFTs) {
        throw new Error(
            `Number of leafs in week ${currentWeek} (${currentLeafs.length}) exceeds the maximum of 8888`
        )
    }

    console.log(`Leaf count validation passed for week ${currentWeek}`)
}

async function run(
    batchSize = 50,
    startAt = 0,
    endAt = 0,
    week = 1,
    currentWeekCSVPath = ''
) {
    if (!PROJECT_ID || !TOKEN_TABLE_DOMAIN) {
        console.error('PROJECT_ID or TOKEN_TABLE_DOMAIN is not set')
        process.exit(1)
    }

    const nftIds = await loadNFTIds()

    const distributorAddress = process.env.DISTRIBUTOR_CONTRACT || ''

    const out_leaf_file_path = `output/${PROJECT_ID}_leafs_${week}.csv`
    const out_proofs_file_path = `output/${PROJECT_ID}_proofs_${week}.csv`

    const distributor = await hre.ethers.getContractAt(
        'NFTGatedMerkleDistributor',
        distributorAddress
        // signer
    )

    const [startTime, endTime] = await distributor.getTime()

    // eslint-disable-next-line no-console
    console.log('Contract start time: ', startTime, ' end time: ', endTime)

    // load current week csv
    const csvPath = currentWeekCSVPath
    const userRecords = await loadCSV<{
        Recipient: string
        'Token Allocated': string
    }>(csvPath)
    const executeTime = Date.now()

    console.log(
        'Script started for validting merkle contract: ',
        distributorAddress,
        ' at ',
        executeTime
    )

    const end = endAt === 0 ? nftIds.length : endAt

    // convert userRecords to token id amount mapping
    const idAmountMap = new Map<string, bigint>()
    for (let i = 0; i < userRecords.length; i++) {
        idAmountMap.set(
            userRecords[i].Recipient,
            BigInt(hre.ethers.parseEther(userRecords[i]['Token Allocated']))
        )
    }

    fs.writeFileSync(
        out_proofs_file_path,
        '"nft id","claim","proof (bytes32[])","group (byte32)","data (bytes)"\n'
    )

    fs.writeFileSync(out_leaf_file_path, '"nftId","leaf","isClaimed"\n')

    const allLeafs: LeafData[] = []

    const previousLeafs = await loadLeafs(week - 1)

    // loop thought all the nft ids
    for (let i = startAt; i < end; i += batchSize) {
        const tokenIds = nftIds.slice(i, i + batchSize)

        console.log(
            `Validating by nft id, from ${i} to ${i + batchSize} of ${nftIds.length}`
        )

        // batch request claims
        const claims = await requestProofs(tokenIds, PROJECT_ID)

        validateClaimsDuplicatedRecipients(claims)

        console.log('claims response', claims)

        for (let j = 0; j < claims.length; j++) {
            const leaf = {
                nftId: claims[j].recipient,
                leaf: claims[j].leaf,
                isClaimed: await distributor.isLeafUsed('0x' + claims[j].leaf)
            }
            allLeafs.push(leaf)

            const leafData = await distributor.decodeMOCALeafData(
                claims[j].data
            )

            const idx = tokenIds.indexOf(claims[j].recipient)
            // some id in merkle tree is not in the nft list
            if (idx === -1) {
                throw new Error(
                    'Token ID in claim data not found in the NFT list!'
                )
            }

            const expectedAmount = idAmountMap.get(claims[j].recipient)

            console.log(
                'tokenId:',
                claims[j].recipient,
                'leaf decoded claimableAmout:',
                leafData.base.claimableAmount,
                'amount in csv:',
                expectedAmount,
                'expiryTimestamp:',
                leafData.expiryTimestamp
            )

            let writeContent = `${claims[j].recipient} data matched`
            if (leafData.base.claimableAmount !== expectedAmount) {
                if (typeof expectedAmount === 'undefined') {
                    // look up if its leaf exists in previous week
                    const prevLeaf = previousLeafs.find(
                        (pl) => pl.nftId === claims[j].recipient
                    )
                    // eslint-disable-next-line max-depth
                    if (prevLeaf) {
                        console.log('pass as previous week leaf')
                    }
                } else {
                    console.log('amount mismatch')
                    throw new Error(
                        `${claims[j].recipient} Amount mismatch: ${leafData.base.claimableAmount} != ${expectedAmount}`
                    )
                }

                writeContent = `${claims[j].recipient} data mismatch: ${leafData.base.claimableAmount} != ${expectedAmount}`
            }
            const proofString = claims[j].proof.join(',')

            const csvOutput = `${claims[j].recipient},${0},"${proofString}",${claims[j].group},${claims[j].data}\n`
            fs.appendFileSync(out_proofs_file_path, csvOutput)

            const leafOutput = `"${leaf.nftId}","${leaf.leaf}","${leaf.isClaimed}"\n`
            fs.appendFileSync(out_leaf_file_path, leafOutput)

            fs.appendFileSync(
                `validate_merkle_${PROJECT_ID}_${executeTime}.log`,
                writeContent + '\n'
            )
        }
    }

    // querying back the previous week leafs from api

    await validateLeafs(previousLeafs, week, allLeafs, nftIds.length)

    console.log(`Script finished, total time: ${Date.now() - executeTime} ms`)
}

const BATCH_SIZE = 50
const START_AT = 0
const END_AT = 0
const WEEK = 2
const CURRENT_WEEK_CSV_PATH = './claim-extra-e2e-2.csv'

run(BATCH_SIZE, START_AT, END_AT, WEEK, CURRENT_WEEK_CSV_PATH).catch(
    (error) => {
        console.error(error)
        process.exitCode = 1
    }
)
