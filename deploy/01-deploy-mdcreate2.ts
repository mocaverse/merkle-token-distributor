// TypeScript
import {DeployFunction} from 'hardhat-deploy/dist/types'
import {HardhatRuntimeEnvironment} from 'hardhat/types'
import {ethers} from 'hardhat'
import {MDCreate2} from '../typechain-types'

const deployMDCreate2: DeployFunction = async (
    hre: HardhatRuntimeEnvironment
) => {
    // eslint-disable-next-line @typescript-eslint/unbound-method
    const {deploy} = hre.deployments
    const {deployer} = await hre.getNamedAccounts()
    const mdCreate2Result = await deploy('MDCreate2', {
        from: deployer,
        log: true,
        args: [],
        waitConfirmations: 1
    })
    const simpleERC721MerkleDistributorResult = await deploy(
        'SimpleERC721MerkleDistributor',
        {
            from: deployer,
            log: true,
            args: [],
            waitConfirmations: 1
        }
    )
    const tokenTableMerkleDistributorResult = await deploy(
        'TokenTableMerkleDistributor',
        {
            from: deployer,
            log: true,
            args: [],
            waitConfirmations: 1
        }
    )
    const tokenTableNativeMerkleDistributorResult = await deploy(
        'TokenTableNativeMerkleDistributor',
        {
            from: deployer,
            log: true,
            args: [],
            waitConfirmations: 1
        }
    )
    const nftGatedMerkleDistributorResult = await deploy(
        'NFTGatedMerkleDistributor',
        {
            from: deployer,
            log: true,
            args: [],
            waitConfirmations: 1
        }
    )

    const MDCreate2Factory = await ethers.getContractFactory('MDCreate2')
    const mdCreate2Instance = MDCreate2Factory.attach(
        mdCreate2Result.address
    ) as MDCreate2
    await mdCreate2Instance.setImplementation(
        0,
        tokenTableMerkleDistributorResult.address
    )
    await mdCreate2Instance.setImplementation(
        1,
        tokenTableNativeMerkleDistributorResult.address
    )
    await mdCreate2Instance.setImplementation(
        2,
        simpleERC721MerkleDistributorResult.address
    )
    await mdCreate2Instance.setImplementation(
        3,
        nftGatedMerkleDistributorResult.address
    )
}

export default deployMDCreate2
deployMDCreate2.tags = ['MDCreate2']
