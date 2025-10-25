// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title PetitionNFT
 * @dev Decentralized petition platform with NFT ownership and auto-generated unique IDs
 * @author Kyy
 */
contract PetitionNFT is ERC721, ERC721URIStorage, ERC721Enumerable, Ownable, ReentrancyGuard {
    enum PetitionStatus {
        ACTIVE,
        COMPLETED,
        CANCELLED
    }

    struct PetitionData {
        bytes32 id;
        uint256 tokenId;
        address owner;
        string metadataURI;
        uint256 category;
        string[] tags;
        uint256 startDate;
        uint256 endDate;
        uint256 signatureCount;
        uint256 targetSignatures;
        PetitionStatus status;
        uint256 createdAt;
    }

    struct Signature {
        address signer;
        uint256 timestamp;
        string comment;
    }

    struct PetitionStats {
        uint256 signatureCount;
        PetitionStatus status;
        uint256 progress;
        bool hasEnded;
        bool hasStarted;
        bool canSign;
    }

    // Storage
    mapping(bytes32 => PetitionData) public petitions;
    mapping(bytes32 => mapping(address => bool)) public hasSigned;
    mapping(bytes32 => Signature[]) private signatures;
    mapping(address => bytes32[]) private userSignedPetitions;
    mapping(address => bytes32[]) private userCreatedPetitions;
    bytes32[] private allPetitionIds;
    mapping(uint256 => bytes32[]) private petitionsByCategory;
    mapping(bytes32 => uint256) public petitionToToken;
    mapping(uint256 => bytes32) public tokenToPetition;

    uint256 private _nonce;

    // Events
    event PetitionCreated(
        bytes32 indexed petitionId,
        uint256 indexed tokenId,
        address indexed owner,
        string metadataURI,
        uint256 category,
        uint256 targetSignatures
    );
    event PetitionSigned(bytes32 indexed petitionId, address indexed signer, uint256 signatureCount, string comment);
    event PetitionCompleted(bytes32 indexed petitionId, uint256 finalSignatureCount, string newMetadataURI);
    event PetitionStatusChanged(bytes32 indexed petitionId, PetitionStatus status);
    event SignatureWithdrawn(bytes32 indexed petitionId, address indexed signer, uint256 newSignatureCount);

    constructor() ERC721("PetitionNFT", "PETITION") Ownable(msg.sender) {}

    modifier petitionExists(bytes32 petitionId) {
        require(petitions[petitionId].owner != address(0), "Petition does not exist");
        _;
    }

    modifier petitionIsActive(bytes32 petitionId) {
        PetitionData memory p = petitions[petitionId];
        require(p.status == PetitionStatus.ACTIVE, "Petition not active");
        require(block.timestamp >= p.startDate, "Not started yet");
        require(block.timestamp <= p.endDate, "Already ended");
        _;
    }

    modifier onlyPetitionOwner(bytes32 petitionId) {
        require(petitions[petitionId].owner == msg.sender, "Not petition owner");
        _;
    }

    /// @dev Generate unique tokenId and petitionId using keccak256
    function _generateIds(address creator) internal returns (bytes32 petitionId, uint256 tokenId) {
        _nonce++;
        tokenId = uint256(
            keccak256(
                abi.encodePacked(block.timestamp, block.prevrandao, creator, _nonce)
            )
        );
        petitionId = keccak256(abi.encodePacked(creator, tokenId, _nonce, block.timestamp));
    }

    /// @dev Internal complete petition logic
    function _completePetition(bytes32 petitionId) internal {
        petitions[petitionId].status = PetitionStatus.COMPLETED;
        emit PetitionCompleted(
            petitionId,
            petitions[petitionId].signatureCount,
            petitions[petitionId].metadataURI
        );
    }

    /// @notice Create a new petition NFT with auto-generated IDs
    function createPetition(
        string memory metadataURI,
        uint256 category,
        string[] memory tags,
        uint256 startDate,
        uint256 endDate,
        uint256 targetSignatures
    ) external nonReentrant returns (bytes32 petitionId, uint256 tokenId) {
        require(bytes(metadataURI).length > 0, "Empty metadata URI");
        require(startDate < endDate, "Invalid date range");
        require(endDate > block.timestamp, "End date must be future");
        require(targetSignatures > 0, "Target must be > 0");
        require(tags.length <= 10, "Max 10 tags");

        (petitionId, tokenId) = _generateIds(msg.sender);
        require(petitions[petitionId].owner == address(0), "ID collision");

        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, metadataURI);

        petitions[petitionId] = PetitionData({
            id: petitionId,
            tokenId: tokenId,
            owner: msg.sender,
            metadataURI: metadataURI,
            category: category,
            tags: tags,
            startDate: startDate,
            endDate: endDate,
            signatureCount: 0,
            targetSignatures: targetSignatures,
            status: PetitionStatus.ACTIVE,
            createdAt: block.timestamp
        });

        allPetitionIds.push(petitionId);
        petitionsByCategory[category].push(petitionId);
        petitionToToken[petitionId] = tokenId;
        tokenToPetition[tokenId] = petitionId;
        userCreatedPetitions[msg.sender].push(petitionId);

        emit PetitionCreated(petitionId, tokenId, msg.sender, metadataURI, category, targetSignatures);
    }

    /// @notice Sign a petition
    function signPetition(bytes32 petitionId, string memory comment)
        external
        nonReentrant
        petitionExists(petitionId)
        petitionIsActive(petitionId)
    {
        require(!hasSigned[petitionId][msg.sender], "Already signed");
        require(msg.sender != petitions[petitionId].owner, "Owner cannot sign");
        require(bytes(comment).length <= 500, "Comment too long");

        hasSigned[petitionId][msg.sender] = true;
        petitions[petitionId].signatureCount++;

        signatures[petitionId].push(Signature({signer: msg.sender, timestamp: block.timestamp, comment: comment}));
        userSignedPetitions[msg.sender].push(petitionId);

        emit PetitionSigned(petitionId, msg.sender, petitions[petitionId].signatureCount, comment);

        if (petitions[petitionId].signatureCount >= petitions[petitionId].targetSignatures) {
            _completePetition(petitionId);
        }
    }

    function withdrawSignature(bytes32 petitionId)
        external
        nonReentrant
        petitionExists(petitionId)
        petitionIsActive(petitionId)
    {
        require(hasSigned[petitionId][msg.sender], "Haven't signed");
        hasSigned[petitionId][msg.sender] = false;
        petitions[petitionId].signatureCount--;

        emit SignatureWithdrawn(petitionId, msg.sender, petitions[petitionId].signatureCount);
    }

    function completePetition(bytes32 petitionId, string memory newMetadataURI)
        external
        nonReentrant
        petitionExists(petitionId)
        onlyPetitionOwner(petitionId)
    {
        require(petitions[petitionId].status == PetitionStatus.ACTIVE, "Not active");
        require(bytes(newMetadataURI).length > 0, "Empty metadata URI");

        petitions[petitionId].status = PetitionStatus.COMPLETED;
        petitions[petitionId].metadataURI = newMetadataURI;
        _setTokenURI(petitions[petitionId].tokenId, newMetadataURI);

        emit PetitionCompleted(petitionId, petitions[petitionId].signatureCount, newMetadataURI);
    }

    function cancelPetition(bytes32 petitionId)
        external
        nonReentrant
        petitionExists(petitionId)
        onlyPetitionOwner(petitionId)
    {
        require(petitions[petitionId].status == PetitionStatus.ACTIVE, "Not active");
        petitions[petitionId].status = PetitionStatus.CANCELLED;
        emit PetitionStatusChanged(petitionId, PetitionStatus.CANCELLED);
    }

    // ===== VIEW FUNCTIONS =====

    function getPetition(bytes32 petitionId)
        external
        view
        petitionExists(petitionId)
        returns (PetitionData memory)
    {
        return petitions[petitionId];
    }

    function getAllPetitions() external view returns (PetitionData[] memory result) {
        uint256 total = allPetitionIds.length;
        result = new PetitionData[](total);
        for (uint256 i; i < total; i++) {
            result[i] = petitions[allPetitionIds[i]];
        }
    }

    function getPetitionsByCategory(uint256 category)
        external
        view
        returns (PetitionData[] memory result)
    {
        bytes32[] memory ids = petitionsByCategory[category];
        result = new PetitionData[](ids.length);
        for (uint256 i; i < ids.length; i++) result[i] = petitions[ids[i]];
    }

    function getSignatures(bytes32 petitionId)
        external
        view
        petitionExists(petitionId)
        returns (Signature[] memory)
    {
        return signatures[petitionId];
    }

    function getUserSignedPetitions(address user)
        external
        view
        returns (bytes32[] memory)
    {
        return userSignedPetitions[user];
    }

    function getUserCreatedPetitions(address user)
        external
        view
        returns (bytes32[] memory)
    {
        return userCreatedPetitions[user];
    }

    function getPetitionIdByTokenId(uint256 tokenId)
        external
        view
        returns (bytes32)
    {
        return tokenToPetition[tokenId];
    }

    function getTotalPetitions() external view returns (uint256) {
        return allPetitionIds.length;
    }

    // ===== ERC721 OVERRIDES =====
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
