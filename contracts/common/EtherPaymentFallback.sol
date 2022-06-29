// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

/// @title EtherPaymentFallback - 能接受 以太币支付 的 fallback 合约
contract EtherPaymentFallback {
    event SafeReceived(address indexed sender, uint256 value);

    /// @dev Fallback function 接受以太币交易
    receive() external payable {
        emit SafeReceived(msg.sender, msg.value);
    }
}
