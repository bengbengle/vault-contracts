// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;
import "../common/SelfAuthorized.sol";

/// @title OwnerManager - 管理一组所有者和执行操作的阈值。
/// @author Stefan George - <stefan@gnosis.pm>
contract OwnerManager is SelfAuthorized {
    event AddedOwner(address owner);
    event RemovedOwner(address owner);
    event ChangedThreshold(uint256 threshold);

    address internal constant SENTINEL_OWNERS = address(0x1);

    mapping(address => address) internal owners;
    uint256 internal ownerCount;
    uint256 internal threshold;

    /// @dev Setup function sets initial storage of contract.
    /// @param _owners List of Safe owners.
    /// @param _threshold Number of required confirmations for a Safe transaction.
    function setupOwners(address[] memory _owners, uint256 _threshold) internal {
        // Threshold can only be 0 at initialization.
        // Check ensures that setup function can only be called once.
        require(threshold == 0, "GS200");
        // Validate that threshold is smaller than number of added owners.
        require(_threshold <= _owners.length, "GS201");
        // There has to be at least one Safe owner.
        require(_threshold >= 1, "GS202");
        // Initializing Safe owners.
        address currentOwner = SENTINEL_OWNERS;
        for (uint256 i = 0; i < _owners.length; i++) {
            // Owner address cannot be null.
            address owner = _owners[i];
            require(owner != address(0) && owner != SENTINEL_OWNERS && owner != address(this) && currentOwner != owner, "GS203");
            // No duplicate owners allowed.
            require(owners[owner] == address(0), "GS204");
            owners[currentOwner] = owner;
            currentOwner = owner;
        }
        owners[currentOwner] = SENTINEL_OWNERS;
        ownerCount = _owners.length;
        threshold = _threshold;
    }
    
    /// @dev 允许将新所有者添加到保险箱并同时更新阈值。 这只能通过安全事务来完成。
    /// @notice 将所有者 `owner` 添加到 Safe 并将阈值更新为 `_threshold`。
    /// @param owner 新的所有者地址。
    /// @param _threshold 新阈值
    function addOwnerWithThreshold(address owner, uint256 _threshold) public authorized {
        // 所有者地址不能为空，哨兵或保险箱本身。
        require(owner != address(0) && owner != SENTINEL_OWNERS && owner != address(this), "GS203");
        // 不允许重复所有者。
        require(owners[owner] == address(0), "GS204");
        owners[owner] = owners[SENTINEL_OWNERS];
        owners[SENTINEL_OWNERS] = owner;
        ownerCount++;
        emit AddedOwner(owner);
        // 如果阈值改变，则改变阈值。
        if (threshold != _threshold) changeThreshold(_threshold);
    }

    
    /// @dev 允许从保险箱中删除所有者并同时更新阈值。 这只能通过安全事务来完成。 
    /// @notice 从 Safe 中删除所有者 `owner` 并将阈值更新为 `_threshold`。 
    /// @param prevOwner Owner 指向链表中要移除的所有者 
    /// @param owner 要移除的所有者地址。 
    /// @param _threshold 新阈值。
    function removeOwner(
        address prevOwner,
        address owner,
        uint256 _threshold
    ) public authorized {
        // 如果仍然可以达到阈值，则只允许删除所有者。
        require(ownerCount - 1 >= _threshold, "GS201");
        // 验证所有者地址并检查它是否与所有者索引相对应。
        require(owner != address(0) && owner != SENTINEL_OWNERS, "GS203");
        require(owners[prevOwner] == owner, "GS205");
        owners[prevOwner] = owners[owner];
        owners[owner] = address(0);
        ownerCount--;
        emit RemovedOwner(owner);
        // 如果阈值已更改，则更改阈值。
        if (threshold != _threshold) changeThreshold(_threshold);
    }

    /// @dev 允许用另一个地址交换/替换保险箱中的所有者。 这只能通过安全事务来完成。 
    /// @notice 将保险箱中的所有者 `oldOwner` 替换为 `newOwner`。 
    /// @param prevOwner Owner 指向链表中要替换的所有者 
    /// @param oldOwner 要替换的所有者地址。 
    /// @param newOwner 新所有者地址。
    function swapOwner(
        address prevOwner,
        address oldOwner,
        address newOwner
    ) public authorized {
        // 所有者地址不能为空，哨兵或保险箱本身。
        require(newOwner != address(0) && newOwner != SENTINEL_OWNERS && newOwner != address(this), "GS203");
        // 不允许重复所有者。
        require(owners[newOwner] == address(0), "GS204");
        // 验证 oldOwner 地址并检查它是否对应于所有者索引。
        require(oldOwner != address(0) && oldOwner != SENTINEL_OWNERS, "GS203");
        require(owners[prevOwner] == oldOwner, "GS205");
        owners[newOwner] = owners[oldOwner];
        owners[prevOwner] = newOwner;
        owners[oldOwner] = address(0);
        emit RemovedOwner(oldOwner);
        emit AddedOwner(newOwner);
    }

    /// @dev 允许更新安全所有者所需的确认次数。 这只能通过安全事务来完成。 
    /// @notice 将 Safe 的阈值更改为 `_threshold`。 
    /// @param _threshold 新阈值。
    function changeThreshold(uint256 _threshold) public authorized {
        // 验证阈值小于所有者数。
        require(_threshold <= ownerCount, "GS201");
        // 必须至少有一个保险箱所有者。
        require(_threshold >= 1, "GS202");
        threshold = _threshold;
        emit ChangedThreshold(threshold);
    }

    function getThreshold() public view returns (uint256) {
        return threshold;
    }

    function isOwner(address owner) public view returns (bool) {
        return owner != SENTINEL_OWNERS && owners[owner] != address(0);
    }

    /// @dev 返回所有者数组。 
    /// @return 安全所有者数组。
    function getOwners() public view returns (address[] memory) {
        address[] memory array = new address[](ownerCount);

        uint256 index = 0;
        address currentOwner = owners[SENTINEL_OWNERS];
        while (currentOwner != SENTINEL_OWNERS) {
            array[index] = currentOwner;
            currentOwner = owners[currentOwner];
            index++;
        }
        return array;
    }
}
