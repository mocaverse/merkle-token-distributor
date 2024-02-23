import {ethers, upgrades} from 'hardhat'

async function main() {
    const Factory = await ethers.getContractFactory('MDCreate2')
    const instance = await upgrades.deployProxy(Factory, [])
    await instance.waitForDeployment()
}

void main()
