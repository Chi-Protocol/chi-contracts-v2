// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IArbitrageV5 {
    struct SwapParams {
        address reserveAsset;
        uint256 amountIn;
        uint256 minAmountOut;
    }

    error DeltaBiggerThanAmountReceivedETH(uint256 deltaETH, uint256 receivedETH);
    error ToleranceTooBig(uint16 _tolerance);
    error PriceSlippageTooBig();
    error NotArbitrager(address account);
    error PriceIsNotPegged();
    error ReserveDiffTooBig();
    error ChiPriceNotPegged(uint256 spotPrice, uint256 twapPrice);
    error FeeTooBig(uint256 fee);
    error ChiSpotPriceTooBig();
    error ContractIsPaused();
    error ReserveTxLimitExceeded();

    event SetPriceTolerance(uint16 priceTolerance);
    event Mint(address indexed account, address token, uint256 amount, uint256 uscAmount);
    event ExecuteArbitrage(
        address indexed account,
        uint256 indexed arbNum,
        uint256 deltaUsd,
        uint256 reserveDiff,
        uint256 ethPrice,
        uint256 rewardValue
    );
    event UpdateArbitrager(address indexed account, bool status);
    event SetMaxMintBurnPriceDiff(uint256 maxMintBurnPriceDiff);
    event SetChiPriceTolerance(uint16 chiPriceTolerance);
    event SetMaxMintBurnReserveTolerance(uint16 maxBurnReserveTolerance);
    event SetMintBurnFee(uint256 mintFee);
    event UpdatePrivileged(address indexed privileged, bool isPrivileged);
    event Burn(address account, uint256 amount, uint256 reserveReceived, address reserve);
    event RewardUSC(uint256 amount);
    event SetReserveMintTxLimit(address reserveAsset, uint256 limit);
    event SetReserveBurnTxLimit(address reserveAsset, uint256 limit);

    /// @notice Sets absolute peg price tolerance
    /// @param _priceTolerance Absolute value of price tolerance
    /// @custom:usage This function should be called from owner in purpose of setting price tolerance
    function setPegPriceToleranceAbs(uint256 _priceTolerance) external;

    /// @notice Sets spot price tolerance from TWAP price
    /// @dev 100% = 10000
    /// @param _priceTolerance Price tolerance in percents
    /// @custom:usage This function should be called from owner in purpose of setting price tolerance
    function setPriceTolerance(uint16 _priceTolerance) external;

    /// @notice Sets reserve tx limit for minting
    /// @param reserveAsset Address of reserve asset
    /// @param limit Limit of reserve tx
    function setReserveMintTxLimit(address reserveAsset, uint256 limit) external;

    /// @notice Sets reserve tx limit for burn
    /// @param reserveAsset Address of reserve asset
    /// @param limit Limit of reserve tx
    function setReserveBurnTxLimit(address reserveAsset, uint256 limit) external;

    /// @notice Mint USC tokens for ETH
    /// @dev If USC price is different from target price for less then max mint price diff, then minting is allowed without performing arbitrage
    /// @param receiver Receiver of USC tokens
    /// @return uscAmount Amount of USC tokens minted
    function mint(address receiver) external payable returns (uint256 uscAmount);

    /// @notice Mint USC tokens for WETH
    /// @param token Address of a token that will be used to mint USC
    /// @param amount Amount of token to use for minting
    /// @param receiver Receiver of USC tokens
    /// @return uscAmount Amount of USC tokens minted
    function mint(address token, uint256 amount, address receiver) external returns (uint256 uscAmount);

    /// @notice Executes arbitrage with reserve rebalance
    /// @param chiSpotPrice CHI spot price
    /// @param swapParams Array of swap params for reserve holder in order to perform safe reserve sell and get ETH
    /// @return amountOut Amount out
    /// @dev This function should execute arbitrage with reserve rebalance when there is not enough ETH in reserve holder so some reserves need to be sold
    function executeArbitrageWithReserveSell(uint256 chiSpotPrice, SwapParams[] memory swapParams)
        external
        returns (uint256);

    /// @notice Executes arbitrage, profit sent to caller
    /// @notice Returns reward value in USD
    /// @param maxChiSpotPrice maximum spot price of CHI, if 0 TWAP check will be done
    /// @return rewardValue Reward value in USD
    /// @custom:usage This function should be called from external keeper in purpose of pegging USC price and getting reward
    /// @custom:usage This function has no restrictions, anyone can be arbitrager
    function executeArbitrage(uint256 maxChiSpotPrice) external returns (uint256 rewardValue);

    /// @notice Gets information for perfoming arbitrage such as price diff, reserve diff, discount
    /// @return isPriceAtPeg True if USC price is above target price
    /// @return isPriceAboveTarget True if USC price is above target price
    /// @return isExcessOfReserves True if there is excess of reserves
    /// @return reserveDiff Reserve diff, excess or deficit of reserves
    function getArbitrageData()
        external
        view
        returns (bool isPriceAtPeg, bool isPriceAboveTarget, bool isExcessOfReserves, uint256 reserveDiff);

    /// @notice Update arbitrager status
    /// @dev This function can be called only by owner of contract
    /// @param account Arbitrager account
    /// @param status Arbitrager status
    function updateArbitrager(address account, bool status) external;

    /// @notice Claim rewards from arbitrages
    /// @dev This function can be called only by owner of contract
    /// @param tokens Tokens to claim rewards for
    /// @param amounts Amounts of tokens to claim rewards for
    function claimRewards(IERC20[] memory tokens, uint256[] memory amounts) external;

    /// @notice Rewards USC
    /// @dev This function can be called only by owner of contract
    /// @param amount Amount of USC to reward
    function rewardUSC(uint256 amount) external;

    /// @notice Sets maximum mint and burn price difference
    /// @dev This function can be called only by owner of contract, value is absolute
    /// @param _maxMintBurnPriceDiff Maximum mint and burn price difference
    function setMaxMintBurnPriceDiff(uint256 _maxMintBurnPriceDiff) external;

    /// @notice Sets CHI price tolerance percentage when checking TWAP
    /// @dev This function can be called only by owner of contract, value is relative
    /// @param _chiPriceTolerance CHI price tolerance percentage
    function setChiPriceTolerance(uint16 _chiPriceTolerance) external;

    /// @notice Sets maximum mint and burn price difference
    /// @dev This function can be called only by owner of contract, value is relative
    /// @param _maxMintBurnReserveTolerance Maximum mint and burn reserve tolerance
    function setMaxMintBurnReserveTolerance(uint16 _maxMintBurnReserveTolerance) external;

    /// @notice Sets mint and burn fee
    /// @dev This function can be called only by owner of contract
    /// @param _mintBurnFee Mint and burn fee
    function setMintBurnFee(uint16 _mintBurnFee) external;

    /// @notice Update privilege status, only privileged accounts can call arbitrage and pass CHI TWAP check
    /// @dev This function can be called only by owner of contract
    /// @param account Arbitrager account
    /// @param status Privilege status
    function updatePrivileged(address account, bool status) external;

    /// @notice Burns USC tokens from msg.sender and sends him WETH from reserves
    /// @param amount Amount of USC tokens to burn
    /// @param reserveToReceive Address of reserve to receive
    /// @return ethAmount Amount of WETH received
    function burn(uint256 amount, address reserveToReceive) external returns (uint256 ethAmount);

    /// @notice Sets mint pause
    /// @param isPaused true of false
    function setMintPause(bool isPaused) external;

    /// @notice Sets burn pause
    /// @param isPaused true of false
    function setBurnPause(bool isPaused) external;
}
