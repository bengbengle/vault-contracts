// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

/// @title IProxy - 访问链上 Proxy 的 masterCopy 的 Helper 接口
interface IProxy {
    function masterCopy() external view returns (address);
}

/// @title GnosisSafeProxy - 通用代理合约允许执行应用主合约代码的所有交易
contract GnosisSafeProxy {
    // 单例总是需要首先声明变量，以确保它在委托调用的合约中的相同位置， 为了降低部署成本，这个变量是内部变量，需要通过 `getStorageAt` 检索
    address internal singleton;

    /// @dev 构造函数设置单例合约的地址。
    /// @param _singleton Singleton address.
    constructor(address _singleton) {
        require(_singleton != address(0), "Invalid singleton address provided");
        singleton = _singleton;
    }

    /// @dev Fallback 函数转发所有交易并返回所有收到的返回数据
    fallback() external payable {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let _singleton := and(sload(0), 0xffffffffffffffffffffffffffffffffffffffff)
            // 0xa619486e == keccak("masterCopy()"). The value is right padded to 32-bytes with 0s
            if eq(calldataload(0), 0xa619486e00000000000000000000000000000000000000000000000000000000) {
                mstore(0, _singleton)
                return(0, 0x20)
            }
            calldatacopy(0, 0, calldatasize())
            let success := delegatecall(gas(), _singleton, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            if eq(success, 0) {
                revert(0, returndatasize())
            }
            return(0, returndatasize())
        }
    }
}
