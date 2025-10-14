// SPDX-License-Identifier: MIT

// Solidity files have to start with this pragma.
// It will be used by the Solidity compiler to validate its version.
pragma solidity ^0.8.28;
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_3_0/FunctionsClient.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import {ITokenAsset} from "./interfaces/ITokenAsset.sol";

// TODO: Optimize contract for Gas with correct types, do not use uint256 when not needed
import "hardhat/console.sol";

contract TokenAsset is
    ITokenAsset,
    ERC1155,
    ERC2981,
    Ownable,
    FunctionsClient,
    ReentrancyGuard
{
    using FunctionsRequest for FunctionsRequest.Request;
    using Strings for uint256;

    event Deployed(uint256 indexed id);
    event Withdrawn(uint256 indexed id, address indexed from, uint256 quantity);

    event MintSuccess(
        uint256 indexed id,
        address indexed to,
        uint256 quantity,
        string status
    );

    event MintError(
        bytes32 indexed requestId,
        address indexed to,
        string reason
    );

    struct MintRequest {
        uint256 id;
        address to;
        uint256 quantity;
    }

    uint32 private constant GAS_LIMIT = 300000;

    string public contractURI;
    uint256 public nextTokenId;
    mapping(uint256 => string) public uris;
    mapping(uint256 => uint256) public usdPricePerShare;
    mapping(uint256 => uint256) public availableSupply;
    mapping(uint256 => uint256) public totalSupply;

    mapping(bytes32 => MintRequest) private _mintRequests;
    string private _fnMintJS;
    uint64 private immutable _fnSubscriptionId;
    bytes32 private immutable _fnDonId;

    // ETH / USD
    AggregatorV3Interface private immutable _dataFeed;

    constructor(
        string memory _contractURI,
        address priceFeedAddress,
        string memory fnMintJS,
        address fnRouterAddress,
        bytes32 fnDonId,
        uint64 fnSubscriptionId
    ) ERC1155("") Ownable(msg.sender) FunctionsClient(fnRouterAddress) {
        contractURI = _contractURI;
        _dataFeed = AggregatorV3Interface(priceFeedAddress);
        _fnMintJS = fnMintJS;
        _fnSubscriptionId = fnSubscriptionId;
        _fnDonId = fnDonId;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155, IERC165, ERC2981) returns (bool) {
        return
            interfaceId == type(ITokenAsset).interfaceId ||
            ERC1155.supportsInterface(interfaceId) ||
            ERC2981.supportsInterface(interfaceId);
    }

    function getQuote(
        uint256 id
    ) public view returns (uint256, uint80, uint256) {
        (uint80 roundId, int256 price, uint256 startedAt, , ) = _dataFeed
            .latestRoundData();
        uint256 amountInEth = ((usdPricePerShare[id] * 1e18) / uint256(price)) *
            1e8; // to have all in wei

        return (amountInEth, roundId, startedAt);
    }

    function getQuoteForRound(
        uint256 id,
        uint80 roundId
    ) internal view returns (uint256, uint80, uint256) {
        (, int256 price, uint256 startedAt, , ) = _dataFeed.getRoundData(
            roundId
        );
        uint256 amountInEth = ((usdPricePerShare[id] * 1e18) / uint256(price)) *
            1e8; // to have all in wei

        return (amountInEth, roundId, startedAt);
    }

    function uri(
        uint256 id
    ) public view virtual override(ERC1155) returns (string memory) {
        return uris[id];
    }

    function deploy(
        uint256 quantity,
        uint256 _usdPricePerShare,
        string calldata tokenUri
    ) external override onlyOwner returns (uint256) {
        require(quantity > 0, "Quantity must be greater than zero");

        uint256 id = nextTokenId;

        uris[id] = tokenUri;
        availableSupply[id] = quantity;
        totalSupply[id] = quantity;
        usdPricePerShare[id] = _usdPricePerShare;

        emit Deployed(id);

        nextTokenId++;

        return id;
    }

    function mint(
        uint256 id,
        uint256 quantity,
        uint80 roundId
    ) external payable override nonReentrant {
        require(
            availableSupply[id] - quantity >= 0,
            "There are not enough token"
        );

        (uint256 quoteInEth, , ) = getQuoteForRound(id, roundId);

        // TODO: Check round timestamp to avoid old rounds

        require(quoteInEth > 0, "No quote available for that round");
        require(
            (quoteInEth * quantity) == msg.value,
            "You must send the exact amount"
        );

        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(_fnMintJS);

        string[] memory args = new string[](4);
        args[0] = id.toString();
        args[1] = quantity.toString();
        args[2] = Strings.toHexString(uint160(msg.sender), 20);
        // TODO: Use VRF or better source of randomness?
        args[3] = block.number.toString();

        console.log(args[3]);

        req.setArgs(args);

        bytes32 requestId = _sendRequest(
            req.encodeCBOR(),
            _fnSubscriptionId,
            GAS_LIMIT,
            _fnDonId
        );

        _mintRequests[requestId] = MintRequest({
            id: id,
            to: msg.sender,
            quantity: quantity
        });
    }

    function _fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        if (err.length > 0) {
            // TODO: Refund user if error?
            emit MintError(requestId, address(0), string(err));
        } else {
            MintRequest memory mintReq = _mintRequests[requestId];
            if (mintReq.to == address(0) || mintReq.quantity == 0) {
                emit MintError(requestId, address(0), "No Mint Request");
                return;
            }

            availableSupply[mintReq.id] -= mintReq.quantity;
            _mint(mintReq.to, mintReq.id, mintReq.quantity, "");

            emit MintSuccess(
                mintReq.id,
                mintReq.to,
                mintReq.quantity,
                string(response)
            );
        }

        delete _mintRequests[requestId];
    }

    function withdraw(
        uint256 id,
        uint256 quantity
    ) external override nonReentrant {
        require(
            availableSupply[id] + quantity <= totalSupply[id],
            "Too many tokens to withdraw"
        );

        require(
            quantity <= balanceOf(msg.sender, id),
            "Sender does not own enough tokens"
        );

        availableSupply[id] += quantity;

        _burn(msg.sender, id, quantity);

        // That wouldn't work if the price of ETH has increased since the minting
        // and the user wants to withdraw all his investment
        // But it's ok for a demo / PoC
        (uint256 amountInEth, , ) = getQuote(id);
        amountInEth = amountInEth * quantity;
        payable(msg.sender).transfer(amountInEth);

        emit Withdrawn(id, msg.sender, quantity);

        // TODO: Call Chainlink function to notify the withdrawal
        // And update database off-chain
    }

    function setContractURI(string calldata newContractURI) external onlyOwner {
        contractURI = newContractURI;
    }

    function adminSafeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 quantity
    ) external override onlyOwner nonReentrant {
        return _safeTransferFrom(from, to, id, quantity, "");
    }

    function adminWithdraw(
        uint256 amount
    ) external override onlyOwner nonReentrant {
        payable(owner()).transfer(amount);
    }
}
