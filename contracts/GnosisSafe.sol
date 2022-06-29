// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

import "./base/ModuleManager.sol";
import "./base/OwnerManager.sol";
import "./base/FallbackManager.sol";
import "./base/GuardManager.sol";
import "./common/EtherPaymentFallback.sol";
import "./common/Singleton.sol";
import "./common/SignatureDecoder.sol";
import "./common/SecuredTokenTransfer.sol";
import "./common/StorageAccessible.sol";
import "./interfaces/ISignatureValidator.sol";
import "./external/GnosisSafeMath.sol";

/// @title Gnosis Safe - A multisignature wallet with support for confirmations using signed messages based on ERC191.
contract GnosisSafe is
    EtherPaymentFallback,
    Singleton,
    ModuleManager,
    OwnerManager,
    SignatureDecoder,
    SecuredTokenTransfer,
    ISignatureValidatorConstants,
    FallbackManager,
    StorageAccessible,
    GuardManager
{
    using GnosisSafeMath for uint256;

    string public constant VERSION = "1.3.0";

    // keccak256(
    //     "EIP712Domain(uint256 chainId,address verifyingContract)"
    // );
    bytes32 private constant DOMAIN_SEPARATOR_TYPEHASH = 0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218;

    // keccak256(
    //     "SafeTx(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,uint256 nonce)"
    // );
    bytes32 private constant SAFE_TX_TYPEHASH = 0xbb8310d486368db6bd6f849402fdd73ad53d316b5a4b2644ad6efe0f941286d8;

    event SafeSetup(address indexed initiator, address[] owners, uint256 threshold, address initializer, address fallbackHandler);
    event ApproveHash(bytes32 indexed approvedHash, address indexed owner);
    event SignMsg(bytes32 indexed msgHash);
    event ExecutionFailure(bytes32 txHash, uint256 payment);
    event ExecutionSuccess(bytes32 txHash, uint256 payment);

    uint256 public nonce;
    bytes32 private _deprecatedDomainSeparator;
    // 映射以跟踪所有必需所有者已批准的所有消息哈希
    mapping(bytes32 => uint256) public signedMessages;
    // 映射以跟踪已被任何所有者批准的所有哈希（消息或交易）
    mapping(address => mapping(bytes32 => uint256)) public approvedHashes;
    
    // 此构造函数确保此合约只能用作代理合约的主副本
    constructor() {
        // 通过设置阈值，就不能再调用 setup， 
        // 所以我们创建了一个拥有 0 个所有者和阈值 1 的保险箱。 
        // 这是一个无法使用的保险箱，非常适合单例
        threshold = 1;
    }
    
    /// @dev 设置函数设置合约的初始存储。 
    /// @param _owners 安全所有者列表。 
    /// @param _threshold 安全交易所需的确认次数。 
    /// @param to 于可选委托调用的合约地址。 
    /// @param data 可选委托调用的数据负载。 
    /// @param fallbackHandler 该合约的回退调用处理程序 
    /// @param paymentToken 应该用于支付的令牌（0 是 ETH） 
    /// @param payment 应该支付的值 
    /// @param paymentReceiver 地址应该收到付款（如果 tx.origin 则为 0）
    function setup(
        address[] calldata _owners,
        uint256 _threshold,
        address to,
        bytes calldata data,
        address fallbackHandler,
        address paymentToken,
        uint256 payment,
        address payable paymentReceiver
    ) external {
        // setupOwners 检查是否已经设置了阈值，因此防止此方法被调用两次
        setupOwners(_owners, _threshold);
        if (fallbackHandler != address(0)) internalSetFallbackHandler(fallbackHandler);
        // 因为 setupOwners 只能在合约没有被初始化的情况下被调用，所以我们不需要检查 setupModules
        setupModules(to, data);

        if (payment > 0) {
            // 为了避免遇到 EIP-170 的问题，我们重用了 handlePayment 函数（为了避免调整已验证的代码，我们不会调整方法本身） 
            // baseGas = 0, gasPrice = 1 and gas = payment => amount = (付款 + 0) * 1 = 付款
            handlePayment(payment, 0, 1, paymentToken, paymentReceiver);
        }
        emit SafeSetup(msg.sender, _owners, _threshold, to, fallbackHandler);
    }

    /// @dev 允许执行由所需数量的所有者确认的安全交易，然后支付提交交易的帐户。 
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
    ) public payable virtual returns (bool success) {
        bytes32 txHash;
        // 这里使用作用域来限制变量的生命周期并防止 `stack too deep` 错误
        {
            bytes memory txHashData =
                encodeTransactionData(
                    // Transaction info
                    to,
                    value,
                    data,
                    operation,
                    safeTxGas,
                    // Payment info
                    baseGas,
                    gasPrice,
                    gasToken,
                    refundReceiver,
                    // Signature info
                    nonce
                );
            // Increase nonce and execute transaction.
            nonce++;
            txHash = keccak256(txHashData);
            checkSignatures(txHash, txHashData, signatures);
        }
        address guard = getGuard();
        {
            if (guard != address(0)) {
                Guard(guard).checkTransaction(
                    // Transaction info
                    to,
                    value,
                    data,
                    operation,
                    safeTxGas,
                    // Payment info
                    baseGas,
                    gasPrice,
                    gasToken,
                    refundReceiver,
                    // Signature info
                    signatures,
                    msg.sender
                );
            }
        }
        // 我们需要一些 gas 来在执行后发出事件（至少 2500）和一些在执行之前执行代码（500） 
        // 我们还在检查中包含 1/64，它不会与调用一起发送抵消 EIP-150 导致的潜在短路
        require(gasleft() >= ((safeTxGas * 64) / 63).max(safeTxGas + 2500) + 500, "GS010");
        // 这里使用作用域来限制变量的生命周期并防止 `stack too deep` 错误
        {
            uint256 gasUsed = gasleft();
           // 如果 gasPrice 为 0，我们假设几乎所有可用的 gas 都可以使用（它总是比 safeTxGas 多） 
           // 我们只减去 2500（与之前的 3000 相比）以确保传递的数量仍然高于 safeTxGas
           success = execute(to, value, data, operation, gasPrice == 0 ? (gasleft() - 2500) : safeTxGas);
            gasUsed = gasUsed.sub(gasleft());
            // 如果没有设置 safeTxGas 和 gasPrice（例如，两者都是 0），则需要内部 tx 成功 
            // 这使得可以毫无问题地使用 `estimateGas`，因为它会搜索 tx 所在的最小 gas不恢复
            require(success || safeTxGas != 0 || gasPrice != 0, "GS013");
            // 我们将计算的 tx 成本转移到 tx.origin 以避免将其发送到已调用的中间合约
            uint256 payment = 0;
            if (gasPrice > 0) {
                payment = handlePayment(gasUsed, baseGas, gasPrice, gasToken, refundReceiver);
            }
            if (success) emit ExecutionSuccess(txHash, payment);
            else emit ExecutionFailure(txHash, payment);
        }
        {
            if (guard != address(0)) {
                Guard(guard).checkAfterExecution(txHash, success);
            }
        }
    }

    function handlePayment(
        uint256 gasUsed,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver
    ) private returns (uint256 payment) {
        // solhint-disable-next-line avoid-tx-origin
        address payable receiver = refundReceiver == address(0) ? payable(tx.origin) : refundReceiver;
        if (gasToken == address(0)) {
            // 对于 ETH，我们只会将 gas 价格调整为不高于实际使用的 gas 价格
            payment = gasUsed.add(baseGas).mul(gasPrice < tx.gasprice ? gasPrice : tx.gasprice);
            require(receiver.send(payment), "GS011");
        } else {
            payment = gasUsed.add(baseGas).mul(gasPrice);
            require(transferToken(gasToken, receiver, payment), "GS012");
        }
    }

    /**
    * @dev 检查提供的签名是否对提供的数据有效，哈希。否则将恢复。 
    * @param dataHash 数据的哈希（可以是消息哈希或交易哈希） 
    * @param data 应该被签名的数据（这被传递给外部验证者合约） 
    * @param signatures 应该被验证的签名数据。可以是 ECDSA 签名、合约签名 (EIP-1271) 或已批准的哈希。
    */
    function checkSignatures(
        bytes32 dataHash,
        bytes memory data,
        bytes memory signatures
    ) public view {
        // 负载阈值以避免多个存储负载
        uint256 _threshold = threshold;
        // 检查是否设置了阈值
        require(_threshold > 0, "GS001");
        checkNSignatures(dataHash, data, signatures, _threshold);
    }

    /**
    * @dev 检查提供的签名是否对提供的数据有效，哈希。否则将恢复。 
    * @param dataHash 数据的哈希（可以是消息哈希或交易哈希） 
    * @param data 应该被签名的数据（这被传递给外部验证者合约） 
    * @param signatures 应该被验证的签名数据。可以是 ECDSA 签名、合约签名 (EIP-1271) 或已批准的哈希。 
    * @param requiredSignatures 所需有效签名的数量。
    */
    function checkNSignatures(
        bytes32 dataHash,
        bytes memory data,
        bytes memory signatures,
        uint256 requiredSignatures
    ) public view {
        // 检查提供的签名数据是否太短
        require(signatures.length >= requiredSignatures.mul(65), "GS020");
        // 不能有地址为 0 的所有者。
        address lastOwner = address(0);
        address currentOwner;
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 i;
        for (i = 0; i < requiredSignatures; i++) {
            (v, r, s) = signatureSplit(signatures, i);
            if (v == 0) {
                // 如果 v 为 0， 那么它是一个合约签名 
                // 当处理合约签名时， 合约的地址被编码为 r
                currentOwner = address(uint160(uint256(r)));

               // 检查签名数据指针 (s) 是否未指向签名字节的静态部分内。 
               // 此检查并不完全准确，因为发送的签名可能超过阈值。
               // 这里我们只检查指针没有指向正在处理的部分内部。
               require(uint256(s) >= requiredSignatures.mul(65), "GS021");

                // 检查签名数据指针 (s) 是否在界限内（指向数据长度 -> 32 字节）
                require(uint256(s).add(32) <= signatures.length, "GS022");

                // 检查合约签名是否在界限内：数据的开始是 s + 32，结束是开始 + 签名长度
                uint256 contractSignatureLen;
                // solhint-disable-next-line no-inline-assembly
                assembly {
                    contractSignatureLen := mload(add(add(signatures, s), 0x20))
                }
                require(uint256(s).add(32).add(contractSignatureLen) <= signatures.length, "GS023");

                // Check signature
                bytes memory contractSignature;
                // solhint-disable-next-line no-inline-assembly
                assembly {
                    // 合约签名的签名数据附加到级联签名中，偏移量存储在 s
                    contractSignature := add(add(signatures, s), 0x20)
                }
                require(ISignatureValidator(currentOwner).isValidSignature(data, contractSignature) == EIP1271_MAGIC_VALUE, "GS024");
            } else if (v == 1) {
                // 如果 v 为 1，那么它是一个已批准的哈希 
                // 当处理已批准的哈希时，批准者的地址被编码为 r
                currentOwner = address(uint160(uint256(r)));
                // 哈希由消息的发送者自动批准， 或者当它们通过单独的交易被预先批准时
                require(msg.sender == currentOwner || approvedHashes[currentOwner][dataHash] != 0, "GS025");
            } else if (v > 30) {
                // 如果 v > 30， 则默认 va (27,28) 已针对 eth_sign 流进行了调整 
                // 为了支持 eth_sign 和类似内容， 我们调整 v 并在应用 ecrecover 之前使用以太坊消息前缀对 messageHash 进行散列
                currentOwner = ecrecover(keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", dataHash)), v - 4, r, s);
            } else {
                // 默认是带有提供数据哈希的 ecrecover 流 
                // 使用带有 messageHash 的 ecrecover 进行 EOA 签名
                currentOwner = ecrecover(dataHash, v, r, s);
            }
            require(currentOwner > lastOwner && owners[currentOwner] != address(0) && currentOwner != SENTINEL_OWNERS, "GS026");
            lastOwner = currentOwner;
        }
    }

   /// @dev 允许估计一个安全事务。 
   /// 此方法仅用于估计目的，因此调用将始终还原并将结果编码到还原数据中。 
   /// 由于 `estimateGas` 函数包含退款，调用此方法可通过 `execTransaction` 获取从保险箱中扣除的估计费用 
   /// @param to Safe 交易的目标地址。 
   /// @param value 安全交易的以太币值。 
   /// @param data 安全事务的数据负载。 
   /// @param operation 安全事务的操作类型。 
   /// @return 估计没有退款和间接费用（基本交易和有效载荷数据气体成本）。 
   /// @notice 已弃用，取而代之的是 common/StorageAccessible.sol，并将在下一个版本中删除。
   function requiredTxGas(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation
    ) external returns (uint256) {
        uint256 startGas = gasleft();
        // 我们在这里不提供错误消息，因为我们使用它来返回估计值
        require(execute(to, value, data, operation, gasleft()));
        uint256 requiredGas = startGas - gasleft();
        // 将响应转换为字符串并通过错误消息返回
        revert(string(abi.encodePacked(requiredGas)));
    }

    /**
    * @dev 将哈希标记为已批准。这可用于验证签名使用的散列。 
    * @param hashToApprove 应标记为已批准的哈希值，以用于由本合约验证的签名。
    */
    function approveHash(bytes32 hashToApprove) external {
        require(owners[msg.sender] != address(0), "GS030");
        approvedHashes[msg.sender][hashToApprove] = 1;
        emit ApproveHash(hashToApprove, msg.sender);
    }
    
    /// @dev 返回此合约使用的链 ID。
    function getChainId() public view returns (uint256) {
        uint256 id;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            id := chainid()
        }
        return id;
    }

    function domainSeparator() public view returns (bytes32) {
        return keccak256(abi.encode(DOMAIN_SEPARATOR_TYPEHASH, getChainId(), this));
    }

    /// @dev 返回经过哈希处理以由所有者签名的字节。 
    /// @param 到目标地址。 
    /// @param value 以太币值。 
    /// @param data 数据负载。 
    /// @param operation 操作类型。 
    /// @param safeTxGas 应该用于安全交易的气体。 
    /// @param baseGas Gas 成本与交易执行无关（例如，基本交易费用、签名检查、退款支付） 
    /// @param gasPrice 该交易应使用的最大gas价格。 
    /// @param gasToken 用于支付的代币地址（如果是 ETH，则为 0）。 
    /// @param refundReceiver gas 支付接收方地址（如果 tx.origin 则为 0）。 
    /// @param _nonce 事务随机数。 
    /// @return 事务哈希字节。
    function encodeTransactionData(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver,
        uint256 _nonce
    ) public view returns (bytes memory) {
        bytes32 safeTxHash =
            keccak256(
                abi.encode(
                    SAFE_TX_TYPEHASH,
                    to,
                    value,
                    keccak256(data),
                    operation,
                    safeTxGas,
                    baseGas,
                    gasPrice,
                    gasToken,
                    refundReceiver,
                    _nonce
                )
            );
        return abi.encodePacked(bytes1(0x19), bytes1(0x01), domainSeparator(), safeTxHash);
    }
    
    /// @dev 返回要由所有者签名的哈希。 
    /// @param to 目标地址。 
    /// @param value 以太币值。 
    /// @param data 数据负载。 
    /// @param operation 操作类型。 
    /// @param safeTxGas Fas 应该用于安全交易。 
    /// @param baseGas 用于触发安全交易的数据的 Gas 成本。 
    /// @param gasPrice 该交易应该使用的最大gas价格。 
    /// @param gasToken 用于支付的代币地址（如果是 ETH，则为 0）。 
    /// @param refundReceiver gas 支付接收方地址（如果 tx.origin 则为 0）。 
    /// @param _nonce 事务随机数。 
    /// @return 交易哈希。
    function getTransactionHash(
        address to,
        uint256 value,
        bytes calldata data,
        Enum.Operation operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address refundReceiver,
        uint256 _nonce
    ) public view returns (bytes32) {
        return keccak256(encodeTransactionData(to, value, data, operation, safeTxGas, baseGas, gasPrice, gasToken, refundReceiver, _nonce));
    }
}
