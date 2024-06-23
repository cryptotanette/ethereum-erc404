// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./ERC404.sol";


interface IBlazeSwapBaseFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint256 count);

    function getPair(address tokenA, address tokenB) external view returns (address pair);

    function allPairs(uint256) external view returns (address pair);

    function allPairsLength() external view returns (uint256);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function manager() external view returns (address);
}

interface IBlazeSwapMulticall {
    function multicall(bytes[] calldata data) external returns (bytes[] memory results);
}

interface IBlazeSwapRouter is IBlazeSwapMulticall {
    function factory() external view returns (address);

    function wNat() external view returns (address);

    // Note:
    // The minimum amounts and the returned amounts in the add/remove liquidity
    // functions are *always* relative to the sent amounts, the received amounts may
    // be different in the case of fee-on-transfer tokens.
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        uint256 feeBipsA,
        uint256 feeBipsB,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    function addLiquidityNAT(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountNATMin,
        uint256 feeBipsToken,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountNAT, uint256 liquidity);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityNAT(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountNATMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountNAT);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityNATWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountNATMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountNAT);

    // Note:
    // Swap functions with exact input can be called with paths including fee-on-transfer tokens,
    // and the `amountOutMin` will be checked against what's actually been received by the `to` address.
    // Swap functions with exact output cannot be called with paths including fee-on-transfer tokes.
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amountsSent, uint256[] memory amountsRecv);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactNATForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amountsSent, uint256[] memory amountsRecv);

    function swapTokensForExactNAT(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForNAT(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amountsSent, uint256[] memory amountsRecv);

    function swapNATForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) external pure returns (uint256 amountB);

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut);

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountIn);

    function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts);

    function getAmountsIn(uint256 amountOut, address[] calldata path) external view returns (uint256[] memory amounts);

    function pairFor(address tokenA, address tokenB) external view returns (address);

    function getReserves(address tokenA, address tokenB) external view returns (uint256, uint256);

    function selfPermit(address token, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
}
contract HEPEREFLECTION is ERC404 {
    using Strings for uint256;

    string public dataURI;
    string public baseTokenURI;
    string public metaDescription;

    IBlazeSwapRouter public blazeSwapRouter;
    address public liquidityPair;
    uint256 public pairBalance;
    uint256 public lpPercentage = 300; // 3%
    bool private inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;
    uint256 public minTokensBeforeSwap = 1 * 10**18;
    uint256 public burnPercentage = 133; // 1.33%
    uint256 public reflectionPercentage = 169; // 1.69%
    address[] private _holders;
    mapping(address => bool) private _isHolder;
    mapping(address => uint256) private _holderIndex;

    event SwapAndLiquify(uint256 tokensSwapped, uint256 ethReceived, uint256 tokensIntoLiqudity);
    event Burn(address indexed from, uint256 amount);
    event Reflect(uint256 amount);
    event DebugLog(string message, address indexed from, address indexed to, uint256 amount, uint256 balanceFrom, uint256 balanceTo);
    event DebugLogSwap(string message, uint256 contractTokenBalance, uint256 half, uint256 otherHalf, uint256 initialBalance, uint256 newBalance);

    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    address private constant FACTORY_ADDRESS = 0x440602f459D7Dd500a74528003e6A20A46d6e2A6;
    address private constant ROUTER_ADDRESS = 0xe3A1b355ca63abCBC9589334B5e609583C7BAa06;
  

    constructor(address _owner) ERC404("WEee", "WEE", 18, 777, _owner) {
        blazeSwapRouter = IBlazeSwapRouter(ROUTER_ADDRESS);
        balanceOf[_owner] = 777 * 10**18;
        whitelist[_owner] = true;
        totalSupply = 777 * 10**18;
        _addHolder(_owner);
        dataURI = "https://bafybeibcqeb7qhtmvgh6bn6dtqh6zjmnqlqz4k4q7gxlfpfpz2tyvxfuge.ipfs.nftstorage.link/";
        baseTokenURI = "";
        metaDescription = "HepeTest8 is a collection of 777 unique NFTs. Each NFT is a unique combination of a retro futuristic character and a color theme.";
    }

    function _addHolder(address holder) internal {
        if (!_isHolder[holder]) {
            _holders.push(holder);
            _isHolder[holder] = true;
            _holderIndex[holder] = _holders.length - 1;
        }
    }

    function _removeHolder(address holder) internal {
        if (_isHolder[holder] && balanceOf[holder] == 0) {
            uint256 index = _holderIndex[holder];
            _holders[index] = _holders[_holders.length - 1];
            _holderIndex[_holders[index]] = index;
            _holders.pop();
            _isHolder[holder] = false;
        }
    }

    function _updateHolder(address holder) internal {
        if (balanceOf[holder] > 0) {
            _addHolder(holder);
        } else {
            _removeHolder(holder);
        }
    }

    function holders() public view returns (address[] memory) {
        return _holders;
    }

    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
    }

    function setMinTokensBeforeSwap(uint256 _minTokensBeforeSwap) public onlyOwner {
        minTokensBeforeSwap = _minTokensBeforeSwap;
    }

    // Function to get the current total supply
    function currentTotalSupply() public view virtual returns (uint256) {
        return totalSupply;
    }

    // Manually set a pool address for the pair of tokens
    function setPool(address _pair) public onlyOwner {
        liquidityPair = _pair;
    }

    // Set the LP percentage
    function setLpPercentage(uint256 percentage) public onlyOwner {
        require(percentage <= 1000, "Percentage too high"); // Maximum 10%
        lpPercentage = percentage;
    }

    // Set the burn percentage
    function setBurnPercentage(uint256 percentage) public onlyOwner {
        require(percentage <= 1000, "Percentage too high"); // Maximum 10%
        burnPercentage = percentage;
    }

    // Set the reflection percentage
    function setReflectionPercentage(uint256 percentage) public onlyOwner {
        require(percentage <= 1000, "Percentage too high"); // Maximum 10%
        reflectionPercentage = percentage;
    }

    // Internal function to add liquidity
    function _addLiquidity(
    address tokenA,
    address tokenB,
    uint256 amountADesired,
    uint256 amountBDesired,
    uint256 amountAMin,
    uint256 amountBMin
) internal {
    approve(address(blazeSwapRouter), amountADesired);

    if (tokenA == blazeSwapRouter.wNat() || tokenB == blazeSwapRouter.wNat()) {
        address token = tokenA == blazeSwapRouter.wNat() ? tokenB : tokenA;
        uint256 amountTokenDesired = tokenA == blazeSwapRouter.wNat() ? amountBDesired : amountADesired;
        uint256 amountNATDesired = tokenA == blazeSwapRouter.wNat() ? amountADesired : amountBDesired;
        uint256 amountTokenMin = tokenA == blazeSwapRouter.wNat() ? amountBMin : amountAMin;
        uint256 amountNATMin = tokenA == blazeSwapRouter.wNat() ? amountAMin : amountBMin;

        blazeSwapRouter.addLiquidityNAT{value: amountNATDesired}(
            token,
            amountTokenDesired,
            amountTokenMin,
            amountNATMin,
            0, // assuming feeBipsToken is 0 or set it as needed
            address(this),
            block.timestamp
        );
    } else {
        approve(address(blazeSwapRouter), amountBDesired);

        blazeSwapRouter.addLiquidity(
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            0, // assuming feeBipsA is 0 or set it as needed
            0, // assuming feeBipsB is 0 or set it as needed
            address(this),
            block.timestamp
        );
    }
}

    // Set data URI
    function setDataURI(string memory _dataURI) public onlyOwner {
        dataURI = _dataURI;
    }

    // Set base token URI
    function setTokenURI(string memory _tokenURI) public onlyOwner {
        baseTokenURI = _tokenURI;
    }

    // Set token name and symbol
    function setNameSymbol(string memory _name, string memory _symbol) public onlyOwner {
        _setNameSymbol(_name, _symbol);
    }

    // Set metadata description
    function setMetaDescription(string memory _metaDesc) public onlyOwner {
        metaDescription = _metaDesc;
    }

    function getNftImg(uint256 id) internal pure returns (string[2] memory) {
        uint8 idSeed = uint8(bytes1(keccak256(abi.encodePacked(id))));
        string memory image;
        string memory color;
        if (idSeed <= 100) {
            image = "1.jpg";
            color = "Retro Punk";
        } else if (idSeed <= 130) {
            image = "2.jpg";
            color = "Hybrid Cyborg";
        } else if (idSeed <= 160) {
            image = "3.jpg";
            color = "Ai Commander";
        } else if (idSeed <= 190) {
            image = "4.jpg";
            color = "Cyber Renegade";
        } else if (idSeed <= 220) {
            image = "5.jpg";
            color = "Web3 Evangelist";
        } else if (idSeed <= 255) {
            image = "6.jpg";
            color = "Future Humanoid";
        }
        return [image, color];
    }

    function base64Encode(bytes memory data) internal pure returns (string memory) {
        string memory table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        uint256 encodedLen = 4 * ((data.length + 2) / 3);
        string memory result = new string(encodedLen + 32);

        assembly {
            mstore(result, encodedLen)

            let tablePtr := add(table, 1)
            let resultPtr := add(result, 32)
            let dataPtr := data
            let endPtr := add(dataPtr, mload(data))

            for {} lt(dataPtr, endPtr) {}
            {
                dataPtr := add(dataPtr, 3)
                let input := mload(dataPtr)
                mstore(resultPtr, shl(248, mload(add(tablePtr, and(shr(18, input), 0x3F)))))
                resultPtr := add(resultPtr, 1)
                mstore(resultPtr, shl(248, mload(add(tablePtr, and(shr(12, input), 0x3F)))))
                resultPtr := add(resultPtr, 1)
                mstore(resultPtr, shl(248, mload(add(tablePtr, and(shr(6, input), 0x3F)))))
                resultPtr := add(resultPtr, 1)
                mstore(resultPtr, shl(248, mload(add(tablePtr, and(input, 0x3F)))))
                resultPtr := add(resultPtr, 1)
            }

            switch mod(mload(data), 3)
            case 1 { mstore(sub(resultPtr, 2), shl(240, 0x3d3d)) }
            case 2 { mstore(sub(resultPtr, 1), shl(248, 0x3d)) }
        }

        return result;
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        if (bytes(baseTokenURI).length > 0) {
            return string(abi.encodePacked(baseTokenURI, id.toString()));
        } else {
            string memory image = getNftImg(id)[0];
            string memory color = getNftImg(id)[1];
            string memory json = string(abi.encodePacked(
                '{"name":"HepeTest8 #', id.toString(), '",',
                '"description":"', metaDescription, '",',
                '"external_url":"https://net2dev.io",',
                '"image":"', dataURI, image, '",',
                '"attributes":[{"trait_type":"Color","value":"', color, '"}]}'
            ));
            string memory encodedJson = base64Encode(bytes(json));
            return string(abi.encodePacked("data:application/json;base64,", encodedJson));
        }
    }

    // Transfer tokens with automatic liquidity provisioning, burning, and reflection
    function _transfer(address sender, address recipient, uint256 amount) internal virtual override returns (bool) {
        uint256 remainingAmount = amount;

        // Log initial balances
        emit DebugLog("Before Transfer", sender, recipient, amount, balanceOf[sender], balanceOf[recipient]);

        // Calculate and burn the burn portion
        uint256 burnAmount = (amount * burnPercentage) / 10000;
        remainingAmount -= burnAmount;
        balanceOf[sender] -= burnAmount;
        totalSupply -= burnAmount;
        emit Burn(sender, burnAmount);

        // Calculate and distribute reflection portion
        uint256 reflectionAmount = (amount * reflectionPercentage) / 10000;
        remainingAmount -= reflectionAmount;
        _reflect(sender, reflectionAmount);
        emit Reflect(reflectionAmount);

        // Distribute liquidity portion
        uint256 liquidityAmount = (amount * lpPercentage) / 10000;
        remainingAmount -= liquidityAmount;
        pairBalance += liquidityAmount;
        emit DebugLog("Liquidity Added", sender, address(this), liquidityAmount, balanceOf[sender], pairBalance);
        if (pairBalance >= minTokensBeforeSwap) {
            emit DebugLog("Before swapAndLiquify", address(this), address(this), pairBalance, balanceOf[address(this)], 0);
            swapAndLiquify(pairBalance);
            emit DebugLog("After swapAndLiquify", address(this), address(this), pairBalance, balanceOf[address(this)], 0);
            pairBalance = 0;
        }

        // Log balances after burning, reflecting, and liquidity distribution
        emit DebugLog("After Burn, Reflect, Liquidity", sender, recipient, amount, balanceOf[sender], balanceOf[recipient]);

        super._transfer(sender, recipient, remainingAmount);
        _updateHolder(sender);
        _updateHolder(recipient);

        // Log final balances
        emit DebugLog("After Transfer", sender, recipient, amount, balanceOf[sender], balanceOf[recipient]);

        return true;
    }

    // Reflect tokens to all holders
    function _reflect(address sender, uint256 reflectionAmount) private {
        uint256 totalTokenSupply = totalSupply; // Access total supply directly as a variable
        for (uint256 i = 0; i < _holders.length; i++) {
            address holder = _holders[i];
            uint256 holderBalance = balanceOf[holder];
            if (holderBalance > 0) {
                uint256 reflectionForHolder = (reflectionAmount * holderBalance) / totalTokenSupply;
                super._transfer(sender, holder, reflectionForHolder);
            }
        }
    }

    // Swap and liquify tokens
    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        uint256 half = contractTokenBalance / 2;
        uint256 otherHalf = contractTokenBalance - half;

        uint256 initialBalance = address(this).balance;

        emit DebugLogSwap("Before swapTokensForEth", contractTokenBalance, half, otherHalf, initialBalance, 0);
        swapTokensForEth(half);

        uint256 newBalance = address(this).balance - initialBalance;

        emit DebugLogSwap("After swapTokensForEth", contractTokenBalance, half, otherHalf, initialBalance, newBalance);
        addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    // Swap tokens for ETH
    function swapTokensForEth(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = blazeSwapRouter.wNat();

        approve(address(blazeSwapRouter), tokenAmount);

        blazeSwapRouter.swapExactTokensForNAT(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    // Correcting the addLiquidityNAT function call in the addLiquidity function
function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
    approve(address(blazeSwapRouter), tokenAmount);

    blazeSwapRouter.addLiquidityNAT{value: ethAmount}(
        address(this),
        tokenAmount,
        0, // assuming amountTokenMin is 0 or set it as needed
        0, // assuming amountNATMin is 0 or set it as needed
        0, // assuming feeBipsToken is 0 or set it as needed
        address(this),
        block.timestamp
    );
}

    // Function to check the balance of a specific ERC20 token held by the contract
    function checkERC20Balance(address tokenAddress) public view returns (uint256) {
        IERC20 token = IERC20(tokenAddress);
        return token.balanceOf(address(this));
    }

    // Function to check the balance of native tokens held by the contract
    function checkNativeTokenBalance() public view returns (uint256) {
        return address(this).balance;
    }

    // Manually trigger the swap and add liquidity process
    function manualSwapAndLiquify() external onlyOwner {
        uint256 contractTokenBalance = balanceOf[address(this)];
        require(contractTokenBalance >= minTokensBeforeSwap, "Not enough tokens to swap and liquify");
        swapAndLiquify(contractTokenBalance);
    }

    // Allow contract to receive ETH
    receive() external payable {}
}
