pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;
import "./interface/MarketInterfaces.sol";

contract ShardsMarketDelegator is IShardsMarketStorge {
    /**
     * @notice Emitted when pendingComptrollerImplementation is accepted, which means comptroller implementation is updated
     */
    event NewImplementation(
        address oldImplementation,
        address newImplementation
    );

    event NewAdmin(address oldAdmin, address newAdmin);
    event NewGovernance(address oldGovernance, address newGovernance);

    constructor(
        address _WETH,
        address _factory,
        address _governance,
        address _router,
        address _dev,
        address _platformFund,
        address _shardsFactory,
        address _regulator,
        address _buyoutProposals,
        address implementation_
    ) public {
        admin = msg.sender;
        governance = msg.sender;
        _setImplementation(implementation_);
        delegateTo(
            implementation_,
            abi.encodeWithSignature(
                "initialize(address,address,address,address,address,address,address,address,address)",
                _WETH,
                _factory,
                _governance,
                _router,
                _dev,
                _platformFund,
                _shardsFactory,
                _regulator,
                _buyoutProposals
            )
        );
    }

    function _setImplementation(address implementation_) public {
        require(
            msg.sender == governance,
            "_setImplementation: Caller must be governance"
        );

        address oldImplementation = implementation;
        implementation = implementation_;

        emit NewImplementation(oldImplementation, implementation);
    }

    function _setAdmin(address newAdmin) public {
        require(msg.sender == admin, "UNAUTHORIZED");

        address oldAdmin = admin;

        admin = newAdmin;

        emit NewAdmin(oldAdmin, newAdmin);
    }

    function _setGovernance(address newGovernance) public {
        require(msg.sender == governance, "UNAUTHORIZED");

        address oldGovernance = governance;

        governance = newGovernance;

        emit NewGovernance(oldGovernance, newGovernance);
    }

    function delegateTo(address callee, bytes memory data)
        internal
        returns (bytes memory)
    {
        (bool success, bytes memory returnData) = callee.delegatecall(data);
        assembly {
            if eq(success, 0) {
                revert(add(returnData, 0x20), returndatasize())
            }
        }
        return returnData;
    }

    receive() external payable {}

    /**
     * @notice Delegates execution to an implementation contract
     * @dev It returns to the external caller whatever the implementation returns or forwards reverts
    //  */
    fallback() external payable {
        // delegate all other functions to current implementation
        (bool success, ) = implementation.delegatecall(msg.data);
        assembly {
            let free_mem_ptr := mload(0x40)
            returndatacopy(free_mem_ptr, 0, returndatasize())
            switch success
                case 0 {
                    revert(free_mem_ptr, returndatasize())
                }
                default {
                    return(free_mem_ptr, returndatasize())
                }
        }
    }
}
