// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity >=0.7.0 <0.9.0;

/**
 * @title GnosisSafeMath
 * @dev 具有安全检查的数学运算，在错误时恢复 
 * 从 SafeMath 重命名为 GnosisSafeMath 以避免冲突 
 * TODO：一旦打开 zeppelin 更新到 solc 0.5.0 就删除
 */
library GnosisSafeMath {
    /**
     * @dev Multiplies two numbers, reverts on overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas 优化：这比要求 'a' 不为零要便宜，但是如果还测试了 'b'，则好处会丢失。
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    /**
     * @dev 减去两个数字，在溢出时恢复（即如果 subtrahend 大于 minuend）。
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev 添加两个数字，溢出时恢复。
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);

        return c;
    }

    /**
     * @dev 返回两个数字中最大的一个。 
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }
}
