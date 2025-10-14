// SPDX-License-Identifier: MIT

// Solidity files have to start with this pragma.
// It will be used by the Solidity compiler to validate its version.
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

interface ITokenAsset is IERC1155 {
    function adminSafeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        uint256 quantity
    ) external;

    function adminWithdraw(uint256 amount) external;

    function setContractURI(string calldata newContractURI) external;

    function deploy(
        uint256 quantity,
        uint256 _usdPricePerShare,
        string calldata newUri
    ) external returns (uint256);

    function getQuote(
        uint256 id
    ) external view returns (uint256, uint80, uint256);

    function mint(
        uint256 id,
        uint256 quantity,
        uint80 roundId
    ) external payable;

    function withdraw(uint256 id, uint256 quantity) external;
}
