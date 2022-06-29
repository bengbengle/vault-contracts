// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;
import "../common/Enum.sol";
import "../common/SelfAuthorized.sol";
import "./Executor.sol";

/// @title Module Manager - 管理可以通过此合约执行交易的模块的合约 
contract ModuleManager is SelfAuthorized, Executor {
    event EnabledModule(address module);
    event DisabledModule(address module);
    event ExecutionFromModuleSuccess(address indexed module);
    event ExecutionFromModuleFailure(address indexed module);

    address internal constant SENTINEL_MODULES = address(0x1);

    mapping(address => address) internal modules;

    function setupModules(address to, bytes memory data) internal {
        require(modules[SENTINEL_MODULES] == address(0), "GS100");
        modules[SENTINEL_MODULES] = SENTINEL_MODULES;
        if (to != address(0))
            // 设置必须成功完成或交易失败
            require(execute(to, 0, data, Enum.Operation.DelegateCall, gasleft()), "GS000");
    }

    /// @dev 允许将模块添加到白名单。 
    ///  这只能通过安全事务来完成。 
    /// @notice 为保险箱启用模块 `module`。 
    /// @param module 要列入白名单的模块。
    function enableModule(address module) public authorized {
        // 模块地址不能为空或哨兵。
        require(module != address(0) && module != SENTINEL_MODULES, "GS101");
        // 模块不能添加两次。
        require(modules[module] == address(0), "GS102");
        modules[module] = modules[SENTINEL_MODULES];
        modules[SENTINEL_MODULES] = module;
        emit EnabledModule(module);
    }
    
    /// @dev 允许从白名单中删除模块。 这只能通过安全事务来完成。 
    /// @notice 为保险箱禁用模块 `module`。 
    /// @param prevModule 指向链表中要移除的模块的模块 
    /// @param module 要移除的模块。
    function disableModule(address prevModule, address module) public authorized {
        // 验证模块地址并检查它是否对应于模块索引
        require(module != address(0) && module != SENTINEL_MODULES, "GS101");
        require(modules[prevModule] == module, "GS103");
        modules[prevModule] = modules[module];
        modules[module] = address(0);
        emit DisabledModule(module);
    }
    
    /// @dev 允许模块在没有任何进一步确认的情况下执行安全事务。 
    /// @param to 模块事务的目标地址。 
    /// @param value 模块交易的以太币值。 
    /// @param data 模块事务的数据负载。 
    /// @param operation 模块事务的操作类型。
    function execTransactionFromModule(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation
    ) public virtual returns (bool success) {
        // 只允许列入白名单的模块
        require(msg.sender != SENTINEL_MODULES && modules[msg.sender] != address(0), "GS104");
        // 无需进一步确认即可执行交易。
        success = execute(to, value, data, operation, gasleft());
        if (success) emit ExecutionFromModuleSuccess(msg.sender);
        else emit ExecutionFromModuleFailure(msg.sender);
    }

    /// @dev 允许模块在没有任何进一步确认的情况下执行安全事务并返回数据 
    /// @param to 模块事务的目标地址。 
    /// @param value 模块交易的以太币值。 
    /// @param data 模块事务的数据负载。 
    /// @param operation 模块事务的操作类型。
    function execTransactionFromModuleReturnData(
        address to,
        uint256 value,
        bytes memory data,
        Enum.Operation operation
    ) public returns (bool success, bytes memory returnData) {
        success = execTransactionFromModule(to, value, data, operation);
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // 加载空闲内存位置
            let ptr := mload(0x40)
            // 我们通过将空闲内存位置设置为 
            // 当前空闲内存位置 + 数据大小 + 32 字节作为数据大小值来为返回数据分配内存
            mstore(0x40, add(ptr, add(returndatasize(), 0x20)))
            // Store the size
            mstore(ptr, returndatasize())
            // Store the data
            returndatacopy(add(ptr, 0x20), 0, returndatasize())
            // 将返回数据指向正确的内存位置
            returnData := ptr
        }
    }
    
    /// @dev 如果启用了模块，则返回 
    /// @return 如果启用了模块，则返回 True
    function isModuleEnabled(address module) public view returns (bool) {
        return SENTINEL_MODULES != module && modules[module] != address(0);
    }

    /// @dev 返回模块数组。 
    /// @param start 页面的开始。 
    /// @param pageSize 应该返回的最大模块数。 
    /// @return array 模块数组。 
    /// @return next 下一页的开始。
    function getModulesPaginated(address start, uint256 pageSize) external view returns (address[] memory array, address next) {
        // 具有最大页面大小的初始化数组
        array = new address[](pageSize);

        // 填充返回数组
        uint256 moduleCount = 0;
        address currentModule = modules[start];
        while (currentModule != address(0x0) && currentModule != SENTINEL_MODULES && moduleCount < pageSize) {
            array[moduleCount] = currentModule;
            currentModule = modules[currentModule];
            moduleCount++;
        }
        next = currentModule;
        // 设置返回数组的正确大小 
        // solhint-disable-next-line no-inline-assembly
        assembly {
            mstore(array, moduleCount)
        }
    }
}
