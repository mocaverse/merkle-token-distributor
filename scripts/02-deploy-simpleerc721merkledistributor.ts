import {ethers, upgrades} from 'hardhat'

async function main() {
    const Factory = await ethers.getContractFactory(
        'SimpleERC721MerkleDistributor'
    )
    const instance = await upgrades.deployProxy(Factory, ['AD_DUs3iQRdM18h'], {
        kind: 'uups'
    })
    await instance.waitForDeployment()
}

void main()
