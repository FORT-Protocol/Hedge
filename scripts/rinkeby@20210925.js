// We require the Hardhat Runtime Environment explicitly here. This is optional 
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const { ethers, upgrades } = require('hardhat');

exports.deploy = async function() {
    
    const eth = { address: '0x0000000000000000000000000000000000000000' };
    const TestERC20 = await ethers.getContractFactory('TestERC20');
    const NestPriceFacade = await ethers.getContractFactory('NestPriceFacade');
    const HedgeGovernance = await ethers.getContractFactory('HedgeGovernance');
    const DCU = await ethers.getContractFactory('DCU');
    const HedgeDAO = await ethers.getContractFactory('HedgeDAO');
    const HedgeOptions = await ethers.getContractFactory('HedgeOptions');
    const HedgeFutures = await ethers.getContractFactory('HedgeFutures');
    const HedgeVaultForStaking = await ethers.getContractFactory('HedgeVaultForStaking');

    console.log('** 开始部署合约 rinkeby@20210925.js **');
    
    // ** 开始部署合约 rinkeby@20210925.js **
    // usdt: 0x2d750210c0b5343a0b79beff8F054C9add7d2411
    // hbtc: 0xaE73d363Cb4aC97734E07e48B01D0a1FF5D1190B
    // dcu: 0xDB7b4FdF99eEE8E4Cb8373630c923c51c1275382
    // nestPriceFacade: 0x40C3EB032f27fDa7AdcF1B753c75B84e27f26838
    // hedgeGovernance: 0x43E8330d1725a2978122B49d41197e7Dc073cdf1
    // hedgeDAO: 0x57E481f193df1e69639171506b2c38136e53B7d1
    // hedgeOptions: 0x7557E34f05193b8Ee1edC1A4c0d4f8A158D1Ab61
    // hedgeFutures: 0x183C6068f6e3c25912f0D054e2cC34D11f217f50
    // hedgeVaultForStaking: 0x3254D21C38c6b8ea4A256A5B474622852F8B6d2A

    // 1. 部署依赖合约
    //const usdt = await TestERC20.deploy('USDT', 'USDT', 6);
    const usdt = await TestERC20.attach('0x2d750210c0b5343a0b79beff8F054C9add7d2411');
    console.log('usdt: ' + usdt.address);

    //const hbtc = await TestERC20.deploy('HBTC', 'HBTC', 18);
    const hbtc = await TestERC20.attach('0xaE73d363Cb4aC97734E07e48B01D0a1FF5D1190B');
    console.log('hbtc: ' + hbtc.address);

    //const dcu = await DCU.deploy();
    const dcu = await DCU.attach('0xDB7b4FdF99eEE8E4Cb8373630c923c51c1275382');
    console.log('dcu: ' + dcu.address);
    
    //const nestPriceFacade = await NestPriceFacade.deploy();
    const nestPriceFacade = await NestPriceFacade.attach('0x40C3EB032f27fDa7AdcF1B753c75B84e27f26838');
    console.log('nestPriceFacade: ' + nestPriceFacade.address);

    //const hedgeGovernance = await upgrades.deployProxy(HedgeGovernance, ['0x0000000000000000000000000000000000000000'], { initializer: 'initialize' });
    const hedgeGovernance = await HedgeGovernance.attach('0x43E8330d1725a2978122B49d41197e7Dc073cdf1');
    console.log('hedgeGovernance: ' + hedgeGovernance.address);

    //const hedgeDAO = await upgrades.deployProxy(HedgeDAO, [hedgeGovernance.address], { initializer: 'initialize' });
    const hedgeDAO = await HedgeDAO.attach('0x57E481f193df1e69639171506b2c38136e53B7d1');
    console.log('hedgeDAO: ' + hedgeDAO.address);

    //const hedgeOptions = await upgrades.deployProxy(HedgeOptions, [hedgeGovernance.address], { initializer: 'initialize' });
    const hedgeOptions = await HedgeOptions.attach('0x7557E34f05193b8Ee1edC1A4c0d4f8A158D1Ab61');
    console.log('hedgeOptions: ' + hedgeOptions.address);

    //const hedgeFutures = await upgrades.deployProxy(HedgeFutures, [hedgeGovernance.address], { initializer: 'initialize' });
    const hedgeFutures = await HedgeFutures.attach('0x183C6068f6e3c25912f0D054e2cC34D11f217f50');
    console.log('hedgeFutures: ' + hedgeFutures.address);

    //const hedgeVaultForStaking = await upgrades.deployProxy(HedgeVaultForStaking, [hedgeGovernance.address], { initializer: 'initialize' });
    const hedgeVaultForStaking = await HedgeVaultForStaking.attach('0x3254D21C38c6b8ea4A256A5B474622852F8B6d2A');
    console.log('hedgeVaultForStaking: ' + hedgeVaultForStaking.address);

    // // await hedgeGovernance.initialize('0x0000000000000000000000000000000000000000');
    // console.log('1. dcu.initialize(hedgeGovernance.address)');
    // await dcu.initialize(hedgeGovernance.address);
    // // await hedgeDAO.initialize(hedgeGovernance.address);
    // // await hedgeOptions.initialize(hedgeGovernance.address);
    // // await hedgeFutures.initialize(hedgeGovernance.address);
    // // await hedgeVaultForStaking.initialize(hedgeGovernance.address);

    // console.log('2. hedgeGovernance.setBuiltinAddress()');
    // await hedgeGovernance.setBuiltinAddress(
    //     dcu.address,
    //     hedgeDAO.address,
    //     hedgeOptions.address,
    //     hedgeFutures.address,
    //     hedgeVaultForStaking.address,
    //     nestPriceFacade.address
    // );

    // console.log('3. dcu.update()');
    // await dcu.update(hedgeGovernance.address);
    // console.log('4. hedgeDAO.update()');
    // await hedgeDAO.update(hedgeGovernance.address);
    // console.log('5. hedgeOptions.update()');
    // await hedgeOptions.update(hedgeGovernance.address);
    // console.log('6. hedgeFutures.update()');
    // await hedgeFutures.update(hedgeGovernance.address);
    // console.log('7. hedgeVaultForStaking.update()');
    // await hedgeVaultForStaking.update(hedgeGovernance.address);

    // console.log('8. hedgeOptions.setConfig()');
    // await hedgeOptions.setConfig(eth.address, { 
    //     sigmaSQ: '45659142400', 
    //     miu: '467938556917', 
    //     minPeriod: 6000 
    // });
    // console.log('8.1. hedgeOptions.setConfig()');
    // await hedgeOptions.setConfig(hbtc.address, { 
    //     sigmaSQ: '45659142400', 
    //     miu: '467938556917', 
    //     minPeriod: 6000 
    // });

    // console.log('9. dcu.setMinter(hedgeOptions.address, 1)');
    // await dcu.setMinter(hedgeOptions.address, 1);
    // console.log('10. dcu.setMinter(hedgeFutures.address, 1)');
    // await dcu.setMinter(hedgeFutures.address, 1);
    // console.log('11. dcu.setMinter(hedgeVaultForStaking.address, 1)');
    // await dcu.setMinter(hedgeVaultForStaking.address, 1);

    // await hedgeOptions.setUsdtTokenAddress(usdt.address);
    // await hedgeFutures.setUsdtTokenAddress(usdt.address);

    // console.log('8.2 create lever');
    // await hedgeFutures.create(eth.address, 1, true);
    // await hedgeFutures.create(eth.address, 2, true);
    // await hedgeFutures.create(eth.address, 5, true);
    // await hedgeFutures.create(eth.address, 1, false);
    // await hedgeFutures.create(eth.address, 2, false);
    // await hedgeFutures.create(eth.address, 5, false);
    // await hedgeFutures.create(hbtc.address, 1, true);
    // await hedgeFutures.create(hbtc.address, 2, true);
    // await hedgeFutures.create(hbtc.address, 5, true);
    // await hedgeFutures.create(hbtc.address, 1, false);
    // await hedgeFutures.create(hbtc.address, 2, false);
    // await hedgeFutures.create(hbtc.address, 5, false);

    console.log('---------- OK ----------');
    
    const contracts = {
        eth: eth,
        usdt: usdt,
        hbtc: hbtc,

        hedgeGovernance: hedgeGovernance,
        dcu: dcu,
        hedgeDAO: hedgeDAO,
        hedgeOptions: hedgeOptions,
        hedgeFutures: hedgeFutures,
        hedgeVaultForStaking: hedgeVaultForStaking,
        nestPriceFacade: nestPriceFacade
    };

    return contracts;
};