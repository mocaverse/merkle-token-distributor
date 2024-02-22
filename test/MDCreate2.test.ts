/* eslint-disable multiline-comment-style */
/* eslint-disable @typescript-eslint/no-unsafe-member-access */
/* eslint-disable @typescript-eslint/no-unsafe-assignment */
/* eslint-disable @typescript-eslint/no-unsafe-call */
/* eslint-disable no-console */
/* eslint-disable no-mixed-operators */
import {ethers} from 'hardhat'
import {expect} from 'chai'
import '@nomicfoundation/hardhat-chai-matchers'
import {MDCreate2, SimpleERC721MerkleDistributor} from '../typechain-types'

describe('MDCreate2', () => {
    const projectId = 'test id'
    let mdCreate2: MDCreate2

    beforeEach(async () => {
        const MDCreate2Factory = await ethers.getContractFactory('MDCreate2')
        mdCreate2 = await MDCreate2Factory.deploy()
    })

    it('should successfully deploy a Merkle Distributor', async () => {
        const instanceAddress = await mdCreate2.deploy.staticCall(2, projectId)
        await mdCreate2.deploy(2, projectId)
        const instance = (
            await ethers.getContractFactory('SimpleERC721MerkleDistributor')
        ).attach(instanceAddress) as SimpleERC721MerkleDistributor
        expect(await instance.version()).to.equal('0.0.1')
    })

    it('should simulate the correct address', async () => {
        expect(await mdCreate2.deploy.staticCall(2, projectId)).to.equal(
            await mdCreate2.simulateDeploy(2, projectId)
        )
    })
})
