// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

/// @title Singleton - 单例合约的基础（应该始终是第一个超级合约）
/// 这个合约与我们的代理合约紧密耦合（参见 `proxies/GnosisSafeProxy.sol`）
contract Singleton {
    // 单例总 首先声明变量 ,  以确保它与 代理合约 中的位置相同  
    // 还应始终确保单独存储地址（使用完整字）
    address private singleton;
}
