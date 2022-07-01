pragma solidity >=0.5.0 <0.9.0;

/// @title ViewStorageAccessible - StorageAccessible 基类之上的接口 ,  允许从 view 函数进行模拟
/// @notice Adjusted version of https://github.com/gnosis/util-contracts/blob/3db1e531cb243a48ea91c60a800d537c1000612a/contracts/StorageAccessible.sol
interface ViewStorageAccessible {
    /** 
    * @dev 与 StorageAccessible 上的 `simulate` 相同  标记为 view  ,  以便可以从希望从 view 函数中运行模拟的外部合约调用它 
    如果调用的模拟尝试更改状态 , 将恢复  
    */
    function simulate(address targetContract, bytes calldata calldataPayload) external view returns (bytes memory);
}
