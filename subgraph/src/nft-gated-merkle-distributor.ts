import {
    Claimed as ClaimedEvent,
    Initialized1 as Initialized1Event,
    NFTGatedMerkleDistributor
} from '../generated/NFTGatedMerkleDistributor/NFTGatedMerkleDistributor'
import {Claimed, Initialized1} from '../generated/schema'

export function handleClaimed(event: ClaimedEvent): void {
    const contract = NFTGatedMerkleDistributor.bind(event.address)
    const decodedData = contract.decodeMOCALeafData(event.params.data)

    const entity = new Claimed(
        event.transaction.hash.concatI32(event.logIndex.toI32())
    )
    entity.recipient = event.params.recipient
    entity.group = event.params.group
    entity.index = decodedData.base.index
    entity.claimableTimestamp = decodedData.base.claimableTimestamp
    entity.claimableAmount = decodedData.base.claimableAmount
    entity.expiryTimestamp = decodedData.expiryTimestamp
    entity.nftTokenId = decodedData.nftTokenId

    entity.blockNumber = event.block.number
    entity.blockTimestamp = event.block.timestamp
    entity.transactionHash = event.transaction.hash

    entity.save()
}

export function handleInitialized1(event: Initialized1Event): void {
    const entity = new Initialized1(
        event.transaction.hash.concatI32(event.logIndex.toI32())
    )
    entity.projectId = event.params.projectId

    entity.blockNumber = event.block.number
    entity.blockTimestamp = event.block.timestamp
    entity.transactionHash = event.transaction.hash

    entity.save()
}
