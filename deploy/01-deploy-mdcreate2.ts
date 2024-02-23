// TypeScript
import {DeployFunction} from 'hardhat-deploy/dist/types'
import {HardhatRuntimeEnvironment} from 'hardhat/types'

const deployMDCreate2: DeployFunction = async (
    hre: HardhatRuntimeEnvironment
) => {
    // eslint-disable-next-line @typescript-eslint/unbound-method
    const {deploy} = hre.deployments
    const {deployer} = await hre.getNamedAccounts()
    await deploy('MDCreate2', {
        from: deployer,
        log: true,
        args: [],
        waitConfirmations: 1
    })
}

export default deployMDCreate2
deployMDCreate2.tags = ['MDCreate2']
