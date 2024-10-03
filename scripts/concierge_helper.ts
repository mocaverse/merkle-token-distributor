/* eslint-disable no-console */
import hre from 'hardhat'
import fs from 'fs'
import csv from 'csv-parse'

import {DelegateV2} from '@delegatexyz/sdk'
import {http} from 'viem'
import {OwnedNft, OwnedNftsResponse} from 'alchemy-sdk'

import {abi} from '../artifacts/src/core/extensions/custom/NFTGatedMerkleDistributor.sol/NFTGatedMerkleDistributor.json'
import {Multicall} from 'ethereum-multicall'
import {JsonRpcProvider, Signer} from 'ethers'

const ISLEAFUSED_ABI = {
    inputs: [
        {
            internalType: 'bytes32',
            name: 'leaf',
            type: 'bytes32'
        }
    ],
    name: 'isLeafUsed',
    outputs: [
        {
            internalType: 'bool',
            name: '',
            type: 'bool'
        }
    ],
    stateMutability: 'view',
    type: 'function'
}

const RPC_URL = `https://eth-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_ETH_API!}`
// const RPC_URL = 'https://eth-sepolia.g.alchemy.com/v2/oi_0UC8MxXX5JWBts1L8f8waeNdenVf5'

const TOKEN_TABLE_DOMAIN =
    process.env.TOKEN_TABLE_DOMAIN || 'https://moca-claim.tokentable.xyz'

export const getDelegateAddresses = async (recipient: `0x${string}`) => {
    let incoming
    try {
        const v2 = new DelegateV2(http(RPC_URL))
        incoming = await v2.getIncomingDelegations(recipient)
        return incoming.map((it) => it.from)
    } catch (error) {
        console.warn(error)
    }
}

export async function loadCSV(filePath: string): Promise<string[]> {
    const addresses: string[] = []

    return new Promise((resolve, reject) => {
        fs.createReadStream(filePath)
            .pipe(
                csv.parse({
                    delimiter: ',',
                    columns: true,
                    ltrim: true
                })
            )
            .on('data', (data) => addresses.push(data.address.toLowerCase()))
            .on('end', () => {
                resolve(addresses)
            })
            .on('error', reject)
    })
}

export async function requestProofs(
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
        `${TOKEN_TABLE_DOMAIN}/api/airdrop-open/batch-query`,
        requestOptions
    )
        .then((response) => response.json())
        .then((res) => res.data.claims)
}

export async function batchFetchClaimed(
    signer: Signer,
    contractAddress: string,
    leafs: string[]
) {
    const multicall = new Multicall({
        multicallCustomContractAddress:
            '0xcA11bde05977b3631167028862bE2a173976CA11',
        nodeUrl: RPC_URL,
        tryAggregate: true
    })

    const calls = leafs.map((leaf) => ({
        reference: 'leaf',
        methodName: 'isLeafUsed',
        methodParameters: ['0x' + leaf]
    }))

    const contractCallContext = [
        {
            reference: 'NFTGatedMerkleDistributor',
            contractAddress: contractAddress,
            abi: [ISLEAFUSED_ABI],
            calls: calls
        }
    ]

    const {results} = await multicall.call(contractCallContext)

    const isLeavesUsed: boolean[] =
        results.NFTGatedMerkleDistributor.callsReturnContext.map(
            (call) => call.returnValues[0]
        ) as boolean[]

    return isLeavesUsed
}

export function wait(ms: number) {
    return new Promise((resolve) => {
        setTimeout(resolve, ms)
    })
}

export async function requestOwnerNfts(
    chainId: string,
    owner: string,
    contractAddress: string
): Promise<OwnedNftsResponse> {
    const myHeaders = new Headers()
    myHeaders.append('Content-Type', 'application/json')

    const raw = JSON.stringify({
        chainId,
        owner,
        contractAddress
    })

    const requestOptions = {
        method: 'POST',
        headers: myHeaders,
        body: raw
    }

    return fetch(`${TOKEN_TABLE_DOMAIN}/api/airdrop-open/nfts`, requestOptions)
        .then((response) => response.json())
        .then((res) => res.data.ownedNfts)
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
    index: number
    expiryTimestamp: number
}

export function chunk<T>(array: T[], chunkSize: number): T[][] {
    const chunkedArray: T[][] = []
    let index = 0

    while (index < array.length) {
        chunkedArray.push(array.slice(index, index + chunkSize))
        index += chunkSize
    }

    return chunkedArray
}
