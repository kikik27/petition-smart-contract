// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title PetitionNFT UUID Edition (Clean)
 * @dev Petition platform using unique UUID-like tokenIds (non-sequential)
 * @notice Each petition = NFT with metadata stored on IPFS
 * @author Kyy
 */
contract PetitionNFT is ERC721URIStorage, Ownable {
    constructor() ERC721("PetitionNFT", "PETITION") Ownable(msg.sender) {}

    // ================= ENUMS =================
    enum PetitionState {
        PUBLISHED,
        COMPLETED,
        CANCELLED
    }

    enum Category {
        SOCIAL,
        POLITICAL,
        ENVIRONMENTAL,
        EDUCATION,
        HEALTH,
        HUMAN_RIGHTS,
        ANIMAL_RIGHTS,
        ECONOMIC,
        TECHNOLOGY,
        OTHER
    }

    // ================= STRUCTS =================
    struct PetitionCore {
        uint256 tokenId;
        address creator;
        Category category;
        PetitionState state;
        uint256 createdAt;
        uint256 startDate;
        uint256 endDate;
        uint256 targetSignatures;
    }

    struct PetitionDynamic {
        uint256 signatureCount;
        uint256 lastUpdated;
        string currentMetadataURI;
    }

    struct Signature {
        address signer;
        uint256 timestamp;
        string message;
    }

    struct UserStats {
        uint256 petitionsCreated;
        uint256 petitionsSigned;
        uint256 reputationScore;
    }

    struct Milestone {
        uint256 targetReached;
        uint256 timestamp;
        string achievementURI;
    }

    // ================= STORAGE =================
    mapping(uint256 => PetitionCore) public petitionCore;
    mapping(uint256 => PetitionDynamic) public petitionDynamic;
    mapping(uint256 => mapping(address => bool)) public hasSigned;
    mapping(uint256 => address[]) private signers;
    mapping(uint256 => mapping(address => Signature)) public signatures;
    mapping(address => UserStats) public userStats;
    mapping(address => uint256[]) private _petitionsByCreator;
    uint256[] private _allTokens;
    mapping(uint256 => Milestone[]) public milestones;
    mapping(uint256 => string[]) public petitionTags;

    // ================= EVENTS =================
    event PetitionCreated(
        uint256 indexed tokenId,
        address indexed creator,
        string metadataURI,
        uint256 startDate,
        uint256 endDate,
        uint256 targetSignatures
    );

    event PetitionSigned(
        uint256 indexed tokenId,
        address indexed signer,
        uint256 signatureCount,
        string message
    );

    event PetitionStateChanged(uint256 indexed tokenId, PetitionState newState);

    // ================= MODIFIERS =================
    modifier petitionExists(uint256 tokenId) {
        require(_ownerOf(tokenId) != address(0), "Petition does not exist");
        _;
    }

    modifier onlyTokenOwner(uint256 tokenId) {
        require(ownerOf(tokenId) == msg.sender, "Not token owner");
        _;
    }

    modifier canSign(uint256 tokenId) {
        PetitionCore memory core = petitionCore[tokenId];
        require(core.state == PetitionState.PUBLISHED, "Not published");
        require(block.timestamp >= core.startDate, "Not started");
        require(block.timestamp <= core.endDate, "Ended");
        _;
    }

    // ================= UUID GENERATOR =================
    function _generateTokenId(address creator) internal view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(block.timestamp, creator, block.prevrandao)
                )
            );
    }

    // ================= CREATE PETITION =================
    function createPetition(
        string memory metadataURI,
        Category category,
        string[] memory tags,
        uint256 startDate,
        uint256 endDate,
        uint256 targetSignatures
    ) external returns (uint256) {
        require(bytes(metadataURI).length > 0, "metadata required");
        require(startDate < endDate, "invalid date range");
        require(targetSignatures > 0, "target required");

        uint256 tokenId = _generateTokenId(msg.sender);
        require(_ownerOf(tokenId) == address(0), "collision");

        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, metadataURI);

        petitionCore[tokenId] = PetitionCore({
            tokenId: tokenId,
            creator: msg.sender,
            category: category,
            state: PetitionState.PUBLISHED,
            createdAt: block.timestamp,
            startDate: startDate,
            endDate: endDate,
            targetSignatures: targetSignatures
        });

        petitionDynamic[tokenId] = PetitionDynamic({
            signatureCount: 0,
            lastUpdated: block.timestamp,
            currentMetadataURI: metadataURI
        });

        for (uint256 i = 0; i < tags.length; i++) {
            petitionTags[tokenId].push(tags[i]);
        }

        _petitionsByCreator[msg.sender].push(tokenId);
        _allTokens.push(tokenId);

        userStats[msg.sender].petitionsCreated++;
        userStats[msg.sender].reputationScore += 10;

        emit PetitionCreated(
            tokenId,
            msg.sender,
            metadataURI,
            startDate,
            endDate,
            targetSignatures
        );

        return tokenId;
    }

    // ================= SIGN PETITION =================
    function signPetition(
        uint256 tokenId,
        string memory message
    ) external petitionExists(tokenId) canSign(tokenId) {
        require(!hasSigned[tokenId][msg.sender], "already signed");

        hasSigned[tokenId][msg.sender] = true;
        signers[tokenId].push(msg.sender);
        signatures[tokenId][msg.sender] = Signature(
            msg.sender,
            block.timestamp,
            message
        );

        petitionDynamic[tokenId].signatureCount++;
        userStats[msg.sender].petitionsSigned++;
        userStats[msg.sender].reputationScore += 1;

        emit PetitionSigned(
            tokenId,
            msg.sender,
            petitionDynamic[tokenId].signatureCount,
            message
        );

        if (
            petitionDynamic[tokenId].signatureCount >=
            petitionCore[tokenId].targetSignatures
        ) {
            petitionCore[tokenId].state = PetitionState.COMPLETED;
            userStats[petitionCore[tokenId].creator].reputationScore += 100;
            emit PetitionStateChanged(tokenId, PetitionState.COMPLETED);
        }
    }

    // ================= CANCEL PETITION =================
    function cancelPetition(
        uint256 tokenId
    ) external petitionExists(tokenId) onlyTokenOwner(tokenId) {
        petitionCore[tokenId].state = PetitionState.CANCELLED;
        emit PetitionStateChanged(tokenId, PetitionState.CANCELLED);
    }

    // ================= VIEW FUNCTIONS =================
    function getAllPetitionIds() external view returns (uint256[] memory) {
        return _allTokens;
    }

    function getPetitionsByCreator(
        address creator
    ) external view returns (uint256[] memory) {
        return _petitionsByCreator[creator];
    }

    function getPetition(
        uint256 tokenId
    )
        external
        view
        petitionExists(tokenId)
        returns (PetitionCore memory, PetitionDynamic memory)
    {
        return (petitionCore[tokenId], petitionDynamic[tokenId]);
    }

    function getSignatures(
        uint256 tokenId
    ) external view returns (Signature[] memory) {
        address[] memory signerList = signers[tokenId];
        Signature[] memory sigList = new Signature[](signerList.length);

        for (uint256 i = 0; i < signerList.length; i++) {
            sigList[i] = signatures[tokenId][signerList[i]];
        }

        return sigList;
    }

    // ================= OVERRIDES =================
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
