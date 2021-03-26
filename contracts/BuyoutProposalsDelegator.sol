pragma solidity 0.6.12;

import "./interface/IBuyoutProposals.sol";

contract BuyoutProposalsDelegator is IBuyoutProposals {
    /**
     * @notice Emitted when pendingComptrollerImplementation is accepted, which means comptroller implementation is updated
     */
    event NewImplementation(
        address oldImplementation,
        address newImplementation
    );

    event NewGovernance(address oldGovernance, address newGovernance);

    constructor(
        address _governance,
        address _regulator,
        address implementation_
    ) public {
        governance = msg.sender;
        _setImplementation(implementation_);
        delegateTo(
            implementation_,
            abi.encodeWithSignature(
                "initialize(address,address)",
                _governance,
                _regulator
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

    function _setGovernance(address newGovernance) public {
        require(msg.sender == governance, "UNAUTHORIZED");

        address oldGovernance = governance;

        governance = newGovernance;

        emit NewGovernance(oldGovernance, newGovernance);
    }

    function createProposal(
        uint256 _shardPoolId,
        uint256 shardBalance,
        uint256 wantTokenAmount,
        uint256 currentPrice,
        uint256 totalShardSupply,
        address submitter
    ) external override returns (uint256 proposalId, uint256 buyoutTimes) {
        bytes memory data =
            delegateToImplementation(
                abi.encodeWithSignature(
                    "createProposal(uint256,uint256,uint256,uint256,uint256,address)",
                    _shardPoolId,
                    shardBalance,
                    wantTokenAmount,
                    currentPrice,
                    totalShardSupply,
                    submitter
                )
            );
        return abi.decode(data, (uint256, uint256));
    }

    function vote(
        uint256 _shardPoolId,
        bool isAgree,
        address shard,
        address voter
    ) external override returns (uint256 proposalId, uint256 balance) {
        bytes memory data =
            delegateToImplementation(
                abi.encodeWithSignature(
                    "vote(uint256,bool,address,address)",
                    _shardPoolId,
                    isAgree,
                    shard,
                    voter
                )
            );
        return abi.decode(data, (uint256, uint256));
    }

    function voteResultConfirm(uint256 _shardPoolId)
        external
        override
        returns (
            uint256 proposalId,
            bool result,
            address submitter,
            uint256 shardAmount,
            uint256 wantTokenAmount
        )
    {
        bytes memory data =
            delegateToImplementation(
                abi.encodeWithSignature(
                    "voteResultConfirm(uint256)",
                    _shardPoolId
                )
            );
        return abi.decode(data, (uint256, bool, address, uint256, uint256));
    }

    function exchangeForWantToken(uint256 _shardPoolId, uint256 shardAmount)
        external
        view
        override
        returns (uint256 wantTokenAmount)
    {
        bytes memory data =
            delegateToViewImplementation(
                abi.encodeWithSignature(
                    "exchangeForWantToken(uint256,uint256)",
                    _shardPoolId,
                    shardAmount
                )
            );
        return abi.decode(data, (uint256));
    }

    function redeemForBuyoutFailed(uint256 _proposalId, address submitter)
        external
        override
        returns (
            uint256 _shardPoolId,
            uint256 shardTokenAmount,
            uint256 wantTokenAmount
        )
    {
        bytes memory data =
            delegateToImplementation(
                abi.encodeWithSignature(
                    "redeemForBuyoutFailed(uint256,address)",
                    _proposalId,
                    submitter
                )
            );
        return abi.decode(data, (uint256, uint256, uint256));
    }

    function setBuyoutTimes(uint256 _buyoutTimes) external override {
        delegateToImplementation(
            abi.encodeWithSignature("setBuyoutTimes(uint256)", _buyoutTimes)
        );
    }

    function setVoteLenth(uint256 _voteLenth) external override {
        delegateToImplementation(
            abi.encodeWithSignature("setVoteLenth(uint256)", _voteLenth)
        );
    }

    function setPassNeeded(uint256 _passNeeded) external override {
        delegateToImplementation(
            abi.encodeWithSignature("setPassNeeded(uint256)", _passNeeded)
        );
    }

    function setBuyoutProportion(uint256 _buyoutProportion) external override {
        delegateToImplementation(
            abi.encodeWithSignature(
                "setBuyoutProportion(uint256)",
                _buyoutProportion
            )
        );
    }

    function setMarket(address _market) external override {
        delegateToImplementation(
            abi.encodeWithSignature("setMarket(address)", _market)
        );
    }

    function setRegulator(address _regulator) external override {
        delegateToImplementation(
            abi.encodeWithSignature("setRegulator(address)", _regulator)
        );
    }

    function getProposalsForExactPool(uint256 _shardPoolId)
        external
        view
        override
        returns (uint256[] memory _proposalsHistory)
    {
        bytes memory data =
            delegateToViewImplementation(
                abi.encodeWithSignature(
                    "getProposalsForExactPool(uint256)",
                    _shardPoolId
                )
            );
        return abi.decode(data, (uint256[]));
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

    /**
     * @notice Delegates execution to the implementation contract
     * @dev It returns to the external caller whatever the implementation returns or forwards reverts
     * @param data The raw data to delegatecall
     * @return The returned bytes from the delegatecall
     */
    function delegateToImplementation(bytes memory data)
        public
        returns (bytes memory)
    {
        return delegateTo(implementation, data);
    }

    /**
     * @notice Delegates execution to an implementation contract
     * @dev It returns to the external caller whatever the implementation returns or forwards reverts
     *  There are an additional 2 prefix uints from the wrapper returndata, which we ignore since we make an extra hop.
     * @param data The raw data to delegatecall
     * @return The returned bytes from the delegatecall
     */
    function delegateToViewImplementation(bytes memory data)
        public
        view
        returns (bytes memory)
    {
        (bool success, bytes memory returnData) =
            address(this).staticcall(
                abi.encodeWithSignature("delegateToImplementation(bytes)", data)
            );
        assembly {
            if eq(success, 0) {
                revert(add(returnData, 0x20), returndatasize())
            }
        }
        return abi.decode(returnData, (bytes));
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
