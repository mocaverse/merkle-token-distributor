// TypeScript
import {DeployFunction} from 'hardhat-deploy/dist/types'
import {HardhatRuntimeEnvironment} from 'hardhat/types'

const deployTTUV2: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
    // eslint-disable-next-line @typescript-eslint/unbound-method
    const {deploy} = hre.deployments
    const {deployer} = await hre.getNamedAccounts()
    try {
        await deploy('MockERC721', {
            from: deployer,
            log: true,
            args: [],
            waitConfirmations: 1
        })
    } catch (error) {}
}

export default deployTTUV2
deployTTUV2.tags = ['MockERC721']
