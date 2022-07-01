// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import "./DefaultCallbackHandler.sol";
import "../interfaces/ISignatureValidator.sol";
import "../GnosisSafe.sol";

/// @title Compatibility Fallback Handler - fallback handler to provider compatibility between pre 1.3.0 and 1.3.0+ Safe contracts
contract CompatibilityFallbackHandler is DefaultCallbackHandler, ISignatureValidator {
    //keccak256(
    //    "SafeMessage(bytes message)"
    //);
    bytes32 private constant SAFE_MSG_TYPEHASH = 0x60b3cbf8b4a223d68d641b3b6ddf9a298e7f33710cf3d3a9d1146b5a6150fbca;

    bytes4 internal constant SIMULATE_SELECTOR = bytes4(keccak256("simulate(address,bytes)"));

    address internal constant SENTINEL_MODULES = address(0x1);
    bytes4 internal constant UPDATED_MAGIC_VALUE = 0x1626ba7e;

    /**
     * ISignatureValidator 的实现（参见`interfaces/ISignatureValidator.sol`） 
     * @dev 应该返回所提供的签名对于所提供的数据是否有效  
     * @param _data 代表地址（msg.sender）签名的任意长度数据 
     * @param _signature 与_data 关联的签名字节数组 
     * @return 对应_data的有效或无效签名的布尔值
     */
    function isValidSignature(bytes memory _data, bytes memory _signature) public view override returns (bytes4) {
        // Caller should be a Safe
        GnosisSafe safe = GnosisSafe(payable(msg.sender));
        bytes32 messageHash = getMessageHashForSafe(safe, _data);
        if (_signature.length == 0) {
            require(safe.signedMessages(messageHash) != 0, "Hash not approved");
        } else {
            safe.checkSignatures(messageHash, _data, _signature);
        }
        return EIP1271_MAGIC_VALUE;
    }

    /// @dev 返回可以由所有者签名的消息的哈希值  
    /// @param message 应该被散列的消息 
    /// @return 消息散列 
    function getMessageHash(bytes memory message) public view returns (bytes32) {
        return getMessageHashForSafe(GnosisSafe(payable(msg.sender)), message);
    }
    
    /// @dev 返回可以由所有者签名的消息的哈希值  
    /// @param safe 消息的目标安全 
    /// @param message 应该被散列的消息 
    /// @return 消息散列 
    function getMessageHashForSafe(GnosisSafe safe, bytes memory message) public view returns (bytes32) {
        bytes32 safeMessageHash = keccak256(abi.encode(SAFE_MSG_TYPEHASH, keccak256(message)));
        return keccak256(abi.encodePacked(bytes1(0x19), bytes1(0x01), safe.domainSeparator(), safeMessageHash));
    }

    /**
     * Implementation of updated EIP-1271
     * @dev Should return whether the signature provided is valid for the provided data.
     *       The save does not implement the interface since `checkSignatures` is not a view method.
     *       The method will not perform any state changes (see parameters of `checkSignatures`)
     * @param _dataHash Hash of the data signed on the behalf of address(msg.sender)
     * @param _signature Signature byte array associated with _dataHash
     * @return a bool upon valid or invalid signature with corresponding _dataHash
     * @notice See https://github.com/gnosis/util-contracts/blob/bb5fe5fb5df6d8400998094fb1b32a178a47c3a1/contracts/StorageAccessible.sol
     */
    function isValidSignature(bytes32 _dataHash, bytes calldata _signature) external view returns (bytes4) {
        ISignatureValidator validator = ISignatureValidator(msg.sender);
        bytes4 value = validator.isValidSignature(abi.encode(_dataHash), _signature);
        return (value == EIP1271_MAGIC_VALUE) ? UPDATED_MAGIC_VALUE : bytes4(0);
    }

    /// @dev 返回前 10 个模块的数组
    /// @return Array of modules.
    function getModules() external view returns (address[] memory) {
        // Caller 应该是保险箱
        GnosisSafe safe = GnosisSafe(payable(msg.sender));
        (address[] memory array, ) = safe.getModulesPaginated(SENTINEL_MODULES, 10);
        return array;
    }

    /**
    * @dev 在 self 的上下文中对 targetContract 执行委托调用  * 在内部恢复执行以避免副作用（使其成为静态） 捕获还原并将编码结果作为字节返回  
    * @param targetContract 包含要执行的代码的合约地址  
    * @param calldataPayload 应该发送到目标合约的调用数据（编码的方法名称和参数） 
    */
    function simulate(address targetContract, bytes calldata calldataPayload) external returns (bytes memory response) {
        // 禁止编译器关于不使用参数的警告 , 同时允许参数保留名称 以用于文档目的  这不会​​生成代码 
        targetContract;
        calldataPayload;

        // solhint-disable-next-line no-inline-assembly
        assembly {
            let internalCalldata := mload(0x40)
            // Store `simulateAndRevert.selector`.
            // String representation is used to force right padding
            mstore(internalCalldata, "\xb4\xfa\xba\x09")
            // Abuse the fact that both this and the internal methods have the
            // same signature, and differ only in symbol name (and therefore,
            // selector) and copy calldata directly. This saves us approximately
            // 250 bytes of code and 300 gas at runtime over the
            // `abi.encodeWithSelector` builtin.
            calldatacopy(add(internalCalldata, 0x04), 0x04, sub(calldatasize(), 0x04))

            // `pop` is required here by the compiler, as top level expressions
            // can't have return values in inline assembly. `call` typically
            // returns a 0 or 1 value indicated whether or not it reverted, but
            // since we know it will always revert, we can safely ignore it.
            pop(
                call(
                    gas(),
                    // address() has been changed to caller() to use the implementation of the Safe
                    caller(),
                    0,
                    internalCalldata,
                    calldatasize(),
                    // The `simulateAndRevert` call always reverts, and
                    // instead encodes whether or not it was successful in the return
                    // data. The first 32-byte word of the return data contains the
                    // `success` value, so write it to memory address 0x00 (which is
                    // reserved Solidity scratch space and OK to use).
                    0x00,
                    0x20
                )
            )

            // Allocate and copy the response bytes, making sure to increment
            // the free memory pointer accordingly (in case this method is
            // called as an internal function). The remaining `returndata[0x20:]`
            // contains the ABI encoded response bytes, so we can just write it
            // as is to memory.
            let responseSize := sub(returndatasize(), 0x20)
            response := mload(0x40)
            mstore(0x40, add(response, responseSize))
            returndatacopy(response, 0x20, responseSize)

            if iszero(mload(0x00)) {
                revert(add(response, 0x20), mload(response))
            }
        }
    }
}
