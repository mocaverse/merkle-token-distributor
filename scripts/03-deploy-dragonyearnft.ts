import {ethers, upgrades} from 'hardhat'

async function main() {
    const Factory = await ethers.getContractFactory('DragonYearNFT')
    const instance = await upgrades.deployProxy(Factory, [
        'SIGN Lucky Dragon',
        'LUCK'
    ])
    await instance.waitForDeployment()
}

void main()
