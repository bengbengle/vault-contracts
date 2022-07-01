// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

contract ISignatureValidatorConstants {
    // bytes4(keccak256("isValidSignature(bytes,bytes)")
    bytes4 internal constant EIP1271_MAGIC_VALUE = 0x20c13b0b;
}

abstract contract ISignatureValidator is ISignatureValidatorConstants {
    /**
     * @dev 应该返回提供的签名是否对提供的数据有效 
     * @param _data 代表地址（this）签名的任意长度数据 
     * @param _signature 与_data关联的签名字节数组 
     * 
     * 必须返回 bytes4 魔术值 0x20c13b0b当函数通过时  
     * 不得修改状态（对于 solc < 0.5 使用 STATICCALL , 对于 solc > 0.5 使用视图修饰符） 
     * 必须允许外部调用

     */
    function isValidSignature(bytes memory _data, bytes memory _signature) public view virtual returns (bytes4);
}
