import {ethers, upgrades} from 'hardhat'

async function main() {
    const Factory = await ethers.getContractFactory(
        'SimpleERC721MerkleDistributor'
    )
    const instance = await upgrades.deployProxy(Factory, ['dragon-mint'])
    await instance.waitForDeployment()
}

void main()
