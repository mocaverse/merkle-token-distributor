import {ethers, upgrades} from 'hardhat'

async function main() {
    const Factory = await ethers.getContractFactory('DragonYearNFT')
    const instance = await upgrades.deployProxy(Factory, ['Name', 'Symbol'])
    await instance.waitForDeployment()
}

void main()
