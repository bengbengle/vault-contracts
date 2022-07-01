// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import "./GnosisSafeStorage.sol";
import "../GnosisSafe.sol";

/// @title SignMessageLib - 允许在 signedMessages 中设置一个对象
contract SignMessageLib is GnosisSafeStorage {
    //keccak256(
    //    "SafeMessage(bytes message)"
    //);
    bytes32 private constant SAFE_MSG_TYPEHASH = 0x60b3cbf8b4a223d68d641b3b6ddf9a298e7f33710cf3d3a9d1146b5a6150fbca;

    event SignMsg(bytes32 indexed msgHash);

    /// @dev 将消息标记为已签名 ,  以便它可以与 EIP-1271 一起使用 将消息 (`_data`) 标记为已签名  
    /// @param _data 任意长度的数据 ,  应该标记为代表地址签名的数据（this）
    function signMessage(bytes calldata _data) external {
        bytes32 msgHash = getMessageHash(_data);
        signedMessages[msgHash] = 1;
        emit SignMsg(msgHash);
    }

    /// @dev 返回可以由所有者签名的消息的哈希值  
    /// @param message 应该被散列的消息 
    /// @return 消息散列 
    function getMessageHash(bytes memory message) public view returns (bytes32) {
        bytes32 safeMessageHash = keccak256(abi.encode(SAFE_MSG_TYPEHASH, keccak256(message)));
        return
            keccak256(abi.encodePacked(bytes1(0x19), bytes1(0x01), GnosisSafe(payable(address(this))).domainSeparator(), safeMessageHash));
    }
}
