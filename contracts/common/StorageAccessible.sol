// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

/// @title StorageAccessible - 通用基础合约 , 允许调用者访问所有内部存储
/// @notice See https://github.com/gnosis/util-contracts/blob/bb5fe5fb5df6d8400998094fb1b32a178a47c3a1/contracts/StorageAccessible.sol
contract StorageAccessible {
    /**
     * @dev 读取当前合约中存储的 `length` 字节 
     * @param offset - 当前合约存储中要开始读取的字数 
     * @param length - 要读取的数据字数（32 字节）
     * @return 读取的字节数 
     */
    function getStorageAt(uint256 offset, uint256 length) public view returns (bytes memory) {
        bytes memory result = new bytes(length * 32);
        for (uint256 index = 0; index < length; index++) {
            // solhint-disable-next-line no-inline-assembly
            assembly {
                let word := sload(add(offset, index))
                mstore(add(add(result, 0x20), mul(index, 0x20)), word)
            }
        }
        return result;
    }

    /**
     * @dev 在 self 的上下文中对 targetContract 执行委托调用  
     * 在内部恢复执行以避免副作用（使其成为静态）  
     * 
     * 此方法使用等于 `abi.encode(bool(success), bytes(response))` 的数据恢复  
     * 具体来说 , 调用此方法后的 `returndata` 将是： `success:bool || 响应长度：uint256 || 响应：字节`  
     * 
     * @param targetContract 包含要执行的代码的合约地址  
     * @param calldataPayload 应该发送到目标合约的调用数据（编码的方法名称和参数） 
     */
    function simulateAndRevert(address targetContract, bytes memory calldataPayload) external {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let success := delegatecall(gas(), targetContract, add(calldataPayload, 0x20), mload(calldataPayload), 0, 0)

            mstore(0x00, success)
            mstore(0x20, returndatasize())
            returndatacopy(0x40, 0, returndatasize())
            revert(0, add(returndatasize(), 0x40))
        }
    }
}
