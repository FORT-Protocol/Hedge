// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./libs/TransferHelper.sol";

import "./interfaces/IFortDAO.sol";

import "./FortBase.sol";

/// @dev Management of cofix public funds
contract FortDAO is FortBase, IFortDAO {

    // Configuration
    //Config _config;

    // DAO applications
    mapping(address=>uint) _applications;

    /// @dev Create FortDAO contract
    constructor() {
    }

    // /// @dev Rewritten in the implementation contract, for load other contract addresses. Call 
    // ///      super.update(newGovernance) when overriding, and override method without onlyGovernance
    // /// @param newGovernance IFortGovernance implementation contract address
    // function update(address newGovernance) public override {
    //     super.update(newGovernance);
    //     _cofixController = IFortGovernance(newGovernance).getFortControllerAddress();
    // }

    // /// @dev Modify configuration
    // /// @param config Configuration object
    // function setConfig(Config calldata config) external override onlyGovernance {
    //     _config = config;
    // }

    // /// @dev Get configuration
    // /// @return Configuration object
    // function getConfig() external view override returns (Config memory) {
    //     return _config;
    // }

    /// @dev Set DAO application
    /// @param addr DAO application contract address
    /// @param flag Authorization flag, 1 means authorization, 0 means cancel authorization
    function setApplication(address addr, uint flag) external override onlyGovernance {
        _applications[addr] = flag;
        emit ApplicationChanged(addr, flag);
    }

    /// @dev Check DAO application flag
    /// @param addr DAO application contract address
    /// @return Authorization flag, 1 means authorization, 0 means cancel authorization
    function checkApplication(address addr) external view override returns (uint) {
        return _applications[addr];
    }

    /// @dev Add reward
    /// @param pool Destination pool
    function addETHReward(address pool) external payable override {
        //require(pool != address(0));
    }

    /// @dev The function returns eth rewards of specified pool
    /// @param pool Destination pool
    function totalETHRewards(address pool) external view override returns (uint) {
        //require(pool != address(0));
        return address(this).balance;
    }

    /// @dev Settlement
    /// @param pool Destination pool. Indicates which pool to pay with
    /// @param tokenAddress Token address of receiving funds (0 means ETH)
    /// @param to Address to receive
    /// @param value Amount to receive
    function settle(address pool, address tokenAddress, address to, uint value) external payable override {
        //require(pool != address(0));
        require(_applications[msg.sender] == 1, "FortDAO:!app");

        // Pay eth from ledger
        if (tokenAddress == address(0)) {
            // pay
            payable(to).transfer(value);
        }
        // Pay token
        else {
            // pay
            TransferHelper.safeTransfer(tokenAddress, to, value);
        }
    }
}
