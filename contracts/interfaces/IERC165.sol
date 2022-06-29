// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

/// @notice More details at https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/introspection/IERC165.sol
interface IERC165 {
    /**
    * @dev 如果此合约实现了由 `interfaceId` 定义的接口，则返回 true。
    * 
    * 此函数调用必须使用少于 30 000 个气体。 
    */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
