// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

/// @title SelfAuthorized - 授权当前合约执行操作
contract SelfAuthorized {
    function requireSelfCall() private view {
        require(msg.sender == address(this), "GS031");
    }

    modifier authorized() {
        // 这是一个函数调用， 因为它最小化了字节码大小
        requireSelfCall();
        _;
    }
}
