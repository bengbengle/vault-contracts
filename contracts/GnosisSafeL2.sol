// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import "./GnosisSafe.sol";

/// @title Gnosis Safe - 一个多重签名钱包，支持使用基于 ERC191 的签名消息进行确认。 
// 我们将 nonce、sender 和 threshold 合二为一，以避免堆栈过深 
// 开发说明： additionalInfo 不应包含 `bytes`，因为这会使解码复杂化
contract GnosisSafeL2 is GnosisSafe {
    event SafeMultiSigTransaction(
        address to,
        uint256 value,
        bytes data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes signatures,
        bytes additionalInfo
    );

    event SafeModuleTransaction(address module, address to, uint256 value, bytes data, Enum.Operation operation);

    /// @dev 允许执行由所需数量的所有者确认的安全交易，然后支付提交交易的账户。 
    /// 注意：即使用户交易失败，费用也会一直转移。 
    /// @param to 安全事务的目标地址。 
    /// @param value 安全交易的以太币值。 
    /// @param data 安全事务的数据负载。 
    /// @param operation 安全事务的操作类型。 
    /// @param safeTxGas 应该用于安全交易的气体。 
    /// @param baseGas 独立于交易执行的 Gas 成本（例如基本交易费、签名检查、退款支付） 
    /// @param gasPrice 应该用于支付计算的 Gas 价格。 
    /// @param gasToken 用于支付的代币地址（如果是 ETH，则为 0）。 
    /// @param refundReceiver gas 支付接收方地址（如果 tx.origin 则为 0）。 
    /// @param signatures 打包的签名数据 ({bytes32 r}{bytes32 s}{uint8 v})
    function execTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes memory signatures
    ) public payable override returns (bool) {
        bytes memory additionalInfo;
        {
            additionalInfo = abi.encode(nonce, msg.sender, threshold);
        }
        emit SafeMultiSigTransaction(
            to,
            value,
            data,
            operation,
            safeTxGas,
            baseGas,
            gasPrice,
            gasToken,
            refundReceiver,
            signatures,
            additionalInfo
        );
        return super.execTransaction(to, value, data, operation, safeTxGas, baseGas, gasPrice, gasToken, refundReceiver, signatures);
    }

    /// @dev 允许模块在没有任何进一步确认的情况下执行安全事务 
    /// @param to 模块事务的目标地址
    /// @param value 模块交易的以太币值 
    /// @param data 模块事务的数据负载 
    /// @param operation 模块事务的操作类型
    function execTransactionFromModule(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation
    ) public override returns (bool success) {
        emit SafeModuleTransaction(msg.sender, to, value, data, operation);
        success = super.execTransactionFromModule(to, value, data, operation);
    }
}
