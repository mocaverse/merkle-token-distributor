// TypeScript
import {DeployFunction} from 'hardhat-deploy/dist/types'
import {HardhatRuntimeEnvironment} from 'hardhat/types'

const deploySimpleERC721MerkleDistributor: DeployFunction = async (
    hre: HardhatRuntimeEnvironment
) => {
    // eslint-disable-next-line @typescript-eslint/unbound-method
    const {deploy} = hre.deployments
    const {deployer} = await hre.getNamedAccounts()
    await deploy('SimpleERC721MerkleDistributor', {
        from: deployer,
        log: true,
        args: [],
        waitConfirmations: 1
    })
}

export default deploySimpleERC721MerkleDistributor
deploySimpleERC721MerkleDistributor.tags = ['SimpleERC721MerkleDistributor']
