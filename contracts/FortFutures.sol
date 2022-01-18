// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./libs/TransferHelper.sol";
import "./libs/ABDKMath64x64.sol";

import "./interfaces/IFortFutures.sol";

import "./custom/ChainParameter.sol";
import "./custom/CommonParameter.sol";
import "./custom/FortFrequentlyUsed.sol";
import "./custom/NestPriceAdapter.sol";

import "./DCU.sol";

/// @dev 永续合约交易
contract FortFutures is ChainParameter, CommonParameter, FortFrequentlyUsed, NestPriceAdapter, IFortFutures {

    /// @dev 用户账本
    struct Account {
        // 账本-余额
        uint128 balance;
        // 基准价格
        uint64 basePrice;
        // 基准区块号
        uint32 baseBlock;
    }

    /// @dev 永续合约信息
    struct FutureInfo {
        // 目标代币地址
        address tokenAddress; 
        // 杠杆倍数
        uint32 lever;
        // 看涨:true | 看跌:false
        bool orientation;
        
        // 账号信息
        mapping(address=>Account) accounts;
    }

    // 最小余额数量，余额小于此值会被清算
    uint constant MIN_VALUE = 10 ether;

    // 永续合约映射
    mapping(uint=>uint) _futureMapping;

    // 永续合约数组
    FutureInfo[] _futures;

    constructor() {
    }

    /// @dev To support open-zeppelin/upgrades
    /// @param governance IFortGovernance implementation contract address
    function initialize(address governance) public override {
        super.initialize(governance);
        _futures.push();
    }

    /// @dev 返回指定期权当前的价值
    /// @param index 目标期权索引号
    /// @param oraclePrice 预言机价格
    /// @param addr 目标地址
    function balanceOf(uint index, uint oraclePrice, address addr) external view override returns (uint) {
        FutureInfo storage fi = _futures[index];
        Account memory account = fi.accounts[addr];
        return _balanceOf(
            uint(account.balance), 
            _decodeFloat(account.basePrice), 
            uint(account.baseBlock),
            oraclePrice, 
            fi.orientation, 
            uint(fi.lever)
        );
    }

    /// @dev 查找目标账户的合约
    /// @param start 从给定的合约地址对应的索引向前查询（不包含start对应的记录）
    /// @param count 最多返回的记录条数
    /// @param maxFindCount 最多查找maxFindCount记录
    /// @param owner 目标账户地址
    /// @return futureArray 合约信息列表
    function find(
        uint start, 
        uint count, 
        uint maxFindCount, 
        address owner
    ) external view override returns (FutureView[] memory futureArray) {
        
        futureArray = new FutureView[](count);
        
        // 计算查找区间i和end
        FutureInfo[] storage futures = _futures;
        uint i = futures.length;
        uint end = 0;
        if (start > 0) {
            i = start;
        }
        if (i > maxFindCount) {
            end = i - maxFindCount;
        }
        
        // 循环查找，将符合条件的记录写入缓冲区
        for (uint index = 0; index < count && i > end;) {
            FutureInfo storage fi = futures[--i];
            if (uint(fi.accounts[owner].balance) > 0) {
                futureArray[index++] = _toFutureView(fi, i, owner);
            }
        }
    }

    /// @dev 列出历史永续合约地址
    /// @param offset Skip previous (offset) records
    /// @param count Return (count) records
    /// @param order Order. 0 reverse order, non-0 positive order
    /// @return futureArray List of price sheets
    function list(
        uint offset, 
        uint count, 
        uint order
    ) external view override returns (FutureView[] memory futureArray) {

        // 加载代币数组
        FutureInfo[] storage futures = _futures;
        // 创建结果数组
        futureArray = new FutureView[](count);
        uint length = futures.length;
        uint i = 0;

        // 倒序
        if (order == 0) {
            uint index = length - offset;
            uint end = index > count ? index - count : 0;
            while (index > end) {
                FutureInfo storage fi = futures[--index];
                futureArray[i++] = _toFutureView(fi, index, msg.sender);
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
                futureArray[i++] = _toFutureView(futures[index], index, msg.sender);
                ++index;
            }
        }
    }

    /// @dev 创建永续合约
    /// @param tokenAddress 永续合约的标的地产代币地址，0表示eth
    /// @param lever 杠杆倍数
    /// @param orientation 看涨/看跌两个方向。true：看涨，false：看跌
    function create(
        address tokenAddress, 
        uint lever,
        bool orientation
    ) external override onlyGovernance {

        // 检查永续合约是否已经存在
        uint key = _getKey(tokenAddress, lever, orientation);
        uint index = _futureMapping[key];
        require(index == 0, "HF:exists");

        // 创建永续合约
        index = _futures.length;
        FutureInfo storage fi = _futures.push();
        fi.tokenAddress = tokenAddress;
        fi.lever = uint32(lever);
        fi.orientation = orientation;
        _futureMapping[key] = index;

        // 创建永续合约事件
        emit New(tokenAddress, lever, orientation, index);
    }

    /// @dev 获取已经开通的永续合约数量
    /// @return 已经开通的永续合约数量
    function getFutureCount() external view override returns (uint) {
        return _futures.length;
    }

    /// @dev 获取永续合约信息
    /// @param tokenAddress 永续合约的标的地产代币地址，0表示eth
    /// @param lever 杠杆倍数
    /// @param orientation 看涨/看跌两个方向。true：看涨，false：看跌
    /// @return 永续合约地址
    function getFutureInfo(
        address tokenAddress, 
        uint lever,
        bool orientation
    ) external view override returns (FutureView memory) {
        uint index = _futureMapping[_getKey(tokenAddress, lever, orientation)];
        return _toFutureView(_futures[index], index, msg.sender);
    }

    /// @dev 买入永续合约
    /// @param tokenAddress 永续合约的标的地产代币地址，0表示eth
    /// @param lever 杠杆倍数
    /// @param orientation 看涨/看跌两个方向。true：看涨，false：看跌
    /// @param dcuAmount 支付的dcu数量
    function buy(
        address tokenAddress,
        uint lever,
        bool orientation,
        uint dcuAmount
    ) external payable override {
        uint index = _futureMapping[_getKey(tokenAddress, lever, orientation)];
        require(index != 0, "HF:not exist");
        _buy(_futures[index], index, dcuAmount, tokenAddress, orientation);
    }

    /// @dev 买入永续合约
    /// @param index 永续合约编号
    /// @param dcuAmount 支付的dcu数量
    function buyDirect(uint index, uint dcuAmount) public payable override {
        require(index != 0, "HF:not exist");
        FutureInfo storage fi = _futures[index];
        _buy(fi, index, dcuAmount, fi.tokenAddress, fi.orientation);
    }

    /// @dev 卖出永续合约
    /// @param index 永续合约编号
    /// @param amount 卖出数量
    function sell(uint index, uint amount) external payable override {

        // 1. 销毁用户的永续合约
        require(index != 0, "HF:not exist");
        FutureInfo storage fi = _futures[index];
        bool orientation = fi.orientation;

        // 看涨的时候，初始价格乘以(1+k)，卖出价格除以(1+k)
        // 看跌的时候，初始价格除以(1+k)，卖出价格乘以(1+k)
        // 合并的时候，s0用记录的价格，s1用k修正的
        uint oraclePrice = _queryPrice(0, fi.tokenAddress, !orientation, msg.sender);

        // 更新目标账号信息
        Account memory account = fi.accounts[msg.sender];

        account.balance -= _toUInt128(amount);
        fi.accounts[msg.sender] = account;

        // 2. 给用户分发dcu
        uint value = _balanceOf(
            amount, 
            _decodeFloat(account.basePrice), 
            uint(account.baseBlock),
            oraclePrice, 
            orientation, 
            uint(fi.lever)
        );
        DCU(DCU_TOKEN_ADDRESS).mint(msg.sender, value);

        // 卖出事件
        emit Sell(index, amount, msg.sender, value);
    }

    /// @dev 清算
    /// @param index 永续合约编号
    /// @param addresses 清算目标账号数组
    function settle(uint index, address[] calldata addresses) external payable override {

        // 1. 销毁用户的永续合约
        require(index != 0, "HF:not exist");
        FutureInfo storage fi = _futures[index];
        uint lever = uint(fi.lever);

        if (lever > 1) {

            bool orientation = fi.orientation;
            // 看涨的时候，初始价格乘以(1+k)，卖出价格除以(1+k)
            // 看跌的时候，初始价格除以(1+k)，卖出价格乘以(1+k)
            // 合并的时候，s0用记录的价格，s1用k修正的
            uint oraclePrice = _queryPrice(0, fi.tokenAddress, !orientation, msg.sender);

            uint reward = 0;
            mapping(address=>Account) storage accounts = fi.accounts;
            for (uint i = addresses.length; i > 0;) {
                address acc = addresses[--i];

                // 更新目标账号信息
                Account memory account = accounts[acc];
                uint balance = _balanceOf(
                    uint(account.balance), 
                    _decodeFloat(account.basePrice), 
                    uint(account.baseBlock),
                    oraclePrice, 
                    orientation, 
                    lever
                );

                // 杠杆倍数大于1，并且余额小于最小额度时，可以清算
                // 改成当账户净值低于Max(保证金 * 2%*g, 10) 时，清算
                uint minValue = uint(account.balance) * lever / 50;
                if (balance < (minValue < MIN_VALUE ? MIN_VALUE : minValue)) {
                    accounts[acc] = Account(uint128(0), uint64(0), uint32(0));
                    reward += balance;
                    emit Settle(index, acc, msg.sender, balance);
                }
            }

            // 2. 给用户分发dcu
            if (reward > 0) {
                DCU(DCU_TOKEN_ADDRESS).mint(msg.sender, reward);
            }
        } else {
            if (msg.value > 0) {
                payable(msg.sender).transfer(msg.value);
            }
        }
    }

    // 根据杠杆信息计算索引key
    function _getKey(
        address tokenAddress, 
        uint lever,
        bool orientation
    ) private pure returns (uint) {
        //return keccak256(abi.encodePacked(tokenAddress, lever, orientation));
        require(lever < 0x100000000, "HF:lever to large");
        return (uint(uint160(tokenAddress)) << 96) | (lever << 8) | (orientation ? 1 : 0);
    }

    // 买入永续合约
    function _buy(FutureInfo storage fi, uint index, uint dcuAmount, address tokenAddress, bool orientation) private {

        require(dcuAmount >= 50 ether, "HF:at least 50 dcu");

        // 1. 销毁用户的dcu
        DCU(DCU_TOKEN_ADDRESS).burn(msg.sender, dcuAmount);

        // 2. 给用户分发永续合约
        // 看涨的时候，初始价格乘以(1+k)，卖出价格除以(1+k)
        // 看跌的时候，初始价格除以(1+k)，卖出价格乘以(1+k)
        // 合并的时候，s0用记录的价格，s1用k修正的
        uint oraclePrice = _queryPrice(dcuAmount, tokenAddress, orientation, msg.sender);

        Account memory account = fi.accounts[msg.sender];
        uint basePrice = _decodeFloat(account.basePrice);
        uint balance = uint(account.balance);
        uint newPrice = oraclePrice;
        if (uint(account.baseBlock) > 0) {
            newPrice = (balance + dcuAmount) * oraclePrice * basePrice / (
                basePrice * dcuAmount + (balance << 64) * oraclePrice / _expMiuT(orientation, uint(account.baseBlock))
            );
        }
        
        // 更新接收账号信息
        account.balance = _toUInt128(balance + dcuAmount);
        account.basePrice = _encodeFloat(newPrice);
        account.baseBlock = uint32(block.number);
        
        fi.accounts[msg.sender] = account;

        // 买入事件
        emit Buy(index, dcuAmount, msg.sender);
    }

    // 查询预言机价格
    function _queryPrice(uint dcuAmount, address tokenAddress, bool enlarge, address payback) private returns (uint oraclePrice) {
        //require(tokenAddress== address(0), "HF:only support eth/usdt");

        // 获取usdt相对于eth的价格
        uint[] memory prices = _lastPriceList(tokenAddress, msg.value, payback);
        
        // 将token价格转化为以usdt为单位计算的价格
        oraclePrice = prices[1];
        uint k = calcRevisedK(prices[3], prices[2], oraclePrice, prices[0]);

        // 看涨的时候，初始价格乘以(1+k)，卖出价格除以(1+k)
        // 看跌的时候，初始价格除以(1+k)，卖出价格乘以(1+k)
        // 合并的时候，s0用记录的价格，s1用k修正的
        if (enlarge) {
            oraclePrice = oraclePrice * (1 ether + k + impactCost(dcuAmount)) / 1 ether;
        } else {
            oraclePrice = oraclePrice * 1 ether / (1 ether + k + impactCost(dcuAmount));
        }
    }

    /// @dev Calculate the impact cost
    /// @param vol Trade amount in dcu
    /// @return Impact cost
    function impactCost(uint vol) public pure override returns (uint) {
        //impactCost = vol / 10000 / 1000;

        // TODO: 测试时不计算冲击成本
        return 0;
        return vol / 10000000;
    }

    /// @dev K value is calculated by revised volatility
    /// @param p0 Last price (number of tokens equivalent to 1 ETH)
    /// @param bn0 Block number of the last price
    /// @param p Latest price (number of tokens equivalent to 1 ETH)
    /// @param bn The block number when (ETH, TOKEN) price takes into effective
    function calcRevisedK(uint p0, uint bn0, uint p, uint bn) public view override returns (uint k) {
        uint sigmaISQ = p * 1 ether / p0;
        if (sigmaISQ > 1 ether) {
            sigmaISQ -= 1 ether;
        } else {
            sigmaISQ = 1 ether - sigmaISQ;
        }

        // James:
        // fort算法 把前面一项改成 max ((p2-p1)/p1,0.002) 后面不变
        // jackson:
        // 好
        // jackson:
        // 要取绝对值吧
        // James:
        // 对的
        if (sigmaISQ > 0.002 ether) {
            k = sigmaISQ;
        } else {
            k = 0.002 ether;
        }

        // sigmaISQ = sigmaISQ * sigmaISQ / (bn - bn0) / BLOCK_TIME / 1 ether;
        sigmaISQ = sigmaISQ * sigmaISQ / (bn - bn0) / BLOCK_TIME / 1e15;

        if (sigmaISQ > SIGMA_SQ) {
            // k += _sqrt(1 ether * BLOCK_TIME * (block.number - bn) * sigmaISQ);
            k += _sqrt(1e15 * BLOCK_TIME * (block.number - bn) * sigmaISQ);
        } else {
            // k += _sqrt(1 ether * BLOCK_TIME * SIGMA_SQ * (block.number - bn));
            k += _sqrt(1e15 * BLOCK_TIME * SIGMA_SQ * (block.number - bn));
        }

        // TODO: 测试时不计算k
        k = 0;
    }

    function _sqrt(uint256 x) private pure returns (uint256) {
        unchecked {
            if (x == 0) return 0;
            else {
                uint256 xx = x;
                uint256 r = 1;
                if (xx >= 0x100000000000000000000000000000000) { xx >>= 128; r <<= 64; }
                if (xx >= 0x10000000000000000) { xx >>= 64; r <<= 32; }
                if (xx >= 0x100000000) { xx >>= 32; r <<= 16; }
                if (xx >= 0x10000) { xx >>= 16; r <<= 8; }
                if (xx >= 0x100) { xx >>= 8; r <<= 4; }
                if (xx >= 0x10) { xx >>= 4; r <<= 2; }
                if (xx >= 0x8) { r <<= 1; }
                r = (r + x / r) >> 1;
                r = (r + x / r) >> 1;
                r = (r + x / r) >> 1;
                r = (r + x / r) >> 1;
                r = (r + x / r) >> 1;
                r = (r + x / r) >> 1;
                r = (r + x / r) >> 1; // Seven iterations should be enough
                uint256 r1 = x / r;
                return (r < r1 ? r : r1);
            }
        }
    }

    /// @dev Encode the uint value as a floating-point representation in the form of fraction * 16 ^ exponent
    /// @param value Destination uint value
    /// @return float format
    function _encodeFloat(uint value) private pure returns (uint64) {

        uint exponent = 0; 
        while (value > 0x3FFFFFFFFFFFFFF) {
            value >>= 4;
            ++exponent;
        }
        return uint64((value << 6) | exponent);
    }

    /// @dev Decode the floating-point representation of fraction * 16 ^ exponent to uint
    /// @param floatValue fraction value
    /// @return decode format
    function _decodeFloat(uint64 floatValue) private pure returns (uint) {
        return (uint(floatValue) >> 6) << ((uint(floatValue) & 0x3F) << 2);
    }

    // 将uint转化为uint128，有截断检查
    function _toUInt128(uint value) private pure returns (uint128) {
        require(value < 0x100000000000000000000000000000000);
        return uint128(value);
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
    
    // 根据新价格计算账户余额
    function _balanceOf(
        uint balance,
        uint basePrice,
        uint baseBlock,
        uint oraclePrice, 
        bool ORIENTATION, 
        uint LEVER
    ) private view returns (uint) {

        if (balance > 0) {
            //uint price = _decodeFloat(account.price);

            uint left;
            uint right;
            // 看涨
            if (ORIENTATION) {
                left = balance + (LEVER << 64) * balance * oraclePrice / basePrice / _expMiuT(ORIENTATION, baseBlock);
                right = balance * LEVER;
            } 
            // 看跌
            else {
                left = balance * (1 + LEVER);
                right = (LEVER << 64) * balance * oraclePrice / basePrice / _expMiuT(ORIENTATION, baseBlock);
            }

            if (left > right) {
                balance = left - right;
            } else {
                balance = 0;
            }
        }

        return balance;
    }

    // 计算 e^μT
    function _expMiuT(bool orientation, uint baseBlock) private view returns (uint) {
        // return _toUInt(ABDKMath64x64.exp(
        //     _toInt128((orientation ? MIU_LONG : MIU_SHORT) * (block.number - baseBlock) * BLOCK_TIME)
        // ));

        // 改为单利近似计算: x*(1+rt)
        // by chenf 2021-12-28 15:27

        // 64位二进制精度的1
        //int128 constant ONE = 0x10000000000000000;
        //return (orientation ? MIU_LONG : MIU_SHORT) * (block.number - baseBlock) * BLOCK_TIME + 0x10000000000000000;
        return (orientation ? MIU_LONG : MIU_SHORT) * (block.number - baseBlock) * BLOCK_TIME / 1000 + 0x10000000000000000;
    }

    // 转换永续合约信息
    function _toFutureView(FutureInfo storage fi, uint index, address owner) private view returns (FutureView memory) {
        Account memory account = fi.accounts[owner];
        return FutureView(
            index,
            fi.tokenAddress,
            uint(fi.lever),
            fi.orientation,
            uint(account.balance),
            _decodeFloat(account.basePrice),
            uint(account.baseBlock)
        );
    }
}
