// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

/**
    Note: The ERC-165 identifier for this interface is 0x4e2312e0.
*/
interface ERC1155TokenReceiver {
    /** 
    @notice 处理单个 ERC1155 令牌类型的接收。 
    @dev 符合 ERC1155 的智能合约必须在余额更新后的“safeTransferFrom”结束时在代币接收者合约上调用此函数。
    如果该函数接受传输，则必须返回 `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`（即 0xf23a6e61）。
    如果拒绝传输，该函数必须恢复。返回除规定的 keccak256 生成值之外的任何其他值必须导致调用者恢复事务。 
    @param _operator 发起传输的地址（即 msg.sender） 
    @param _from 之前拥有代币的地址 
    @param _id 正在传输的代币的 ID 
    @param _value 正在传输的代币数量 
    @param _data 附加数据没有指定格式 
    @return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))` 
    */
    function onERC1155Received(
        address _operator,
        address _from,
        uint256 _id,
        uint256 _value,
        bytes calldata _data
    ) external returns (bytes4);

    /** 
    @notice 处理多个 ERC1155 令牌类型的接收。 
    @dev 符合 ERC1155 的智能合约必须在余额更新后的“safeBatchTransferFrom”结束时在代币接收者合约上调用此函数。
    如果此函数接受传输，则必须返回 `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`（即 0xbc197c81）。
    如果拒绝传输，该函数必须恢复。返回除规定的 keccak256 生成值之外的任何其他值必须导致调用者恢复事务。 
    @param _operator 发起批量传输的地址（即 msg.sender） 
    @param _from 先前拥有令牌的地址 
    @param _ids 包含正在传输的每个令牌的 id 的数组（顺序和长度必须匹配 _values 数组） 
    @param _values包含正在传输的每个令牌数量的数组（顺序和长度必须与 _ids 数组匹配）
    @param _data 没有指定格式的附加数据 
    @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes )"))` 
    */
    function onERC1155BatchReceived(
        address _operator,
        address _from,
        uint256[] calldata _ids,
        uint256[] calldata _values,
        bytes calldata _data
    ) external returns (bytes4);
}
