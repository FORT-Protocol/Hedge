// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.6;

/// @dev 定义杠杆币交易接口
interface IFortLever {
    
    struct LeverView {
        uint index;
        address tokenAddress;
        uint lever;
        bool orientation;
        
        uint balance;
        // 基准价格
        uint basePrice;
        // 基准区块号
        uint baseBlock;
    }

    /// @dev 新杠杆币事件
    /// @param tokenAddress 杠杆币的标的地产代币地址，0表示eth
    /// @param lever 杠杆倍数
    /// @param orientation 看涨/看跌两个方向。true：看涨，false：看跌
    /// @param index 杠杆币编号
    event New(
        address tokenAddress, 
        uint lever,
        bool orientation,
        uint index
    );

    /// @dev 买入杠杆币事件
    /// @param index 杠杆币编号
    /// @param fortAmount 支付的fort数量
    event Buy(
        uint index,
        uint fortAmount,
        address owner
    );

    /// @dev 卖出杠杆币事件
    /// @param index 杠杆币编号
    /// @param amount 卖出数量
    /// @param owner 所有者
    /// @param value 获得的fort数量
    event Sell(
        uint index,
        uint amount,
        address owner,
        uint value
    );

    /// @dev 清算事件
    /// @param index 杠杆币编号
    /// @param addr 清算目标账号数组
    /// @param sender 清算发起账号
    /// @param reward 清算获得的fort数量
    event Settle(
        uint index,
        address addr,
        address sender,
        uint reward
    );
    
    /// @dev 返回指定期权当前的价值
    /// @param index 目标期权索引号
    /// @param oraclePrice 预言机价格
    /// @param addr 目标地址
    function balanceOf(uint index, uint oraclePrice, address addr) external view returns (uint);

    /// @dev 查找目标账户的合约
    /// @param start 从给定的合约地址对应的索引向前查询（不包含start对应的记录）
    /// @param count 最多返回的记录条数
    /// @param maxFindCount 最多查找maxFindCount记录
    /// @param owner 目标账户地址
    /// @return leverArray 合约信息列表
    function find(
        uint start, 
        uint count, 
        uint maxFindCount, 
        address owner
    ) external view returns (LeverView[] memory leverArray);

    /// @dev 列出历史杠杆币地址
    /// @param offset Skip previous (offset) records
    /// @param count Return (count) records
    /// @param order Order. 0 reverse order, non-0 positive order
    /// @return leverArray List of price sheets
    function list(uint offset, uint count, uint order) external view returns (LeverView[] memory leverArray);

    /// @dev 创建杠杆币
    /// @param tokenAddress 杠杆币的标的地产代币地址，0表示eth
    /// @param lever 杠杆倍数
    /// @param orientation 看涨/看跌两个方向。true：看涨，false：看跌
    function create(
        address tokenAddress, 
        uint lever,
        bool orientation
    ) external;

    /// @dev 获取已经开通的杠杆币数量
    /// @return 已经开通的杠杆币数量
    function getLeverCount() external view returns (uint);

    /// @dev 获取杠杆币信息
    /// @param tokenAddress 杠杆币的标的地产代币地址，0表示eth
    /// @param lever 杠杆倍数
    /// @param orientation 看涨/看跌两个方向。true：看涨，false：看跌
    /// @return 杠杆币地址
    function getLeverInfo(
        address tokenAddress, 
        uint lever,
        bool orientation
    ) external view returns (LeverView memory);

    /// @dev 买入杠杆币
    /// @param tokenAddress 杠杆币的标的地产代币地址，0表示eth
    /// @param lever 杠杆倍数
    /// @param orientation 看涨/看跌两个方向。true：看涨，false：看跌
    /// @param fortAmount 支付的fort数量
    function buy(
        address tokenAddress,
        uint lever,
        bool orientation,
        uint fortAmount
    ) external payable;

    /// @dev 买入杠杆币
    /// @param index 杠杆币编号
    /// @param fortAmount 支付的fort数量
    function buyDirect(
        uint index,
        uint fortAmount
    ) external payable;

    /// @dev 卖出杠杆币
    /// @param index 杠杆币编号
    /// @param amount 卖出数量
    function sell(
        uint index,
        uint amount
    ) external payable;

    /// @dev 清算
    /// @param index 杠杆币编号
    /// @param addresses 清算目标账号数组
    function settle(
        uint index,
        address[] calldata addresses
    ) external payable;
}
