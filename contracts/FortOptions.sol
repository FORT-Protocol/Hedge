// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./libs/TransferHelper.sol";
import "./libs/ABDKMath64x64.sol";

import "./interfaces/IFortOptions.sol";

import "./custom/ChainParameter.sol";
import "./custom/CommonParameter.sol";
import "./custom/FortFrequentlyUsed.sol";
import "./custom/NestPriceAdapter.sol";

import "./DCU.sol";

/// @dev 欧式期权
contract FortOptions is ChainParameter, CommonParameter, FortFrequentlyUsed, NestPriceAdapter, IFortOptions {

    /// @dev 期权结构
    struct Option {
        uint32 owner;
        uint128 balance;
        uint56 strikePrice;
        bool orientation;
        uint32 exerciseBlock;
    }

    // 64位二进制精度的1
    int128 constant ONE = 0x10000000000000000;

    // 64位二进制精度的50000
    uint constant V50000 = 0x0C3500000000000000000;

    // 期权卖出价值比例，万分制。9750
    uint constant SELL_RATE = 9500;

    // 期权代币数组
    Option[] _options;

    // 注册账户索引
    mapping(address=>uint) _accountMapping;

    // 注册账户数组
    address[] _accounts;

    constructor() {
    }

    /// @dev To support open-zeppelin/upgrades
    /// @param governance IFortGovernance implementation contract address
    function initialize(address governance) public override {
        super.initialize(governance);
        _accounts.push();
    }

    /// @dev 返回指定期权的余额
    /// @param index 目标期权索引号
    /// @param addr 目标地址
    function balanceOf(uint index, address addr) external view override returns (uint) {
        //return _options[index].balances[addr];
        Option memory option = _options[index];
        if (uint(option.owner) == getAccountIndex(addr)) {
            return uint(option.balance);
        }
        return 0;
    }

    /// @dev 查找目标账户的期权（倒序）
    /// @param start 从给定的合约地址对应的索引向前查询（不包含start对应的记录）
    /// @param count 最多返回的记录条数
    /// @param maxFindCount 最多查找maxFindCount记录
    /// @param owner 目标账户地址
    /// @return optionArray 期权信息列表
    function find(
        uint start, 
        uint count, 
        uint maxFindCount, 
        address owner
    ) external view override returns (OptionView[] memory optionArray) {
        
        optionArray = new OptionView[](count);
        
        // 计算查找区间i和end
        Option[] storage options = _options;
        uint i = options.length;
        uint end = 0;
        if (start > 0) {
            i = start;
        }
        if (i > maxFindCount) {
            end = i - maxFindCount;
        }
        
        uint ownerIndex = getAccountIndex(owner);
        // 循环查找，将符合条件的记录写入缓冲区
        for (uint index = 0; index < count && i > end;) {
            Option storage option = options[--i];
            if (uint(option.owner) == ownerIndex) {
                optionArray[index++] = _toOptionView(option, i);
            }
        }
    }

    /// @dev 列出历史期权信息
    /// @param offset Skip previous (offset) records
    /// @param count Return (count) records
    /// @param order Order. 0 reverse order, non-0 positive order
    /// @return optionArray 期权信息列表
    function list(
        uint offset, 
        uint count, 
        uint order
    ) external view override returns (OptionView[] memory optionArray) {

        // 加载代币数组
        Option[] storage options = _options;
        // 创建结果数组
        optionArray = new OptionView[](count);
        uint length = options.length;
        uint i = 0;

        // 倒序
        if (order == 0) {
            uint index = length - offset;
            uint end = index > count ? index - count : 0;
            while (index > end) {
                Option storage option = options[--index];
                optionArray[i++] = _toOptionView(option, index);
            }
        } 
        // 正序
        else {
            uint index = offset;
            uint end = index + count;
            if (end > length) {
                end = length;
            }
            while (index < end) {
                optionArray[i++] = _toOptionView(options[index], index);
                ++index;
            }
        }
    }

    /// @dev 获取已经开通的欧式期权代币数量
    /// @return 已经开通的欧式期权代币数量
    function getOptionCount() external view override returns (uint) {
        return _options.length;
    }

    /// @dev 开仓
    /// @param tokenAddress 目标代币地址，0表示eth
    /// @param strikePrice 用户设置的行权价格，结算时系统会根据标的物当前价与行权价比较，计算用户盈亏
    /// @param orientation 看涨/看跌两个方向。true：看涨，false：看跌
    /// @param exerciseBlock 到达该日期后用户手动进行行权，日期在系统中使用区块号进行记录
    /// @param dcuAmount 支付的dcu数量
    function open(
        address tokenAddress,
        uint strikePrice,
        bool orientation,
        uint exerciseBlock,
        uint dcuAmount
    ) external payable override {

        // 1. 调用预言机获取价格
        uint oraclePrice = _latestPrice(tokenAddress, msg.value, msg.sender);

        // 2. 计算可以买到的期权份数
        uint amount = estimate(tokenAddress, oraclePrice, strikePrice, orientation, exerciseBlock, dcuAmount);

        // 3. 开仓
        // 开仓事件
        emit Open(_options.length, dcuAmount, msg.sender, amount);
        // 添加期权账本
        _options.push(Option(
            uint32(_addressIndex(msg.sender)), //uint32 owner;
            _toUInt128(amount), //uint128 balance;
            _encodeFloat(strikePrice), //uint56 strikePrice;
            orientation, //bool orientation;
            uint32(exerciseBlock)//uint32 exerciseBlock;
        ));

        // 4. 销毁权利金
        DCU(DCU_TOKEN_ADDRESS).burn(msg.sender, dcuAmount);
    }

    /// @dev 预估开仓可以买到的期权币数量
    /// @param tokenAddress 目标代币地址，0表示eth
    /// @param oraclePrice 当前预言机价格价
    /// @param strikePrice 用户设置的行权价格，结算时系统会根据标的物当前价与行权价比较，计算用户盈亏
    /// @param orientation 看涨/看跌两个方向。true：看涨，false：看跌
    /// @param exerciseBlock 到达该日期后用户手动进行行权，日期在系统中使用区块号进行记录
    /// @param dcuAmount 支付的dcu数量
    /// @return amount 预估可以获得的期权币数量
    function estimate(
        address tokenAddress,
        uint oraclePrice,
        uint strikePrice,
        bool orientation,
        uint exerciseBlock,
        uint dcuAmount
    ) public view override returns (uint amount) {

        require(exerciseBlock > block.number + MIN_PERIOD, "FEO:exerciseBlock too small");

        // 1. 计算期权价格
        // 按照平均每14秒出一个块计算
        uint v = calcV(
            tokenAddress, 
            oraclePrice,
            strikePrice,
            orientation,
            exerciseBlock
        );

        // 2. 对期权价格进行修正
        if (orientation) {
            //v = _calcVc(config, oraclePrice, T, strikePrice);
            // Vc>=S0*1%; Vp>=K*1%
            // require(v * 100 >> 64 >= oraclePrice, "FEO:vc must greater than S0*1%");
            if (v * 100 >> 64 < oraclePrice) {
                v = oraclePrice * 0x10000000000000000 / 100;
            }
        } else {
            //v = _calcVp(config, oraclePrice, T, strikePrice);
            // Vc>=S0*1%; Vp>=K*1%
            // require(v * 100 >> 64 >= strikePrice, "FEO:vp must greater than K*1%");
            if (v * 100 >> 64 < strikePrice) {
                v = strikePrice * 0x10000000000000000 / 100;
            }
        }

        // 3. 计算可以买到的期权份数
        amount = (USDT_BASE << 64) * dcuAmount / v;
    }
    
    /// @dev 行权
    /// @param index 期权编号
    /// @param amount 结算的期权分数
    function exercise(uint index, uint amount) external payable override {

        // 1. 获取期权信息
        Option storage option = _options[index];
        //address tokenAddress = address(0);// option.tokenAddress;
        uint strikePrice = _decodeFloat(option.strikePrice);
        bool orientation = option.orientation;
        uint exerciseBlock = uint(option.exerciseBlock);

        // TODO: 测试时不检查行权区块
        //require(block.number >= exerciseBlock, "FEO:at maturity");

        // 2. 销毁期权代币
        //option.balances[msg.sender] -= amount;
        option.balance = _toUInt128(uint(option.balance) - amount);

        // 3. 调用预言机获取价格，读取预言机在指定区块的价格
        // 3.1. 获取token相对于eth的价格
        uint oraclePrice = _findPrice(address(0), exerciseBlock, msg.value, msg.sender);

        // 4. 分情况计算用户可以获得的dcu数量
        uint gain = 0;
        // 计算结算结果
        // 看涨期权
        if (orientation) {
            // 赌赢了
            if (oraclePrice > strikePrice) {
                gain = amount * (oraclePrice - strikePrice) / USDT_BASE;
            }
        } 
        // 看跌期权
        else {
            // 赌赢了
            if (oraclePrice < strikePrice) {
                gain = amount * (strikePrice - oraclePrice) / USDT_BASE;
            }
        }

        // 5. 用户赌赢了，给其增发赢得的dcu
        if (gain > 0) {
            DCU(DCU_TOKEN_ADDRESS).mint(msg.sender, gain);
        }

        // 行权事件
        emit Exercise(index, amount, msg.sender, gain);
    }

    /// @dev 卖出期权
    /// @param index 期权编号
    /// @param amount 卖出的期权分数
    function sell(uint index, uint amount) external payable override {
        // 期权卖出公式：vt=Max（ct(T,K）*0.975，0）其中ct(K,T)是按照定价公式计算的期权成本，
        // 注意，不是包含了不低于1%这个设定
        // 1. 获取期权信息
        Option storage option = _options[index];
        address tokenAddress = address(0); //option.tokenAddress;
        uint strikePrice = _decodeFloat(option.strikePrice);
        bool orientation = option.orientation;
        uint exerciseBlock = uint(option.exerciseBlock);

        // 2. 销毁期权代币
        //option.balances[msg.sender] -= amount;
        option.balance = _toUInt128(uint(option.balance) - amount);

        // 3. 调用预言机获取价格，读取预言机在指定区块的价格
        uint oraclePrice = _latestPrice(tokenAddress, msg.value, msg.sender);

        // 4. 分情况计算当前情况下的期权价格
        // 按照平均每14秒出一个块计算
        uint dcuAmount = amount * calcV(
            tokenAddress, 
            oraclePrice,
            strikePrice,
            orientation,
            exerciseBlock
        ) * SELL_RATE / (USDT_BASE * 0x27100000000000000000); //(USDT_BASE * 10000 << 64);
        if (dcuAmount > 0) {
            DCU(DCU_TOKEN_ADDRESS).mint(msg.sender, dcuAmount);
        }

        // 卖出事件
        emit Sell(index, amount, msg.sender, dcuAmount);
    }

    /// @dev 计算期权价格
    /// @param oraclePrice 当前预言机价格价
    /// @param strikePrice 用户设置的行权价格，结算时系统会根据标的物当前价与行权价比较，计算用户盈亏
    /// @param orientation 看涨/看跌两个方向。true：看涨，false：看跌
    /// @param exerciseBlock 到达该日期后用户手动进行行权，日期在系统中使用区块号进行记录
    /// @return v 期权价格，需要除以(USDT_BASE << 64)
    function calcV(
        address,
        uint oraclePrice,
        uint strikePrice,
        bool orientation,
        uint exerciseBlock
    ) public view override returns (uint v) {

        //require(tokenAddress== address(0), "FEO:not allowed");

        // 按照平均每14秒出一个块计算
        uint T = (exerciseBlock - block.number) * BLOCK_TIME / 1000;
        v = orientation 
            ? _calcVc(oraclePrice, T, strikePrice) 
            : _calcVp(oraclePrice, T, strikePrice);
    }

    /// @dev Gets the address corresponding to the given index number
    /// @param index The index number of the specified address
    /// @return The address corresponding to the given index number
    function indexAddress(uint index) public view returns (address) {
        return _accounts[index];
    }

    /// @dev Gets the registration index number of the specified address
    /// @param addr Destination address
    /// @return 0 means nonexistent, non-0 means index number
    function getAccountIndex(address addr) public view returns (uint) {
        return _accountMapping[addr];
    }

    /// @dev Get the length of registered account array
    /// @return The length of registered account array
    function getAccountCount() external view returns (uint) {
        return _accounts.length;
    }

    // 转化位OptionView
    function _toOptionView(
        Option storage option, 
        uint index
    ) private view returns (OptionView memory) {
        return OptionView(
            index,
            address(0), //option.tokenAddress,
            _decodeFloat(option.strikePrice),
            option.orientation,
            uint(option.exerciseBlock),
            option.balance
        );
    }

    // 将18位十进制定点数转化为64位二级制定点数
    function _d18TOb64(uint v) private pure returns (int128) {
        require(v < 0x6F05B59D3B200000000000000000000, "FEO:can't convert to 64bits");
        return int128(int((v << 64) / 1 ether));
    }

    // 将uint转化为int128
    function _toInt128(uint v) private pure returns (int128) {
        require(v < 0x80000000000000000000000000000000, "FEO:can't convert to int128");
        return int128(int(v));
    }

    // 将int128转化为uint
    function _toUInt(int128 v) private pure returns (uint) {
        require(v >= 0, "FEO:can't convert to uint");
        return uint(int(v));
    }

    // 将uint转化为uint128
    function _toUInt128(uint v) private pure returns (uint128) {
        require(v < 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF, "HO:can't convert to uint128");
        return uint128(v);
    }

    // 通过查表的方法计算标准正态分布函数
    function _snd(int128 x) private pure returns (int128) {
        uint[28] memory table = [
            /* */ ///////////////////// STANDARD NORMAL TABLE //////////////////////////
            /* */ 0x174A15BF143412A8111C0F8F0E020C740AE6095807CA063B04AD031E018F0000, //
            ///// 0x2F8C2E0F2C912B1229922811268F250B23872202207D1EF61D6F1BE61A5D18D8, //
            /* */ 0x2F8C2E0F2C912B1229922811268F250B23872202207D1EF61D6F1BE61A5D18D4, //
            /* */ 0x46A2453C43D4426B41003F943E263CB63B4539D3385F36EA357333FB32823108, //
            /* */ 0x5C0D5AC5597B582F56E05590543E52EA5194503C4EE24D874C294ACA49694807, //
            /* */ 0x6F6C6E466D1F6BF56AC9699B686A6738660364CC6392625761195FD95E975D53, //
            /* */ 0x807E7F7F7E7D7D797C737B6A7A5F79517841772F761A750373E972CD71AF708E, //
            /* */ 0x8F2A8E518D768C998BB98AD789F2890B88218736864785568463836E8276817B, //
            /* */ 0x9B749AC19A0B9953989997DD971E965D959A94D4940C9342927591A690D49000, //
            /* */ 0xA57CA4ECA459A3C4A32EA295A1FAA15CA0BDA01C9F789ED29E2A9D809CD39C25, //
            ///// 0xA57CA4ECA459A3C4A32EA295A1FAA15DA0BDA01C9F789ED29E2A9D809CD39C25, //
            /* */ 0xAD78AD07AC93AC1EABA7AB2EAAB3AA36A9B8A937A8B5A830A7AAA721A697A60B, //
            /* */ 0xB3AAB353B2FAB2A0B245B1E7B189B128B0C6B062AFFDAF96AF2DAEC2AE56ADE8, //
            /* */ 0xB859B818B7D6B793B74EB708B6C0B678B62EB5E2B595B547B4F7B4A6B454B400, //
            /* */ 0xBBCDBB9EBB6EBB3CBB0ABAD7BAA2BA6DBA36B9FFB9C6B98CB951B915B8D8B899, //
            /* */ 0xBE49BE27BE05BDE2BDBEBD99BD74BD4DBD26BCFEBCD5BCACBC81BC56BC29BBFC, //
            /* */ 0xC006BFEEBFD7BFBEBFA5BF8CBF72BF57BF3CBF20BF03BEE6BEC8BEA9BE8ABE69, //
            /* */ 0xC135C126C116C105C0F4C0E3C0D1C0BFC0ACC099C086C072C05DC048C032C01C, //
            /* */ 0xC200C1F5C1EBC1E0C1D5C1C9C1BEC1B1C1A5C198C18BC17EC170C162C154C145, //
            /* */ 0xC283C27CC275C26EC267C260C258C250C248C240C238C22FC226C21DC213C20A, //
            /* */ 0xC2D6C2D2C2CDC2C9C2C5C2C0C2BBC2B6C2B1C2ACC2A7C2A1C29BC295C28FC289, //
            /* */ 0xC309C306C304C301C2FEC2FCC2F9C2F6C2F2C2EFC2ECC2E8C2E5C2E1C2DEC2DA, //
            /* */ 0xC328C326C325C323C321C320C31EC31CC31AC318C316C314C312C310C30EC30B, //
            /* */ 0xC33AC339C338C337C336C335C334C333C332C331C330C32EC32DC32CC32AC329, //
            /* */ 0xC344C343C343C342C342C341C341C340C33FC33FC33EC33DC33DC33CC33BC33A, //
            /* */ 0xC34AC349C349C349C348C348C348C348C347C347C346C346C346C345C345C344, //
            /* */ 0xC34DC34DC34CC34CC34CC34CC34CC34CC34BC34BC34BC34BC34BC34AC34AC34A, //
            /* */ 0xC34EC34EC34EC34EC34EC34EC34EC34EC34EC34EC34DC34DC34DC34DC34DC34D, //
            /* */ 0xC34FC34FC34FC34FC34FC34FC34FC34FC34FC34FC34FC34FC34FC34FC34EC34E, //
            /* */ 0xC350C350C350C350C350C350C34FC34FC34FC34FC34FC34FC34FC34FC34FC34F  //
            /* */ //////////////////// MADE IN CHINA 2021-08-24 ////////////////////////
        ];

        uint ux = uint(int(x < 0 ? -x : x)) * 100;
        uint i = ux >> 64;
        uint v = V50000;

        if (i < 447) {
            v = uint((table[i >> 4] >> ((i & 0xF) << 4)) & 0xFFFF) << 64;
            v = (
                    (
                        (
                            (uint((table[(i + 1) >> 4] >> (((i + 1) & 0xF) << 4)) & 0xFFFF) << 64)
                            - v
                        ) * (ux & 0xFFFFFFFFFFFFFFFF) //(ux - (i << 64))
                    ) >> 64
                ) + v;
        }

        if (x > 0) {
            v = V50000 + v;
        } else {
            v = V50000 - v;
        }

        return int128(int(v / 100000));
    }

    // // 查询token价格
    // function _queryPrice(address tokenAddress, uint fee, address payback) private returns (uint oraclePrice) {
    //     require(tokenAddress == address(0), "HO:not allowed!");
    //     // 1.1. 获取token相对于eth的价格
    //     //uint tokenAmount = 1 ether;

    //     // 1.2. 获取usdt相对于eth的价格
    //     (, uint rawPrice) = INestOpenPrice(NEST_OPEN_PRICE).latestPrice {
    //         value: fee
    //     } (ETH_USDT_CHANNEL_ID, payback);

    //     // 1.3. 将token价格转化为以usdt为单位计算的价格
    //     oraclePrice = _toUSDTPrice(rawPrice);
    // }

    // 计算看涨期权价格
    function _calcVc(uint S0, uint T, uint K) private pure returns (uint vc) {

        int128 sigmaSQ_T = _d18TOb64(SIGMA_SQ * T);
        int128 miu_T = _toInt128(MIU_LONG * T);
        int128 sigma_t = ABDKMath64x64.sqrt(sigmaSQ_T);
        int128 D1 = _D1(S0, K, sigmaSQ_T, miu_T);
        int128 d = ABDKMath64x64.div(D1, sigma_t);

        uint left = _toUInt(ABDKMath64x64.mul(
            //ABDKMath64x64.exp(miu_T), 
            // 改为单利近似计算: x*(1+rt)
            // by chenf 2021-12-28 15:27
            miu_T + ONE,
            ABDKMath64x64.sub(
                ONE,
                _snd(ABDKMath64x64.sub(d, sigma_t))
            )
        )) * S0;
        uint right = _toUInt(ABDKMath64x64.sub(ONE, _snd(d))) * K;
        
        vc = left > right ? left - right : 0;
    }

    // 计算看跌期权价格
    function _calcVp(uint S0, uint T, uint K) private pure returns (uint vp) {

        int128 sigmaSQ_T = _d18TOb64(SIGMA_SQ * T);
        int128 miu_T = _toInt128(MIU_SHORT * T);
        int128 sigma_t = ABDKMath64x64.sqrt(sigmaSQ_T);
        int128 D1 = _D1(S0, K, sigmaSQ_T, miu_T);
        int128 d = ABDKMath64x64.div(D1, sigma_t);

        uint left = _toUInt(_snd(d)) * K;
        uint right = _toUInt(ABDKMath64x64.mul(
            //ABDKMath64x64.exp(miu_T), 
            // 改为单利近似计算: x*(1+rt)
            // by chenf 2021-12-28 15:27
            miu_T + ONE,
            _snd(ABDKMath64x64.sub(d, sigma_t))
        )) * S0;

        vp = left > right ? left - right : 0;
    }

    // 计算公式中的d1，因为没有除以σ，所以命名为D1
    function _D1(uint S0, uint K, int128 sigmaSQ_T, int128 miu_T) private pure returns (int128) {

        //require(K < 0x1000000000000000000000000000000000000000000000000, "FEO:K can't ROL 64bits");
        return
            ABDKMath64x64.sub(
                ABDKMath64x64.add(
                    ABDKMath64x64.ln(_toInt128(K * 0x10000000000000000 / S0)),
                    sigmaSQ_T >> 1
                ),
                miu_T
            );
    }
    
    /// @dev Encode the uint value as a floating-point representation in the form of fraction * 16 ^ exponent
    /// @param value Destination uint value
    /// @return float format
    function _encodeFloat(uint value) private pure returns (uint56) {

        uint exponent = 0; 
        while (value > 0x3FFFFFFFFFFFF) {
            value >>= 4;
            ++exponent;
        }
        return uint56((value << 6) | exponent);
    }

    /// @dev Decode the floating-point representation of fraction * 16 ^ exponent to uint
    /// @param floatValue fraction value
    /// @return decode format
    function _decodeFloat(uint56 floatValue) private pure returns (uint) {
        return (uint(floatValue) >> 6) << ((uint(floatValue) & 0x3F) << 2);
    }
    
    /// @dev Gets the index number of the specified address. If it does not exist, register
    /// @param addr Destination address
    /// @return The index number of the specified address
    function _addressIndex(address addr) private returns (uint) {

        uint index = _accountMapping[addr];
        if (index == 0) {
            // If it exceeds the maximum number that 32 bits can store, you can't continue to register a new account.
            // If you need to support a new account, you need to update the contract
            require((_accountMapping[addr] = index = _accounts.length) < 0x100000000, "HO:!accounts");
            _accounts.push(addr);
        }

        return index;
    }
}