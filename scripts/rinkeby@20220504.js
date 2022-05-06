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
    const FortOptions = await ethers.getContractFactory('FortOptions');
    const FortFutures = await ethers.getContractFactory('FortFutures');
    const HedgeVaultForStaking = await ethers.getContractFactory('HedgeVaultForStaking');

    console.log('** Deploy: rinkeby@20220504.js **');
        
    //     ** Deploy: rinkeby@20211004.js **
    // usdt: 0x2d750210c0b5343a0b79beff8F054C9add7d2411
    // hbtc: 0xaE73d363Cb4aC97734E07e48B01D0a1FF5D1190B
    // dcu: 0xc408edF487e98bB932eD4A8983038FF19352eDbd
    // nestPriceFacade: 0xc08E6A853241B9a08225EECf93F3b279FA7A1bE7
    // hedgeGovernance: 0xA2B48399a579335eF7D410B9C0B50E59E126C48a
    // hedgeDAO: 0x5769c37289C9dCfe1AD141773a9ED5aA89c2e069
    // hedgeOptions: 0x702F97D4991e2155576548989fEdEE3971705465
    // hedgeFutures: 0x3Db207CadA55e556ab7A8534A7a6aD9EFfc27B01
    // hedgeVaultForStaking: 0x5cA5E616310c0Cca41B7E4329021C17a5a79a0F1

    // nest: 0xE313F3f49B647fBEDDC5F2389Edb5c93CBf4EE25
    // nhbtc: 0x801b69dA3210BAB7482E21085cd2A14d77b23475
    // cofi: 0x61EA050b28Ccca539F0faf79Fd26F6Df31b9f15B
    // pusd: 0x5407cab67ad304FB8A4aC46D83b3Dd63A9dbA575
    // fortube: 0x37591670bCc04af593287fbc16C58F12f0B57881
    // usdt: 0x2d750210c0b5343a0b79beff8F054C9add7d2411
    // hbtc: 0xaE73d363Cb4aC97734E07e48B01D0a1FF5D1190B
    // dcu: 0xc408edF487e98bB932eD4A8983038FF19352eDbd
    // nestPriceFacade: 0xc08E6A853241B9a08225EECf93F3b279FA7A1bE7
    // hedgeGovernance: 0xA2B48399a579335eF7D410B9C0B50E59E126C48a
    // hedgeDAO: 0x5769c37289C9dCfe1AD141773a9ED5aA89c2e069
    // hedgeOptions: 0x702F97D4991e2155576548989fEdEE3971705465
    // hedgeFutures: 0x3Db207CadA55e556ab7A8534A7a6aD9EFfc27B01
    // hedgeVaultForStaking: 0x5cA5E616310c0Cca41B7E4329021C17a5a79a0F1
    // hedgeSwap: 0x0A94eB67c4bfA14094D6aAF0D1fEc8AfD0E7A25b
    // proxyAdmin: 0xf870dE82463896d2BC7b369eAEfFcCED03139968

    const nest = await TestERC20.attach('0xE313F3f49B647fBEDDC5F2389Edb5c93CBf4EE25'); //.deploy('NEST', 'NEST', 18);
    console.log('nest: ' + nest.address);

    const nhbtc = await TestERC20.attach('0x801b69dA3210BAB7482E21085cd2A14d77b23475');
    console.log('nhbtc: ' + nhbtc.address);

    const cofi = await TestERC20.attach('0x61EA050b28Ccca539F0faf79Fd26F6Df31b9f15B'); //.deploy('COFI', 'COFI', 18);
    console.log('cofi: ' + cofi.address);

    const pusd = await TestERC20.attach('0x5407cab67ad304FB8A4aC46D83b3Dd63A9dbA575');
    console.log('pusd: ' + pusd.address);

    const fortube = await TestERC20.attach('0x37591670bCc04af593287fbc16C58F12f0B57881');
    console.log('fortube: ' + fortube.address);

    //const usdt = await TestERC20.deploy('USDT', 'USDT', 6);
    const usdt = await TestERC20.attach('0x2d750210c0b5343a0b79beff8F054C9add7d2411');
    console.log('usdt: ' + usdt.address);

    //const hbtc = await TestERC20.deploy('HBTC', 'HBTC', 18);
    const hbtc = await TestERC20.attach('0xaE73d363Cb4aC97734E07e48B01D0a1FF5D1190B');
    console.log('hbtc: ' + hbtc.address);

    //const dcu = await DCU.deploy();
    const dcu = await DCU.attach('0xc408edF487e98bB932eD4A8983038FF19352eDbd');
    console.log('dcu: ' + dcu.address);

    //const nestPriceFacade = await NestPriceFacade.deploy();
    const nestPriceFacade = await NestPriceFacade.attach('0xc08E6A853241B9a08225EECf93F3b279FA7A1bE7');
    console.log('nestPriceFacade: ' + nestPriceFacade.address);

    //const hedgeGovernance = await upgrades.deployProxy(HedgeGovernance, ['0x0000000000000000000000000000000000000000'], { initializer: 'initialize' });
    const hedgeGovernance = await HedgeGovernance.attach('0xA2B48399a579335eF7D410B9C0B50E59E126C48a');
    console.log('hedgeGovernance: ' + hedgeGovernance.address);

    //const hedgeDAO = await upgrades.deployProxy(HedgeDAO, [hedgeGovernance.address], { initializer: 'initialize' });
    const hedgeDAO = await HedgeDAO.attach('0x5769c37289C9dCfe1AD141773a9ED5aA89c2e069');
    console.log('hedgeDAO: ' + hedgeDAO.address);

    //const hedgeOptions = await upgrades.deployProxy(HedgeOptions, [hedgeGovernance.address], { initializer: 'initialize' });
    const fortOptions = await FortOptions.attach('0x702F97D4991e2155576548989fEdEE3971705465');
    console.log('fortOptions: ' + fortOptions.address);

    //const hedgeFutures = await upgrades.deployProxy(HedgeFutures, [hedgeGovernance.address], { initializer: 'initialize' });
    const fortFutures = await FortFutures.attach('0x3Db207CadA55e556ab7A8534A7a6aD9EFfc27B01');
    console.log('fortFutures: ' + fortFutures.address);

    //const hedgeVaultForStaking = await upgrades.deployProxy(HedgeVaultForStaking, [hedgeGovernance.address], { initializer: 'initialize' });
    const hedgeVaultForStaking = await HedgeVaultForStaking.attach('0x5cA5E616310c0Cca41B7E4329021C17a5a79a0F1');
    console.log('hedgeVaultForStaking: ' + hedgeVaultForStaking.address);

    // //const hedgeSwap = await upgrades.deployProxy(HedgeSwap, [hedgeGovernance.address], { initializer: 'initialize' });
    // const hedgeSwap = await HedgeSwap.attach('0x0A94eB67c4bfA14094D6aAF0D1fEc8AfD0E7A25b');
    // console.log('hedgeSwap: ' + hedgeSwap.address);

    // // await hedgeGovernance.initialize('0x0000000000000000000000000000000000000000');
    // console.log('1. dcu.initialize(hedgeGovernance.address)');
    // await dcu.initialize(hedgeGovernance.address);
    // // await hedgeDAO.initialize(hedgeGovernance.address);
    // // await hedgeOptions.initialize(hedgeGovernance.address);
    // // await hedgeFutures.initialize(hedgeGovernance.address);
    // // await hedgeVaultForStaking.initialize(hedgeGovernance.address);

    console.log(await hedgeGovernance.getBuiltinAddress());

    // console.log('2. hedgeGovernance.setBuiltinAddress()');
    // await hedgeGovernance.setBuiltinAddress(
    //     '0x0000000000000000000000000000000000000000',
    //     '0x0000000000000000000000000000000000000000',
    //     '0x0000000000000000000000000000000000000000',
    //     '0x0000000000000000000000000000000000000000',
    //     '0x0000000000000000000000000000000000000000',
    //     nestPriceFacade.address, {nonce:2674}
    // );

    // console.log('7. fortOptions.register(eth.address)');
    // await fortOptions.register(eth.address, {
    //     channelId: 0,
    //     pairIndex: 1,
        
    //     sigmaSQ: 45659142400n,
    //     miuLong: 64051194700n,
    //     miuShort: 0n
    // }, {nonce:2677});
    // console.log('8. fortOptions.register(pbtc.address)');
    // await fortOptions.register(hbtc.address, {
    //     channelId: 0,
    //     pairIndex: 0,
        
    //     sigmaSQ: 31708924900n,
    //     miuLong: 64051194700n,
    //     miuShort: 0n
    // }, {nonce:2678});

    // console.log('9. fortFutures.register(eth.address)');
    // await fortFutures.register(eth.address, {
    //     channelId: 0,
    //     pairIndex: 1,
        
    //     sigmaSQ: 45659142400n,
    //     miuLong: 64051194700n,
    //     miuShort: 0n
    // }, {nonce: 2694});
    // console.log('10. fortFutures.register(hbtc.address)');
    // await fortFutures.register(hbtc.address, {
    //     channelId: 0,
    //     pairIndex: 0,
        
    //     sigmaSQ: 31708924900n,
    //     miuLong: 64051194700n,
    //     miuShort: 0n
    // }, {nonce: 2695});

    // console.log('11. create eth long lever');
    // await fortFutures.create(eth.address, [1, 2, 3, 4, 5], true, {nonce: 2696});
    // console.log('12. create eth short lever');
    // await fortFutures.create(eth.address, [1, 2, 3, 4, 5], false, {nonce: 2697});

    // console.log('13. create hbtc long lever');
    // await fortFutures.create(hbtc.address, [1, 2, 3, 4, 5], true, {nonce: 2698});
    // console.log('14. create hbtc short lever');
    // await fortFutures.create(hbtc.address, [1, 2, 3, 4, 5], false, {nonce: 2699});


    console.log('---------- OK ----------');

    const contracts = {
        eth: eth,
        usdt: usdt,
        hbtc: hbtc,
        nest: nest,
        nhbtc: nhbtc,
        cofi: cofi,
        pusd: pusd,
        fortube: fortube,
        peth: fortube,

        hedgeGovernance: hedgeGovernance,
        dcu: dcu,
        hedgeDAO: hedgeDAO,
        fortOptions: fortOptions,
        fortFutures: fortFutures,
        hedgeVaultForStaking: hedgeVaultForStaking,
        nestPriceFacade: nestPriceFacade,
        //hedgeSwap: hedgeSwap
    };

    return contracts;
};