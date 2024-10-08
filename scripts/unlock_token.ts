/* eslint-disable no-console */
import hre from 'hardhat'
import fs from 'fs'
import csv from 'csv-parse'

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

async function unlockToken(nftIds: number[]) {
    // request api POST /api/nft/internal/unlock-nft-tokens
    const apiUrl =
        process.env.INTERNAL_API_DOMAIN + '/api/nft/internal/unlock-nft-tokens'

    console.log(apiUrl)

    const requestBody = {tokenIds: nftIds}

    try {
        const response = await fetch(apiUrl, {
            method: 'POST',
            headers: {
                'x-api-key': process.env.INTERNAL_API_KEY ?? '',
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(requestBody)
        })

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`)
        }

        // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment
        // const result = await response.json()
        console.log('Tokens unlocked successfully:', response.body)
    } catch (error) {
        console.error('Error unlocking tokens:', error)
    }
}

async function run(
    batchSize = 50,
    startAt = 0,
    endAt = 0,
    currentWeekCSVPath = ''
) {
    const csvPath = currentWeekCSVPath
    const userRecords = await loadCSV<{
        Recipient: string
        'Token Allocated': string
    }>(csvPath)

    const end = endAt === 0 ? userRecords.length : endAt

    // loop thought all the nft ids
    for (let i = startAt; i < end; i += batchSize) {
        const tokenIds = userRecords
            .map((r) => parseInt(r.Recipient))
            .slice(i, i + batchSize)

        const res = await unlockToken(tokenIds)
        console.log('res', res)
    }
}

const CURRENT_WEEK_CSV_PATH = './claim-extra-e2e-1.csv'

run(50, 0, 0, CURRENT_WEEK_CSV_PATH).catch((e) => console.error(e))
