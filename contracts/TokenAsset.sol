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
    using Strings for int256;

    event Deployed(uint256 indexed id);

    event MintSuccess(
        uint256 indexed id,
        address indexed to,
        uint256 quantity,
        string status
    );

    event WithdrawSuccess(
        uint256 indexed id,
        address indexed from,
        uint256 quantity,
        string status
    );

    event UpdateError(
        bytes32 indexed requestId,
        address indexed to,
        string reason
    );

    struct UpdateRequest {
        uint256 id;
        address to;
        // quantity can be negative in case of withdraw
        int256 quantity;
        uint256 amountInEth;
    }

    uint32 private constant GAS_LIMIT = 300000;

    string public contractURI;
    uint256 public nextTokenId;
    mapping(uint256 => string) public uris;
    mapping(uint256 => uint256) public usdPricePerShare;
    mapping(uint256 => uint256) public availableSupply;
    mapping(uint256 => uint256) public totalSupply;

    mapping(bytes32 => UpdateRequest) private _updateRequests;
    string private _fnUpdateJS;
    uint64 private immutable _fnSubscriptionId;
    bytes32 private immutable _fnDonId;
    bytes private _encryptedSecretsUrls;
    uint256 private _requestCounter;

    // ETH / USD
    AggregatorV3Interface private immutable _dataFeed;

    constructor(
        string memory _contractURI,
        address priceFeedAddress,
        string memory fnUpdateJS,
        address fnRouterAddress,
        bytes32 fnDonId,
        uint64 fnSubscriptionId,
        bytes memory encryptedSecretsUrls
    ) ERC1155("") Ownable(msg.sender) FunctionsClient(fnRouterAddress) {
        contractURI = _contractURI;
        _dataFeed = AggregatorV3Interface(priceFeedAddress);
        _fnUpdateJS = fnUpdateJS;
        _fnSubscriptionId = fnSubscriptionId;
        _fnDonId = fnDonId;
        _encryptedSecretsUrls = encryptedSecretsUrls;
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

    function createRequest(
        uint256 id,
        int256 quantity,
        uint256 amountInEth
    ) internal {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(_fnUpdateJS);
        req.addSecretsReference(_encryptedSecretsUrls);

        string[] memory args = new string[](4);
        args[0] = id.toString();
        args[1] = quantity.toStringSigned();
        args[2] = Strings.toHexString(uint160(msg.sender), 20);
        args[3] = _requestCounter.toString();

        _requestCounter++;

        req.setArgs(args);

        bytes32 requestId = _sendRequest(
            req.encodeCBOR(),
            _fnSubscriptionId,
            GAS_LIMIT,
            _fnDonId
        );

        _updateRequests[requestId] = UpdateRequest({
            id: id,
            to: msg.sender,
            quantity: quantity,
            amountInEth: amountInEth
        });
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

        createRequest(id, int256(quantity), quoteInEth * quantity);
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

        // That wouldn't work if the price of ETH has increased since the minting
        // and the user wants to withdraw all his investment
        // But it's ok for a demo / PoC
        (uint256 amountInEth, , ) = getQuote(id);
        amountInEth = amountInEth * quantity;

        createRequest(id, -int256(quantity), amountInEth);
    }

    function _fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        UpdateRequest memory updateReq = _updateRequests[requestId];
        if (updateReq.to == address(0) || updateReq.quantity == 0) {
            emit UpdateError(requestId, address(0), "No Update Request");
            return;
        }

        if (updateReq.quantity > 0) {
            if (err.length > 0) {
                // TODO: Refund user if error
                emit UpdateError(requestId, address(0), string(err));
            } else {
                // Minting
                _mint(
                    updateReq.to,
                    updateReq.id,
                    uint256(updateReq.quantity),
                    ""
                );

                availableSupply[updateReq.id] -= uint256(updateReq.quantity);

                emit MintSuccess(
                    updateReq.id,
                    updateReq.to,
                    uint256(updateReq.quantity),
                    string(response)
                );
            }
        } else {
            if (err.length > 0) {
                emit UpdateError(requestId, address(0), string(err));
            } else {
                uint256 quantity = uint256(-updateReq.quantity);
                // Burning
                _burn(updateReq.to, updateReq.id, quantity);

                payable(updateReq.to).transfer(updateReq.amountInEth);

                availableSupply[updateReq.id] += uint256(quantity);

                emit WithdrawSuccess(
                    updateReq.id,
                    updateReq.to,
                    quantity,
                    string(response)
                );
            }
        }

        delete _updateRequests[requestId];
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
