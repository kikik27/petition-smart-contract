// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title PetitionNFT Simplified
 * @dev Decentralized petition platform with NFT ownership & on-chain metadata
 * @notice Draft mode removed — all petitions are created as PUBLISHED directly
 * @author Kyy
 */
contract PetitionNFT is ERC721, ERC721URIStorage, ERC721Enumerable, Ownable {
    using Strings for uint256;

    uint256 private _tokenIdCounter;

    // Petition states
    enum PetitionState {
        PUBLISHED, // 0 - Live
        COMPLETED, // 1 - Target reached
        CANCELLED  // 2 - Cancelled by owner
    }

    // Petition categories
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
        string currentMetadataURI; // Latest IPFS CID
    }

    struct ProgressUpdate {
        uint256 timestamp;
        address author;
        string updateURI;
        string summary;
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

    // Mappings
    mapping(uint256 => PetitionCore) public petitionCore;
    mapping(uint256 => PetitionDynamic) public petitionDynamic;
    mapping(uint256 => ProgressUpdate[]) public progressUpdates;
    mapping(uint256 => mapping(address => bool)) public hasSigned;
    mapping(uint256 => address[]) private signers;
    mapping(uint256 => mapping(address => Signature)) public signatures;
    mapping(address => UserStats) public userStats;
    mapping(uint256 => string[]) public petitionTags;
    mapping(uint256 => Milestone[]) public milestones;

    // Events
    event PetitionCreated(
        uint256 indexed tokenId,
        address indexed creator,
        Category category,
        string metadataURI,
        uint256 startDate,
        uint256 endDate,
        uint256 targetSignatures
    );

    event ProgressUpdateAdded(
        uint256 indexed tokenId,
        address indexed author,
        string updateURI,
        string summary
    );

    event PetitionSigned(
        uint256 indexed tokenId,
        address indexed signer,
        uint256 signatureCount,
        string message
    );

    event PetitionStateChanged(uint256 indexed tokenId, PetitionState newState);
    event MilestoneReached(uint256 indexed tokenId, uint256 targetReached, uint256 timestamp);
    event SignatureWithdrawn(uint256 indexed tokenId, address indexed signer, uint256 newSignatureCount);
    event EndDateExtended(uint256 indexed tokenId, uint256 oldEndDate, uint256 newEndDate);

    // Modifiers
    modifier onlyTokenOwner(uint256 tokenId) {
        require(ownerOf(tokenId) == msg.sender, "Not token owner");
        _;
    }

    modifier petitionExists(uint256 tokenId) {
        require(_ownerOf(tokenId) != address(0), "Petition does not exist");
        _;
    }

    modifier onlyPublished(uint256 tokenId) {
        require(petitionCore[tokenId].state == PetitionState.PUBLISHED, "Not published");
        _;
    }

    modifier canSign(uint256 tokenId) {
        PetitionCore memory core = petitionCore[tokenId];
        require(core.state == PetitionState.PUBLISHED, "Not published");
        require(block.timestamp >= core.startDate, "Not started");
        require(block.timestamp <= core.endDate, "Has ended");
        _;
    }

    constructor() ERC721("PetitionNFT", "PETITION") Ownable(msg.sender) {}

    // ========= CREATE PETITION (DIRECTLY PUBLISHED) =========

    function createPetition(
        string memory metadataURI,
        Category category,
        string[] memory tags,
        uint256 startDate,
        uint256 endDate,
        uint256 targetSignatures
    ) external returns (uint256) {
        require(bytes(metadataURI).length > 0, "Metadata URI required");
        require(tags.length <= 10, "Max 10 tags");
        require(startDate < endDate, "Invalid date range");
        require(endDate > block.timestamp, "End date must be future");
        require(targetSignatures > 0, "Target must be > 0");

        uint256 tokenId = _tokenIdCounter++;
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

        userStats[msg.sender].petitionsCreated++;
        userStats[msg.sender].reputationScore += 10;

        emit PetitionCreated(tokenId, msg.sender, category, metadataURI, startDate, endDate, targetSignatures);
        return tokenId;
    }

    // ========= PROGRESS UPDATES =========
    function addProgressUpdate(
        uint256 tokenId,
        string memory updateURI,
        string memory summary
    ) external petitionExists(tokenId) onlyTokenOwner(tokenId) onlyPublished(tokenId) {
        require(bytes(updateURI).length > 0, "Update URI required");
        require(bytes(summary).length > 0 && bytes(summary).length <= 280, "Summary length invalid");

        progressUpdates[tokenId].push(
            ProgressUpdate({
                timestamp: block.timestamp,
                author: msg.sender,
                updateURI: updateURI,
                summary: summary
            })
        );

        emit ProgressUpdateAdded(tokenId, msg.sender, updateURI, summary);
    }

    // ========= SIGNATURES =========
    function signPetition(uint256 tokenId, string memory message)
        external
        petitionExists(tokenId)
        canSign(tokenId)
    {
        require(!hasSigned[tokenId][msg.sender], "Already signed");

        hasSigned[tokenId][msg.sender] = true;
        signers[tokenId].push(msg.sender);

        signatures[tokenId][msg.sender] = Signature({
            signer: msg.sender,
            timestamp: block.timestamp,
            message: message
        });

        petitionDynamic[tokenId].signatureCount++;
        userStats[msg.sender].petitionsSigned++;
        userStats[msg.sender].reputationScore += 1;

        uint256 currentCount = petitionDynamic[tokenId].signatureCount;
        emit PetitionSigned(tokenId, msg.sender, currentCount, message);
        _checkMilestone(tokenId, currentCount);

        if (currentCount >= petitionCore[tokenId].targetSignatures) {
            petitionCore[tokenId].state = PetitionState.COMPLETED;
            userStats[petitionCore[tokenId].creator].reputationScore += 100;
            emit PetitionStateChanged(tokenId, PetitionState.COMPLETED);
        }
    }

    function withdrawSignature(uint256 tokenId)
        external
        petitionExists(tokenId)
        onlyPublished(tokenId)
    {
        require(hasSigned[tokenId][msg.sender], "Not signed");

        Signature memory sig = signatures[tokenId][msg.sender];
        require(block.timestamp <= sig.timestamp + 24 hours, "Expired");

        hasSigned[tokenId][msg.sender] = false;
        petitionDynamic[tokenId].signatureCount--;

        address[] storage signerList = signers[tokenId];
        for (uint256 i = 0; i < signerList.length; i++) {
            if (signerList[i] == msg.sender) {
                signerList[i] = signerList[signerList.length - 1];
                signerList.pop();
                break;
            }
        }

        delete signatures[tokenId][msg.sender];
        if (userStats[msg.sender].petitionsSigned > 0) {
            userStats[msg.sender].petitionsSigned--;
        }

        emit SignatureWithdrawn(tokenId, msg.sender, petitionDynamic[tokenId].signatureCount);
    }

    // ========= PETITION MANAGEMENT =========
    function extendPetition(uint256 tokenId, uint256 newEndDate)
        external
        petitionExists(tokenId)
        onlyTokenOwner(tokenId)
        onlyPublished(tokenId)
    {
        uint256 oldEndDate = petitionCore[tokenId].endDate;
        require(newEndDate > oldEndDate, "Must extend");
        require(newEndDate > block.timestamp, "Invalid date");

        petitionCore[tokenId].endDate = newEndDate;
        petitionDynamic[tokenId].lastUpdated = block.timestamp;
        emit EndDateExtended(tokenId, oldEndDate, newEndDate);
    }

    function cancelPetition(uint256 tokenId)
        external
        petitionExists(tokenId)
        onlyTokenOwner(tokenId)
        onlyPublished(tokenId)
    {
        petitionCore[tokenId].state = PetitionState.CANCELLED;
        emit PetitionStateChanged(tokenId, PetitionState.CANCELLED);
    }

    // ========= INTERNAL HELPERS =========
    function _checkMilestone(uint256 tokenId, uint256 currentCount) internal {
        uint256 target = petitionCore[tokenId].targetSignatures;
        uint256[4] memory thresholds = [
            target / 4, target / 2, (target * 3) / 4, target
        ];

        for (uint256 i = 0; i < 4; i++) {
            if (currentCount >= thresholds[i] && currentCount - 1 < thresholds[i]) {
                milestones[tokenId].push(Milestone({
                    targetReached: thresholds[i],
                    timestamp: block.timestamp,
                    achievementURI: ""
                }));
                emit MilestoneReached(tokenId, thresholds[i], block.timestamp);
                break;
            }
        }
    }

    // ========= OVERRIDES =========
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
