// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";

error Raffle__NotEnoughETHEntered();
error Raffle__TransferFailed();
error Raffle__NotOpen();
error Raffle__UpkeepNotNeeded(uint256 currentBalance, uint256 playersLength, uint256 raffleState);

/**
 * @title A sample Raffle Contract
 * @author Tryfon Kaltapanidis
 * @notice This contract is for creating an untamperable decentralized smart contract raffle
 * @dev This contract uses Chainlink VRF to get a random number and pick a winner and Chainlink Keeper to automate the process
 */
contract Raffle is VRFConsumerBaseV2, KeeperCompatibleInterface {
    /* Type declarations */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /* State Variables */
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable i_callbackGasLimit;
    uint32 private constant NUM_WORDS = 1;
    uint256 private s_lastTimeStamp;
    uint256 private immutable i_interval;

    /* Lottery Variables */
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /* Events */
    event RaffleEnter(address indexed player);
    event RequestedRaffleWinner(uint256 indexed requestId);
    event WinnerPicked(address indexed winner);

    /* Functions */
    // vrfCoordinator is the address of the contract that does the random number verification
    constructor(
        address vrfCoordinatorV2, // contract
        uint256 entranceFee,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        uint256 interval
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_entranceFee = entranceFee;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        i_interval = interval;
    }

    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughETHEntered();
        }
        if (s_raffleState == RaffleState.CALCULATING) {
            revert Raffle__NotOpen();
        }
        s_players.push(payable(msg.sender)); // msg.sender is not a payable address itself, so we need to cast it to a payable address
        // Emit an event when we update a dynamic array or a mapping
        // Named events with the function name reversed
        emit RaffleEnter(msg.sender);
    }

    /**
     * @dev This is the function that the Chainlink Keeper nodes call
     * they look for the `upkeepNeeded` to return true, and then call performUpkeep
     * The following should be true in order to return true:
     * 1. The time interval should have passed
     * 2. Lottery should have at least 1 player and have some ETH
     * 3. Our subscription should have enough LINK
     * 4. Lottery should be in an "open" state
     */

    function checkUpkeep(
        bytes memory /* checkData */
    ) public override returns (bool upkeedNeeded, bytes memory /* performData*/) {
        bool isOpen = RaffleState.OPEN == s_raffleState;
        // current timestamp == block.timestamp
        // to get if enough time has passed we need block.timestamp - lastTimeStamp > interval
        bool timePassed = (block.timestamp - s_lastTimeStamp) > i_interval;
        bool hasEnoughPlayers = s_players.length > 0;
        bool hasEnoughETH = address(this).balance > 0;
        upkeedNeeded = isOpen && timePassed && hasEnoughPlayers && hasEnoughETH;
    }

    function performUpkeep(bytes calldata /* performData*/) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        // Request the random number from the Chainlink VRF
        s_raffleState = RaffleState.CALCULATING;
        // requestRandomWords is a function that returns a requestId
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, // keyHash
            i_subscriptionId, // subId
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit, // gasLimit is the maximum amount of gas that can be used to execute the callback which is in this case fullfillRandomWords
            NUM_WORDS // how many random words we want
        );
        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] memory randomWords
    ) internal override {
        // Fullfill the random words from the Chainlink VRF
        uint256 winnerIndex = randomWords[0] % s_players.length; // this secures that the winnerIndex is within the range of the players array
        address payable recentWinner = s_players[winnerIndex];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0); // reset the players array
        s_lastTimeStamp = block.timestamp; // reset the lastTimeStamp
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
        emit WinnerPicked(recentWinner);
    }

    /* View, Pure functions */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    // Since NUM_WORDS is a constant, we can use a pure function to return it and not view. With view we read from storage as it is in the bytecode.
    function getNumWords() public pure returns (uint32) {
        return NUM_WORDS;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }

    function getLatestTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRequestConfirmations() public pure returns (uint16) {
        return REQUEST_CONFIRMATIONS;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }
}
