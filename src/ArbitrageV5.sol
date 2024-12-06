// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "src/interfaces/IWETH.sol";
import "src/interfaces/IPriceFeedAggregator.sol";
import "src/interfaces/IReserveHolderV2.sol";
import "src/interfaces/IArbitrageERC20.sol";
import "src/library/ExternalContractAddresses.sol";
import "src/library/uniswap/UniswapV2Library.sol";
import "src/interfaces/IArbitrageV5.sol";

/// @title Contract for performing arbitrage
/// @notice This contract is responsible for buying USC tokens and for keeping price of USC token pegged to target price
/// @dev This contract represent second version of arbitrage contract, arbitrage is now private and all profit from arbitrage is kept in this contract
contract ArbitrageV5 is IArbitrageV5, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    using SafeERC20 for IArbitrageERC20;

    uint256 public constant BASE_PRICE = 1e8;
    uint256 public constant USC_TARGET_PRICE = 1e8;
    uint256 public constant POOL_FEE = 30;
    uint256 public constant MAX_FEE = 100_00;

    // F = (1 - pool_fee) on 18 decimals
    uint256 public constant F = ((MAX_FEE - POOL_FEE) * 1e18) / MAX_FEE;
    uint16 public constant MAX_PRICE_TOLERANCE = 100_00;
    address public constant WETH = ExternalContractAddresses.WETH;
    address public constant STETH = ExternalContractAddresses.stETH;
    IUniswapV2Router02 public constant swapRouter = IUniswapV2Router02(ExternalContractAddresses.UNI_V2_SWAP_ROUTER);
    IUniswapV2Factory public constant poolFactory = IUniswapV2Factory(ExternalContractAddresses.UNI_V2_POOL_FACTORY);

    IArbitrageERC20 public immutable USC;
    IArbitrageERC20 public immutable CHI;
    IPriceFeedAggregator public immutable priceFeedAggregator;
    IReserveHolderV2 public immutable reserveHolder;

    uint256 public pegPriceToleranceAbs;
    uint256 public mintBurnFee;
    uint256 public maxMintBurnPriceDiff;
    uint16 public maxMintBurnReserveTolerance;
    uint16 public chiPriceTolerance;
    uint16 public priceTolerance;

    bool public mintPaused;
    bool public burnPaused;

    uint256 public totalMintedUsc; // total amount of minted USC tokens during arbitrage when stablecoin is pegged

    mapping(address => bool) public isArbitrager;
    mapping(address => bool) public isPrivileged;
    mapping(address => uint256) public reserveMintTxLimit;
    mapping(address => uint256) public reserveBurnTxLimit;

    modifier onlyArbitrager() {
        if (!isArbitrager[msg.sender]) {
            revert NotArbitrager(msg.sender);
        }

        _;
    }

    modifier whenMintNotPaused() {
        if (mintPaused) {
            revert ContractIsPaused();
        }

        _;
    }

    modifier whenBurnNotPaused() {
        if (burnPaused) {
            revert ContractIsPaused();
        }

        _;
    }

    modifier onlyWhenMintableOrBurnable() {
        uint256 ethPrice = priceFeedAggregator.peek(WETH);

        uint256 uscSpotPrice = _calculateUscSpotPrice(ethPrice);
        if (!_almostEqualAbs(uscSpotPrice, USC_TARGET_PRICE, maxMintBurnPriceDiff)) {
            revert PriceIsNotPegged();
        }

        (, uint256 reserveDiff, uint256 reserveValue) = _getReservesData();
        if (reserveDiff > Math.mulDiv(reserveValue, maxMintBurnReserveTolerance, MAX_PRICE_TOLERANCE)) {
            revert ReserveDiffTooBig();
        }

        _;
    }

    modifier onlyBellowMintLimit(address reserveAsset, uint256 amount) {
        if (reserveMintTxLimit[reserveAsset] < amount) {
            revert ReserveTxLimitExceeded();
        }

        _;
    }

    modifier onlyBellowBurnLimit(address reserveAsset, uint256 amount) {
        if (reserveBurnTxLimit[reserveAsset] < amount) {
            revert ReserveTxLimitExceeded();
        }

        _;
    }

    constructor(
        IArbitrageERC20 _USC,
        IArbitrageERC20 _CHI,
        IPriceFeedAggregator _priceFeedAggregator,
        IReserveHolderV2 _reserveHolder
    ) Ownable() {
        USC = _USC;
        CHI = _CHI;
        priceFeedAggregator = _priceFeedAggregator;
        reserveHolder = _reserveHolder;
        mintPaused = false;
        burnPaused = false;

        IERC20(STETH).approve(address(reserveHolder), type(uint256).max);
    }

    /// @inheritdoc IArbitrageV5
    function setPegPriceToleranceAbs(uint256 _priceTolerance) external override onlyOwner {
        pegPriceToleranceAbs = _priceTolerance;
    }

    /// @inheritdoc IArbitrageV5
    function setMintPause(bool isPaused) external onlyOwner {
        mintPaused = isPaused;
    }

    /// @inheritdoc IArbitrageV5
    function setBurnPause(bool isPaused) external onlyOwner {
        burnPaused = isPaused;
    }

    /// @inheritdoc IArbitrageV5
    function setPriceTolerance(uint16 _priceTolerance) external onlyOwner {
        if (_priceTolerance > MAX_PRICE_TOLERANCE) {
            revert ToleranceTooBig(_priceTolerance);
        }
        priceTolerance = _priceTolerance;
        emit SetPriceTolerance(_priceTolerance);
    }

    /// @inheritdoc IArbitrageV5
    function setChiPriceTolerance(uint16 _chiPriceTolerance) external onlyOwner {
        if (_chiPriceTolerance > MAX_PRICE_TOLERANCE) {
            revert ToleranceTooBig(_chiPriceTolerance);
        }
        chiPriceTolerance = _chiPriceTolerance;
        emit SetChiPriceTolerance(_chiPriceTolerance);
    }

    /// @inheritdoc IArbitrageV5
    function setMaxMintBurnPriceDiff(uint256 _maxMintBurnPriceDiff) external onlyOwner {
        maxMintBurnPriceDiff = _maxMintBurnPriceDiff;
        emit SetMaxMintBurnPriceDiff(_maxMintBurnPriceDiff);
    }

    /// @inheritdoc IArbitrageV5
    function setMaxMintBurnReserveTolerance(uint16 _maxMintBurnReserveTolerance) external onlyOwner {
        if (_maxMintBurnReserveTolerance > MAX_PRICE_TOLERANCE) {
            revert ToleranceTooBig(_maxMintBurnReserveTolerance);
        }
        maxMintBurnReserveTolerance = _maxMintBurnReserveTolerance;
        emit SetMaxMintBurnReserveTolerance(_maxMintBurnReserveTolerance);
    }

    /// @inheritdoc IArbitrageV5
    function setMintBurnFee(uint16 _mintBurnFee) external onlyOwner {
        if (_mintBurnFee > MAX_FEE) {
            revert FeeTooBig(_mintBurnFee);
        }

        mintBurnFee = _mintBurnFee;
        emit SetMintBurnFee(_mintBurnFee);
    }

    /// @inheritdoc IArbitrageV5
    function setReserveMintTxLimit(address reserveAsset, uint256 limit) external onlyOwner {
        reserveMintTxLimit[reserveAsset] = limit;
        emit SetReserveMintTxLimit(reserveAsset, limit);
    }

    /// @inheritdoc IArbitrageV5
    function setReserveBurnTxLimit(address reserveAsset, uint256 limit) external onlyOwner {
        reserveBurnTxLimit[reserveAsset] = limit;
        emit SetReserveBurnTxLimit(reserveAsset, limit);
    }

    /// @inheritdoc IArbitrageV5
    function updateArbitrager(address arbitrager, bool status) external onlyOwner {
        isArbitrager[arbitrager] = status;
        emit UpdateArbitrager(arbitrager, status);
    }

    /// @inheritdoc IArbitrageV5
    function updatePrivileged(address account, bool status) external onlyOwner {
        isPrivileged[account] = status;
        emit UpdatePrivileged(account, status);
    }

    /// @inheritdoc IArbitrageV5
    function claimRewards(IERC20[] memory tokens, uint256[] memory amounts) external onlyOwner {
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20 token = tokens[i];
            uint256 amount = amounts[i];

            token.safeTransfer(msg.sender, amount);

            if (address(token) == address(USC)) {
                if (amount < totalMintedUsc) {
                    totalMintedUsc -= amount;
                } else {
                    totalMintedUsc = 0;
                }
            }
        }
    }

    function rewardUSC(uint256 amount) external onlyOwner {
        USC.safeTransferFrom(msg.sender, address(this), amount);
        totalMintedUsc += amount;

        emit RewardUSC(amount);
    }

    /// @inheritdoc IArbitrageV5
    function mint(address token, uint256 amount, address receiver)
        external
        whenMintNotPaused
        nonReentrant
        onlyWhenMintableOrBurnable
        onlyBellowMintLimit(token, amount)
        returns (uint256)
    {
        uint256 fee = Math.mulDiv(amount, mintBurnFee, MAX_FEE);
        uint256 amountAfterFee = amount - fee;

        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(token).approve(address(reserveHolder), amountAfterFee);
        reserveHolder.deposit(token, amountAfterFee);

        return _mint(amountAfterFee, token, receiver);
    }

    /// @inheritdoc IArbitrageV5
    function mint(address receiver)
        external
        payable
        whenMintNotPaused
        nonReentrant
        onlyWhenMintableOrBurnable
        onlyBellowMintLimit(address(WETH), msg.value)
        returns (uint256)
    {
        uint256 ethAmount = msg.value;
        uint256 fee = Math.mulDiv(ethAmount, mintBurnFee, MAX_FEE);
        uint256 ethAmountAfterFee = ethAmount - fee;

        IWETH(WETH).deposit{value: ethAmount}();
        IERC20(WETH).safeTransfer(address(reserveHolder), ethAmountAfterFee);
        return _mint(ethAmountAfterFee, WETH, receiver);
    }

    /// @inheritdoc IArbitrageV5
    function burn(uint256 amount, address reserveToReceive)
        external
        whenBurnNotPaused
        nonReentrant
        onlyWhenMintableOrBurnable
        onlyBellowBurnLimit(reserveToReceive, amount)
        returns (uint256)
    {
        uint256 reservePrice = priceFeedAggregator.peek(reserveToReceive);

        USC.safeTransferFrom(msg.sender, address(this), amount);
        amount -= (amount * mintBurnFee) / MAX_FEE;
        USC.burn(amount);

        uint256 reserveAmountToRedeem = Math.mulDiv(amount, USC_TARGET_PRICE, reservePrice);

        reserveHolder.redeem(reserveAmountToRedeem, reserveToReceive);
        IERC20(reserveToReceive).safeTransfer(msg.sender, reserveAmountToRedeem);

        emit Burn(msg.sender, amount, reserveAmountToRedeem, reserveToReceive);
        return reserveAmountToRedeem;
    }

    /// @inheritdoc IArbitrageV5
    function executeArbitrageWithReserveSell(uint256 maxChiSpotPrice, SwapParams[] calldata swapParams)
        external
        returns (uint256)
    {
        for (uint256 i = 0; i < swapParams.length; i++) {
            reserveHolder.swapReserveForEth(
                swapParams[i].reserveAsset, swapParams[i].amountIn, swapParams[i].minAmountOut
            );
        }

        return executeArbitrage(maxChiSpotPrice);
    }

    /// @inheritdoc IArbitrageV5
    function executeArbitrage(uint256 maxChiSpotPrice) public override nonReentrant onlyArbitrager returns (uint256) {
        _validateArbitrage(maxChiSpotPrice);
        return _executeArbitrage();
    }

    /// @inheritdoc IArbitrageV5
    function getArbitrageData()
        public
        view
        returns (bool isPriceAtPeg, bool isPriceAboveTarget, bool isExcessOfReserves, uint256 reserveDiff)
    {
        uint256 ethPrice = priceFeedAggregator.peek(WETH);
        uint256 uscPrice = _getAndValidateUscPrice(ethPrice);

        uint256 reserveValue;
        (isExcessOfReserves, reserveDiff, reserveValue) = _getReservesData();
        isPriceAboveTarget = uscPrice >= USC_TARGET_PRICE;

        return (
            _almostEqualAbs(uscPrice, USC_TARGET_PRICE, pegPriceToleranceAbs),
            isPriceAboveTarget,
            isExcessOfReserves,
            reserveDiff
        );
    }

    function _executeArbitrage() internal returns (uint256) {
        (bool isPriceAtPeg, bool isPriceAboveTarget, bool isExcessOfReserves, uint256 reserveDiff) = getArbitrageData();

        uint256 ethPrice = priceFeedAggregator.peek(WETH);

        if (isPriceAtPeg) {
            if (isExcessOfReserves) {
                return _arbitrageAtPegExcessOfReserves(reserveDiff, ethPrice);
            } else {
                return _arbitrageAtPegDeficitOfReserves(reserveDiff, ethPrice);
            }
        } else if (isPriceAboveTarget) {
            if (isExcessOfReserves) {
                return _arbitrageAbovePegExcessOfReserves(reserveDiff, ethPrice);
            } else {
                return _arbitrageAbovePegDeficitOfReserves(reserveDiff, ethPrice);
            }
        } else {
            if (isExcessOfReserves) {
                return _arbitrageBellowPegExcessOfReserves(reserveDiff, ethPrice);
            } else {
                return _arbitrageBellowPegDeficitOfReserves(reserveDiff, ethPrice);
            }
        }
    }

    function _mint(uint256 amount, address token, address receiver) private returns (uint256) {
        uint256 usdValue;
        if (token == WETH) {
            uint256 ethPrice = priceFeedAggregator.peek(WETH);
            usdValue = _convertTokenAmountToUsdValue(amount, ethPrice);
        } else {
            uint256 tokenPrice = priceFeedAggregator.peek(token);
            usdValue = _convertTokenAmountToUsdValue(amount, tokenPrice);
        }

        uint256 uscAmountToMint = _convertUsdValueToTokenAmount(usdValue, USC_TARGET_PRICE);
        USC.mint(receiver, uscAmountToMint);
        emit Mint(msg.sender, token, amount, uscAmountToMint);
        return uscAmountToMint;
    }

    function _arbitrageAbovePegExcessOfReserves(uint256 reserveDiff, uint256 ethPrice) private returns (uint256) {
        uint256 deltaUSC = _calculateDeltaUSC(ethPrice);

        USC.mint(address(this), deltaUSC);
        uint256 ethAmountReceived = _swap(address(USC), WETH, deltaUSC);

        uint256 deltaUsd = _convertTokenAmountToUsdValue(deltaUSC, USC_TARGET_PRICE);
        uint256 deltaInETH = _convertUsdValueToTokenAmount(deltaUsd, ethPrice);

        if (deltaInETH > ethAmountReceived) {
            revert DeltaBiggerThanAmountReceivedETH(deltaInETH, ethAmountReceived);
        }

        uint256 ethAmountToSwap;
        uint256 ethAmountForReserves;

        if (deltaUsd > reserveDiff) {
            ethAmountToSwap = _convertUsdValueToTokenAmount(reserveDiff, ethPrice);
            ethAmountForReserves = _convertUsdValueToTokenAmount(deltaUsd, ethPrice) - ethAmountToSwap;
            IERC20(WETH).safeTransfer(address(reserveHolder), ethAmountForReserves);
        } else {
            ethAmountToSwap = _convertUsdValueToTokenAmount(deltaUsd, ethPrice);
        }

        uint256 chiAmountReceived = _swap(WETH, address(CHI), ethAmountToSwap);
        CHI.burn(chiAmountReceived);

        uint256 rewardAmount = ethAmountReceived - ethAmountToSwap - ethAmountForReserves;

        uint256 rewardValue = _convertTokenAmountToUsdValue(rewardAmount, ethPrice);
        emit ExecuteArbitrage(msg.sender, 1, deltaUsd, reserveDiff, ethPrice, rewardValue);
        return rewardValue;
    }

    function _arbitrageAbovePegDeficitOfReserves(uint256 reserveDiff, uint256 ethPrice) private returns (uint256) {
        uint256 deltaUSC = _calculateDeltaUSC(ethPrice);

        USC.mint(address(this), deltaUSC);
        uint256 ethAmountReceived = _swap(address(USC), WETH, deltaUSC);

        uint256 deltaUsd = _convertTokenAmountToUsdValue(deltaUSC, USC_TARGET_PRICE);
        uint256 deltaInETH = _convertUsdValueToTokenAmount(deltaUsd, ethPrice);

        if (deltaInETH > ethAmountReceived) {
            revert DeltaBiggerThanAmountReceivedETH(deltaInETH, ethAmountReceived);
        }

        IERC20(WETH).safeTransfer(address(reserveHolder), deltaInETH);

        uint256 rewardAmount = ethAmountReceived - deltaInETH;

        uint256 rewardValue = _convertTokenAmountToUsdValue(rewardAmount, ethPrice);
        emit ExecuteArbitrage(msg.sender, 2, deltaUsd, reserveDiff, ethPrice, rewardValue);
        return rewardValue;
    }

    function _arbitrageBellowPegExcessOfReserves(uint256 reserveDiff, uint256 ethPrice) private returns (uint256) {
        uint256 uscAmountToFreeze;
        uint256 uscAmountToBurn;

        uint256 deltaETH = _calculateDeltaETH(ethPrice);
        uint256 deltaUsd = _convertTokenAmountToUsdValue(deltaETH, ethPrice);

        if (deltaUsd > reserveDiff) {
            uscAmountToFreeze = _convertUsdValueToTokenAmount(reserveDiff, USC_TARGET_PRICE);
            uscAmountToBurn = _convertUsdValueToTokenAmount(deltaUsd - reserveDiff, USC_TARGET_PRICE);
        } else {
            uscAmountToFreeze = _convertUsdValueToTokenAmount(deltaUsd, USC_TARGET_PRICE);
        }

        reserveHolder.redeem(deltaETH, address(WETH));
        uint256 uscAmountReceived = _swap(WETH, address(USC), deltaETH);

        if (uscAmountReceived < uscAmountToFreeze) {
            uscAmountToFreeze = uscAmountReceived;
        }

        if (uscAmountToBurn > 0) {
            USC.burn(uscAmountToBurn);
        }

        uint256 rewardAmount = uscAmountReceived - uscAmountToFreeze - uscAmountToBurn;
        uint256 rewardValue = _convertTokenAmountToUsdValue(rewardAmount, USC_TARGET_PRICE);
        emit ExecuteArbitrage(msg.sender, 3, deltaUsd, reserveDiff, ethPrice, rewardValue);
        return rewardValue;
    }

    function _arbitrageBellowPegDeficitOfReserves(uint256 reserveDiff, uint256 ethPrice) private returns (uint256) {
        uint256 ethAmountToRedeem;
        uint256 ethAmountFromChi;

        uint256 deltaETH = _calculateDeltaETH(ethPrice);
        uint256 deltaUsd = _convertTokenAmountToUsdValue(deltaETH, ethPrice);

        if (deltaUsd > reserveDiff) {
            ethAmountFromChi = _convertUsdValueToTokenAmount(reserveDiff, ethPrice);
            ethAmountToRedeem = deltaETH - ethAmountFromChi;
            reserveHolder.redeem(ethAmountToRedeem, address(WETH));
        } else {
            ethAmountFromChi = deltaETH;
        }

        uint256 uscAmountToBurn = _convertUsdValueToTokenAmount(deltaUsd, USC_TARGET_PRICE);

        uint256 uscAmountReceived;
        {
            if (ethAmountFromChi > 0) {
                uint256 chiAmountToMint = _getAmountInForAmountOut(address(CHI), WETH, ethAmountFromChi);
                CHI.mint(address(this), chiAmountToMint);
                _swap(address(CHI), WETH, chiAmountToMint);
            }

            uscAmountReceived = _swap(WETH, address(USC), ethAmountFromChi + ethAmountToRedeem);
        }

        if (uscAmountToBurn > 0) {
            USC.burn(uscAmountToBurn);
        }

        {
            uint256 rewardAmount = uscAmountReceived - uscAmountToBurn;
            uint256 rewardValue = _convertTokenAmountToUsdValue(rewardAmount, USC_TARGET_PRICE);
            emit ExecuteArbitrage(msg.sender, 4, deltaUsd, reserveDiff, ethPrice, rewardValue);
            return rewardValue;
        }
    }

    function _arbitrageAtPegExcessOfReserves(uint256 reserveDiff, uint256 ethPrice) private returns (uint256) {
        uint256 uscAmountToMint = _convertUsdValueToTokenAmount(reserveDiff, USC_TARGET_PRICE);

        USC.mint(address(this), uscAmountToMint);
        totalMintedUsc += uscAmountToMint;

        emit ExecuteArbitrage(msg.sender, 5, 0, reserveDiff, ethPrice, 0);
        return 0;
    }

    function _arbitrageAtPegDeficitOfReserves(uint256 reserveDiff, uint256 ethPrice) private returns (uint256) {
        uint256 reserveDiffInUsc = _convertUsdValueToTokenAmount(reserveDiff, USC_TARGET_PRICE);

        uint256 uscAmountToBurn;
        uint256 ethToGet;
        if (reserveDiffInUsc > totalMintedUsc) {
            uscAmountToBurn = totalMintedUsc;

            uint256 ethToGetInUsd = _convertTokenAmountToUsdValue(reserveDiffInUsc - totalMintedUsc, USC_TARGET_PRICE);
            ethToGet = _convertUsdValueToTokenAmount(ethToGetInUsd, ethPrice);
        } else {
            uscAmountToBurn = reserveDiffInUsc;
            ethToGet = 0;
        }

        uint256 chiToCoverEth;
        if (ethToGet > 0) {
            chiToCoverEth = _getAmountInForAmountOut(address(CHI), WETH, ethToGet);
        }

        CHI.mint(address(this), chiToCoverEth);

        if (ethToGet > 0) {
            uint256 ethReceived = _swap(address(CHI), WETH, chiToCoverEth);
            IERC20(WETH).safeTransfer(address(reserveHolder), ethReceived);
        }

        if (uscAmountToBurn > 0) {
            USC.burn(uscAmountToBurn);
            totalMintedUsc -= uscAmountToBurn;
        }

        emit ExecuteArbitrage(msg.sender, 6, 0, reserveDiff, ethPrice, 0);
        return 0;
    }

    function _getReservesData()
        public
        view
        returns (bool isExcessOfReserves, uint256 reserveDiff, uint256 reserveValue)
    {
        reserveValue = reserveHolder.getReserveValue();
        uint256 uscTotalSupplyValue = _convertTokenAmountToUsdValue(USC.totalSupply(), USC_TARGET_PRICE);

        if (reserveValue > uscTotalSupplyValue) {
            isExcessOfReserves = true;
            reserveDiff = (reserveValue - uscTotalSupplyValue);
        } else {
            isExcessOfReserves = false;
            reserveDiff = (uscTotalSupplyValue - reserveValue);
        }
    }

    function _getAndValidateUscPrice(uint256 ethPrice) private view returns (uint256) {
        uint256 uscPrice = priceFeedAggregator.peek(address(USC));
        uint256 uscSpotPrice = _calculateUscSpotPrice(ethPrice);
        uint256 priceDiff = _absDiff(uscSpotPrice, uscPrice);
        uint256 maxPriceDiff = Math.mulDiv(uscPrice, priceTolerance, MAX_PRICE_TOLERANCE);

        if (priceDiff > maxPriceDiff) {
            revert PriceSlippageTooBig();
        }

        return uscSpotPrice;
    }

    function _validateArbitrage(uint256 maxChiSpotPrice) private view {
        if (!isPrivileged[msg.sender]) {
            uint256 ethPrice = priceFeedAggregator.peek(WETH);
            uint256 chiSpotPrice = _calculateChiSpotPrice(ethPrice);

            if (maxChiSpotPrice != 0 && chiSpotPrice > maxChiSpotPrice) {
                revert ChiSpotPriceTooBig();
            }

            // If max chi spot price is not specified we need to check for twap difference
            if (maxChiSpotPrice == 0) {
                uint256 chiOraclePrice = priceFeedAggregator.peek(address(CHI));

                if (!_almostEqualRel(chiSpotPrice, chiOraclePrice, chiPriceTolerance)) {
                    revert ChiPriceNotPegged(chiSpotPrice, chiOraclePrice);
                }
            }
        }
    }

    // input ethPrice has 8 decimals
    // returns result with 8 decimals
    function _calculateUscSpotPrice(uint256 ethPrice) private view returns (uint256) {
        (uint256 reserveUSC, uint256 reserveWETH) =
            UniswapV2Library.getReserves(address(poolFactory), address(USC), address(WETH));
        uint256 uscFor1ETH = UniswapV2Library.quote(1 ether, reserveWETH, reserveUSC);
        return Math.mulDiv(ethPrice, 1 ether, uscFor1ETH);
    }

    // input ethPrice has 8 decimals
    // returns result with 8 decimals
    function _calculateChiSpotPrice(uint256 ethPrice) private view returns (uint256) {
        (uint256 reserveCHI, uint256 reserveWETH) =
            UniswapV2Library.getReserves(address(poolFactory), address(CHI), address(WETH));
        uint256 chiFor1ETH = UniswapV2Library.quote(1 ether, reserveWETH, reserveCHI);
        return Math.mulDiv(ethPrice, 1 ether, chiFor1ETH);
    }

    // what amount of In tokens to put in pool to make price:   1 tokenOut = (priceOut / priceIn) tokenIn
    // assuming reserves are on 18 decimals, prices are on 8 decimals
    function _calculateDelta(uint256 reserveIn, uint256 priceIn, uint256 reserveOut, uint256 priceOut)
        public
        pure
        returns (uint256)
    {
        // F = (1 - pool_fee) = 0.997 on 18 decimals,   in square root formula  a = F

        // parameter `b` in square root formula,  b = rIn * (1+f) ,  on 18 decimals
        uint256 b = Math.mulDiv(reserveIn, 1e18 + F, 1e18);
        uint256 b_sqr = Math.mulDiv(b, b, 1e18);

        // parameter `c` in square root formula,  c = rIn^2 - (rIn * rOut * priceOut) / priceIn
        uint256 c_1 = Math.mulDiv(reserveIn, reserveIn, 1e18);
        uint256 c_2 = Math.mulDiv(Math.mulDiv(reserveIn, reserveOut, 1e18), priceOut, priceIn);

        uint256 c;
        uint256 root;
        if (c_1 > c_2) {
            c = c_1 - c_2;
            // d = 4ac
            uint256 d = Math.mulDiv(4 * F, c, 1e18);

            // root = sqrt(b^2 - 4ac)
            // multiplying by 10^9 to get back to 18 decimals
            root = Math.sqrt(b_sqr - d) * 1e9;
        } else {
            c = c_2 - c_1;
            // d = 4ac
            uint256 d = Math.mulDiv(4 * F, c, 1e18);

            // root = sqrt(b^2 - 4ac)    -> in this case `c` is negative, so we add `d` to `b^2`
            // multiplying by 10^9 to get back to 18 decimals
            root = Math.sqrt(b_sqr + d) * 1e9;
        }
        // delta = (-b + root) / 2*f
        uint256 delta = Math.mulDiv(1e18, root - b, 2 * F);

        return delta;
    }

    // given ethPrice is on 8 decimals
    // how many USC to put in pool to make price:   1 ETH = ethPrice * USC
    function _calculateDeltaUSC(uint256 ethPrice) public view returns (uint256) {
        (uint256 reserveUSC, uint256 reserveWETH) =
            UniswapV2Library.getReserves(address(poolFactory), address(USC), address(WETH));
        return _calculateDelta(reserveUSC, USC_TARGET_PRICE, reserveWETH, ethPrice);
    }

    // how many ETH to put in pool to make price:   1 ETH = ethPrice * USC
    function _calculateDeltaETH(uint256 ethPrice) public view returns (uint256) {
        (uint256 reserveUSC, uint256 reserveWETH) =
            UniswapV2Library.getReserves(address(poolFactory), address(USC), address(WETH));
        return _calculateDelta(reserveWETH, ethPrice, reserveUSC, USC_TARGET_PRICE);
    }

    function _makePath(address t1, address t2) internal pure returns (address[] memory path) {
        path = new address[](2);
        path[0] = t1;
        path[1] = t2;
    }

    function _makePath(address t1, address t2, address t3) internal pure returns (address[] memory path) {
        path = new address[](3);
        path[0] = t1;
        path[1] = t2;
        path[2] = t3;
    }

    function _swap(address tokenIn, address tokenOut, uint256 amount) private returns (uint256) {
        address[] memory path;

        if (tokenIn != WETH && tokenOut != WETH) {
            path = _makePath(tokenIn, WETH, tokenOut);
        } else {
            path = _makePath(tokenIn, tokenOut);
        }

        IERC20(tokenIn).approve(address(swapRouter), amount);
        uint256[] memory amounts = swapRouter.swapExactTokensForTokens(amount, 0, path, address(this), block.timestamp);

        uint256 amountReceived = amounts[path.length - 1];

        return amountReceived;
    }

    function _getAmountInForAmountOut(address tIn, address tOut, uint256 amountOut) internal view returns (uint256) {
        (uint256 rIn, uint256 rOut) = UniswapV2Library.getReserves(address(poolFactory), tIn, tOut);
        return UniswapV2Library.getAmountIn(amountOut, rIn, rOut);
    }

    function _convertUsdValueToTokenAmount(uint256 usdValue, uint256 price) internal pure returns (uint256) {
        return Math.mulDiv(usdValue, 1e18, price);
    }

    function _convertTokenAmountToUsdValue(uint256 amount, uint256 price) internal pure returns (uint256) {
        return Math.mulDiv(amount, price, 1e18);
    }

    function _absDiff(uint256 a, uint256 b) internal pure returns (uint256) {
        return (a > b) ? a - b : b - a;
    }

    function _almostEqualAbs(uint256 price1, uint256 price2, uint256 delta) internal pure returns (bool) {
        return _absDiff(price1, price2) <= delta;
    }

    function _almostEqualRel(uint256 price1, uint256 price2, uint256 delta) internal pure returns (bool) {
        (uint256 highPrice, uint256 lowPrice) = price1 > price2 ? (price1, price2) : (price2, price1);
        uint256 priceDiff = highPrice - lowPrice;
        uint256 maxPriceDiff = Math.mulDiv(highPrice, delta, MAX_PRICE_TOLERANCE);

        return priceDiff <= maxPriceDiff;
    }

    receive() external payable {}
}
