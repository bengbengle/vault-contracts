// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

/// @dev Note: the ERC-165 identifier for this interface is 0x150b7a02.
interface ERC721TokenReceiver {
    /// @notice 处理 NFT 的收据
    /// @dev ERC721 智能合约在“转移”之后在接收者上调用此函数。此 函数可能会抛出以恢复和拒绝传输。魔术值以外的返回必须导致事务被还原。
    /// 注意：合约地址始终是消息发送者。
    /// @param _operator 调用 `safeTransferFrom` 函数的地址
    /// @param _from 先前拥有令牌的地址
    /// @param _tokenId 正在传输的 NFT 标识符
    /// @param _data 没有附加数据指定格式
    /// @return `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))` 除非抛出。
    function onERC721Received(
        address _operator,
        address _from,
        uint256 _tokenId,
        bytes calldata _data
    ) external returns (bytes4);
}
