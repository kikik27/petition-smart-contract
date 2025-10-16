// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
// REMOVED: import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title PetitionNFT V2
 * @dev Decentralized petition platform with NFT ownership, IPFS storage, and Draft/Published states
 * @notice Each petition is an NFT. Drafts are editable, Published petitions are immutable
 * @author Kyy's
 */
contract PetitionNFT is ERC721, ERC721URIStorage, ERC721Enumerable, Ownable {
    // REMOVED: using Counters for Counters.Counter;
    using Strings for uint256;

    // ========== STATE VARIABLES ==========

    uint256 private _tokenIdCounter; // NEW: Simple uint256 counter (OpenZeppelin v5 compatible)

    // Petition states
    enum PetitionState {
        DRAFT, // 0 - Editable, not live
        PUBLISHED, // 1 - Live, immutable
        COMPLETED, // 2 - Ended successfully
        CANCELLED // 3 - Cancelled by owner
    }

    // Petition categories
    enum Category {
        SOCIAL, // 0
        POLITICAL, // 1
        ENVIRONMENTAL, // 2
        EDUCATION, // 3
        HEALTH, // 4
        HUMAN_RIGHTS, // 5
        ANIMAL_RIGHTS, // 6
        ECONOMIC, // 7
        TECHNOLOGY, // 8
        OTHER // 9
    }

    // Core petition data (on-chain)
    struct PetitionCore {
        uint256 tokenId;
        address creator;
        Category category;
        PetitionState state;
        uint256 createdAt;
        uint256 publishedAt; // 0 if still draft
        uint256 startDate;
        uint256 endDate;
        uint256 targetSignatures;
    }

    // Dynamic petition data (on-chain)
    struct PetitionDynamic {
        uint256 signatureCount;
        uint256 lastUpdated;
        string currentMetadataURI; // Latest IPFS CID
    }

    // Draft edit log (only for drafts)
    struct DraftEdit {
        uint256 timestamp;
        string metadataURI;
        string editNote;
    }

    // Progress update (for published petitions)
    struct ProgressUpdate {
        uint256 timestamp;
        address author;
        string updateURI; // IPFS CID of update content
        string summary;
    }

    // Signature record
    struct Signature {
        address signer;
        uint256 timestamp;
        string message; // Optional support message (IPFS CID if long)
    }

    // User stats
    struct UserStats {
        uint256 petitionsCreated;
        uint256 petitionsSigned;
        uint256 reputationScore;
    }

    // Milestone achievement
    struct Milestone {
        uint256 targetReached;
        uint256 timestamp;
        string achievementURI;
    }

    // ========== MAPPINGS ==========

    mapping(uint256 => PetitionCore) public petitionCore;
    mapping(uint256 => PetitionDynamic) public petitionDynamic;
    mapping(uint256 => DraftEdit[]) public draftEditHistory;
    mapping(uint256 => ProgressUpdate[]) public progressUpdates;
    mapping(uint256 => mapping(address => bool)) public hasSigned;
    mapping(uint256 => address[]) private signers;
    mapping(uint256 => mapping(address => Signature)) public signatures;
    mapping(address => UserStats) public userStats;
    mapping(uint256 => string[]) public petitionTags;
    mapping(uint256 => Milestone[]) public milestones;

    // ========== EVENTS ==========

    event PetitionDraftCreated(
        uint256 indexed tokenId,
        address indexed creator,
        Category category,
        string metadataURI
    );

    event PetitionPublished(
        uint256 indexed tokenId,
        address indexed creator,
        string metadataURI,
        uint256 startDate,
        uint256 endDate,
        uint256 targetSignatures
    );

    event DraftUpdated(
        uint256 indexed tokenId,
        string newMetadataURI,
        string editNote
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

    event MilestoneReached(
        uint256 indexed tokenId,
        uint256 targetReached,
        uint256 timestamp
    );

    event SignatureWithdrawn(
        uint256 indexed tokenId,
        address indexed signer,
        uint256 newSignatureCount
    );

    event EndDateExtended(
        uint256 indexed tokenId,
        uint256 oldEndDate,
        uint256 newEndDate
    );

    // ========== MODIFIERS ==========

    modifier onlyTokenOwner(uint256 tokenId) {
        require(ownerOf(tokenId) == msg.sender, "Not token owner");
        _;
    }

    modifier petitionExists(uint256 tokenId) {
        require(_ownerOf(tokenId) != address(0), "Petition does not exist"); // CHANGED: _exists() to _ownerOf()
        _;
    }

    modifier onlyDraft(uint256 tokenId) {
        require(
            petitionCore[tokenId].state == PetitionState.DRAFT,
            "Not in draft state"
        );
        _;
    }

    modifier onlyPublished(uint256 tokenId) {
        require(
            petitionCore[tokenId].state == PetitionState.PUBLISHED,
            "Not published"
        );
        _;
    }

    modifier canSign(uint256 tokenId) {
        require(
            petitionCore[tokenId].state == PetitionState.PUBLISHED,
            "Not published"
        );
        require(
            block.timestamp >= petitionCore[tokenId].startDate,
            "Not started"
        );
        require(block.timestamp <= petitionCore[tokenId].endDate, "Has ended");
        _;
    }

    // ========== CONSTRUCTOR ==========

    constructor() ERC721("PetitionNFT", "PETITION") Ownable(msg.sender) {} // UPDATED: Added Ownable(msg.sender) for v5

    // ========== DRAFT FUNCTIONS ==========

    /**
     * @dev Create a new petition as DRAFT
     * @param metadataURI IPFS CID of petition metadata
     * @param category Petition category
     * @param tags Array of tags
     * @return tokenId The ID of the created draft
     */
    function createDraft(
        string memory metadataURI,
        Category category,
        string[] memory tags
    ) external returns (uint256) {
        require(bytes(metadataURI).length > 0, "Metadata URI required");
        require(tags.length <= 10, "Max 10 tags");

        uint256 tokenId = _tokenIdCounter; // CHANGED: from _tokenIdCounter.current()
        _tokenIdCounter++; // CHANGED: from _tokenIdCounter.increment()

        // Mint NFT to creator
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, metadataURI);

        // Store core data (in DRAFT state)
        petitionCore[tokenId] = PetitionCore({
            tokenId: tokenId,
            creator: msg.sender,
            category: category,
            state: PetitionState.DRAFT,
            createdAt: block.timestamp,
            publishedAt: 0,
            startDate: 0,
            endDate: 0,
            targetSignatures: 0
        });

        // Store dynamic data
        petitionDynamic[tokenId] = PetitionDynamic({
            signatureCount: 0,
            lastUpdated: block.timestamp,
            currentMetadataURI: metadataURI
        });

        // Store initial edit
        draftEditHistory[tokenId].push(
            DraftEdit({
                timestamp: block.timestamp,
                metadataURI: metadataURI,
                editNote: "Initial draft creation"
            })
        );

        // Store tags
        for (uint256 i = 0; i < tags.length; i++) {
            petitionTags[tokenId].push(tags[i]);
        }

        // Update user stats
        userStats[msg.sender].petitionsCreated++;

        emit PetitionDraftCreated(tokenId, msg.sender, category, metadataURI);

        return tokenId;
    }

    /**
     * @dev Update draft petition (only allowed in DRAFT state)
     * @param tokenId ID of the petition
     * @param newMetadataURI New IPFS CID
     * @param editNote Description of changes
     */
    function updateDraft(
        uint256 tokenId,
        string memory newMetadataURI,
        string memory editNote
    )
        external
        petitionExists(tokenId)
        onlyTokenOwner(tokenId)
        onlyDraft(tokenId)
    {
        require(bytes(newMetadataURI).length > 0, "Metadata URI required");

        // Update token URI
        _setTokenURI(tokenId, newMetadataURI);

        // Update dynamic data
        petitionDynamic[tokenId].currentMetadataURI = newMetadataURI;
        petitionDynamic[tokenId].lastUpdated = block.timestamp;

        // Add to edit history
        draftEditHistory[tokenId].push(
            DraftEdit({
                timestamp: block.timestamp,
                metadataURI: newMetadataURI,
                editNote: editNote
            })
        );

        emit DraftUpdated(tokenId, newMetadataURI, editNote);
    }

    /**
     * @dev Update draft tags (only in DRAFT state)
     * @param tokenId ID of the petition
     * @param tags New tags array
     */
    function updateDraftTags(
        uint256 tokenId,
        string[] memory tags
    )
        external
        petitionExists(tokenId)
        onlyTokenOwner(tokenId)
        onlyDraft(tokenId)
    {
        require(tags.length <= 10, "Max 10 tags");

        // Clear old tags
        delete petitionTags[tokenId];

        // Set new tags
        for (uint256 i = 0; i < tags.length; i++) {
            petitionTags[tokenId].push(tags[i]);
        }
    }

    /**
     * @dev Delete draft (only in DRAFT state, cannot delete published)
     * @param tokenId ID of the petition
     */
    function deleteDraft(
        uint256 tokenId
    )
        external
        petitionExists(tokenId)
        onlyTokenOwner(tokenId)
        onlyDraft(tokenId)
    {
        // Burn the NFT
        _burn(tokenId);

        // Clean up data
        delete petitionCore[tokenId];
        delete petitionDynamic[tokenId];
        delete draftEditHistory[tokenId];
        delete petitionTags[tokenId];

        // Update stats
        if (userStats[msg.sender].petitionsCreated > 0) {
            userStats[msg.sender].petitionsCreated--;
        }
    }

    // ========== PUBLISH FUNCTIONS ==========

    /**
     * @dev Publish draft petition (makes it IMMUTABLE and live)
     * @param tokenId ID of the petition
     * @param startDate Unix timestamp for start
     * @param endDate Unix timestamp for end
     * @param targetSignatures Target number of signatures
     */
    function publishPetition(
        uint256 tokenId,
        uint256 startDate,
        uint256 endDate,
        uint256 targetSignatures
    )
        external
        petitionExists(tokenId)
        onlyTokenOwner(tokenId)
        onlyDraft(tokenId)
    {
        require(startDate < endDate, "Invalid date range");
        require(endDate > block.timestamp, "End date must be future");
        require(targetSignatures > 0, "Target must be > 0");

        // Update to PUBLISHED state (IRREVERSIBLE!)
        petitionCore[tokenId].state = PetitionState.PUBLISHED;
        petitionCore[tokenId].publishedAt = block.timestamp;
        petitionCore[tokenId].startDate = startDate;
        petitionCore[tokenId].endDate = endDate;
        petitionCore[tokenId].targetSignatures = targetSignatures;

        // Add reputation bonus
        userStats[msg.sender].reputationScore += 10;

        emit PetitionPublished(
            tokenId,
            msg.sender,
            petitionDynamic[tokenId].currentMetadataURI,
            startDate,
            endDate,
            targetSignatures
        );

        emit PetitionStateChanged(tokenId, PetitionState.PUBLISHED);
    }

    // ========== PUBLISHED PETITION FUNCTIONS ==========

    /**
     * @dev Add progress update to published petition (does NOT change original content)
     * @param tokenId ID of the petition
     * @param updateURI IPFS CID of the update content
     * @param summary Short summary of the update
     */
    function addProgressUpdate(
        uint256 tokenId,
        string memory updateURI,
        string memory summary
    )
        external
        petitionExists(tokenId)
        onlyTokenOwner(tokenId)
        onlyPublished(tokenId)
    {
        require(bytes(updateURI).length > 0, "Update URI required");
        require(
            bytes(summary).length > 0 && bytes(summary).length <= 280,
            "Summary: 1-280 chars"
        );

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

    /**
     * @dev Sign a petition
     * @param tokenId ID of the petition
     * @param supportMessage Optional message (can be IPFS CID if long)
     */
    function signPetition(
        uint256 tokenId,
        string memory supportMessage
    ) external petitionExists(tokenId) canSign(tokenId) {
        require(!hasSigned[tokenId][msg.sender], "Already signed");

        hasSigned[tokenId][msg.sender] = true;
        signers[tokenId].push(msg.sender);

        signatures[tokenId][msg.sender] = Signature({
            signer: msg.sender,
            timestamp: block.timestamp,
            message: supportMessage
        });

        petitionDynamic[tokenId].signatureCount++;

        // Update user stats
        userStats[msg.sender].petitionsSigned++;
        userStats[msg.sender].reputationScore += 1;

        uint256 currentCount = petitionDynamic[tokenId].signatureCount;

        emit PetitionSigned(tokenId, msg.sender, currentCount, supportMessage);

        // Check milestone achievements
        _checkMilestone(tokenId, currentCount);

        // Auto-complete if target reached
        if (currentCount >= petitionCore[tokenId].targetSignatures) {
            petitionCore[tokenId].state = PetitionState.COMPLETED;
            userStats[petitionCore[tokenId].creator].reputationScore += 100;
            emit PetitionStateChanged(tokenId, PetitionState.COMPLETED);
        }
    }

    /**
     * @dev Withdraw signature (within 24 hours)
     * @param tokenId ID of the petition
     */
    function withdrawSignature(
        uint256 tokenId
    ) external petitionExists(tokenId) onlyPublished(tokenId) {
        require(hasSigned[tokenId][msg.sender], "Haven't signed");

        Signature memory sig = signatures[tokenId][msg.sender];
        require(
            block.timestamp <= sig.timestamp + 24 hours,
            "Withdrawal period expired"
        );

        hasSigned[tokenId][msg.sender] = false;
        petitionDynamic[tokenId].signatureCount--;

        // Remove from signers array
        address[] storage signerList = signers[tokenId];
        for (uint256 i = 0; i < signerList.length; i++) {
            if (signerList[i] == msg.sender) {
                signerList[i] = signerList[signerList.length - 1];
                signerList.pop();
                break;
            }
        }

        delete signatures[tokenId][msg.sender];

        // Update stats
        if (userStats[msg.sender].petitionsSigned > 0) {
            userStats[msg.sender].petitionsSigned--;
        }

        emit SignatureWithdrawn(
            tokenId,
            msg.sender,
            petitionDynamic[tokenId].signatureCount
        );
    }

    /**
     * @dev Extend petition end date (only extend, not shorten)
     * @param tokenId ID of the petition
     * @param newEndDate New end date
     */
    function extendPetition(
        uint256 tokenId,
        uint256 newEndDate
    )
        external
        petitionExists(tokenId)
        onlyTokenOwner(tokenId)
        onlyPublished(tokenId)
    {
        uint256 oldEndDate = petitionCore[tokenId].endDate;
        require(newEndDate > oldEndDate, "Can only extend, not shorten");
        require(newEndDate > block.timestamp, "Must be future date");

        petitionCore[tokenId].endDate = newEndDate;
        petitionDynamic[tokenId].lastUpdated = block.timestamp;

        emit EndDateExtended(tokenId, oldEndDate, newEndDate);
    }

    /**
     * @dev Cancel petition (owner can cancel anytime)
     * @param tokenId ID of the petition
     */
    function cancelPetition(
        uint256 tokenId
    )
        external
        petitionExists(tokenId)
        onlyTokenOwner(tokenId)
        onlyPublished(tokenId)
    {
        petitionCore[tokenId].state = PetitionState.CANCELLED;
        emit PetitionStateChanged(tokenId, PetitionState.CANCELLED);
    }

    // ========== VIEW FUNCTIONS ==========

    /**
     * @dev Get complete petition data
     */
    function getPetition(
        uint256 tokenId
    )
        external
        view
        petitionExists(tokenId)
        returns (
            PetitionCore memory core,
            PetitionDynamic memory dynamic,
            string[] memory tags,
            bool isDraft
        )
    {
        return (
            petitionCore[tokenId],
            petitionDynamic[tokenId],
            petitionTags[tokenId],
            petitionCore[tokenId].state == PetitionState.DRAFT
        );
    }

    /**
     * @dev Get draft edit history
     */
    function getDraftEditHistory(
        uint256 tokenId
    ) external view petitionExists(tokenId) returns (DraftEdit[] memory) {
        return draftEditHistory[tokenId];
    }

    /**
     * @dev Get progress updates
     */
    function getProgressUpdates(
        uint256 tokenId
    ) external view petitionExists(tokenId) returns (ProgressUpdate[] memory) {
        return progressUpdates[tokenId];
    }

    /**
     * @dev Get all signers
     */
    function getSigners(
        uint256 tokenId
    ) external view petitionExists(tokenId) returns (address[] memory) {
        return signers[tokenId];
    }

    /**
     * @dev Get petition tags
     */
    function getTags(
        uint256 tokenId
    ) external view petitionExists(tokenId) returns (string[] memory) {
        return petitionTags[tokenId];
    }

    /**
     * @dev Get user statistics
     */
    function getUserStats(
        address user
    ) external view returns (UserStats memory) {
        return userStats[user];
    }

    /**
     * @dev Get milestones achieved
     */
    function getMilestones(
        uint256 tokenId
    ) external view petitionExists(tokenId) returns (Milestone[] memory) {
        return milestones[tokenId];
    }

    /**
     * @dev Get petition statistics
     */
    function getPetitionStats(
        uint256 tokenId
    )
        external
        view
        petitionExists(tokenId)
        returns (
            PetitionState state,
            uint256 signatureCount,
            uint256 targetSignatures,
            uint256 progressPercentage,
            bool hasStarted,
            bool hasEnded,
            bool isSignable
        )
    {
        PetitionCore memory core = petitionCore[tokenId];
        PetitionDynamic memory dynamic = petitionDynamic[tokenId];

        uint256 progress = 0;
        if (core.targetSignatures > 0) {
            progress = (dynamic.signatureCount * 100) / core.targetSignatures;
            if (progress > 100) progress = 100;
        }

        bool started = block.timestamp >= core.startDate;
        bool ended = block.timestamp > core.endDate;
        bool isSignableLocal = core.state == PetitionState.PUBLISHED &&
            started &&
            !ended;

        return (
            core.state,
            dynamic.signatureCount,
            core.targetSignatures,
            progress,
            started,
            ended,
            isSignableLocal
        );
    }

    /**
     * @dev Get all drafts by creator
     */
    function getDraftsByCreator(
        address creator
    ) external view returns (uint256[] memory) {
        uint256 balance = balanceOf(creator);
        uint256[] memory temp = new uint256[](balance);
        uint256 count = 0;

        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = tokenOfOwnerByIndex(creator, i);
            if (petitionCore[tokenId].state == PetitionState.DRAFT) {
                temp[count] = tokenId;
                count++;
            }
        }

        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = temp[i];
        }

        return result;
    }

    /**
     * @dev Get published petitions by state
     */
    function getPetitionsByState(
        PetitionState state
    ) external view returns (uint256[] memory) {
        uint256 total = _tokenIdCounter; // CHANGED: from _tokenIdCounter.current()
        uint256[] memory temp = new uint256[](total);
        uint256 count = 0;

        for (uint256 i = 0; i < total; i++) {
            if (_ownerOf(i) != address(0) && petitionCore[i].state == state) {
                // CHANGED: _exists() to _ownerOf() != address(0)
                temp[count] = i;
                count++;
            }
        }

        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = temp[i];
        }

        return result;
    }

    /**
     * @dev Get active petitions (published, started, not ended)
     */
    function getActivePetitions() external view returns (uint256[] memory) {
        uint256 total = _tokenIdCounter; // CHANGED
        uint256[] memory temp = new uint256[](total);
        uint256 count = 0;

        for (uint256 i = 0; i < total; i++) {
            if (
                _ownerOf(i) != address(0) && // CHANGED
                petitionCore[i].state == PetitionState.PUBLISHED &&
                block.timestamp >= petitionCore[i].startDate &&
                block.timestamp <= petitionCore[i].endDate
            ) {
                temp[count] = i;
                count++;
            }
        }

        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = temp[i];
        }

        return result;
    }

    /**
     * @dev Get petitions by category
     */
    function getPetitionsByCategory(
        Category category
    ) external view returns (uint256[] memory) {
        uint256 total = _tokenIdCounter; // CHANGED
        uint256[] memory temp = new uint256[](total);
        uint256 count = 0;

        for (uint256 i = 0; i < total; i++) {
            if (
                _ownerOf(i) != address(0) &&
                petitionCore[i].category == category
            ) {
                // CHANGED
                temp[count] = i;
                count++;
            }
        }

        uint256[] memory result = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = temp[i];
        }

        return result;
    }

    // ========== INTERNAL HELPER FUNCTIONS ==========

    /**
     * @dev Check and record milestone achievements
     */
    function _checkMilestone(uint256 tokenId, uint256 currentCount) internal {
        uint256 target = petitionCore[tokenId].targetSignatures;

        // Check for 25%, 50%, 75%, 100% milestones
        uint256[] memory thresholds = new uint256[](4);
        thresholds[0] = target / 4; // 25%
        thresholds[1] = target / 2; // 50%
        thresholds[2] = (target * 3) / 4; // 75%
        thresholds[3] = target; // 100%

        for (uint256 i = 0; i < thresholds.length; i++) {
            if (
                currentCount >= thresholds[i] &&
                currentCount - 1 < thresholds[i]
            ) {
                milestones[tokenId].push(
                    Milestone({
                        targetReached: thresholds[i],
                        timestamp: block.timestamp,
                        achievementURI: ""
                    })
                );

                emit MilestoneReached(tokenId, thresholds[i], block.timestamp);
                break;
            }
        }
    }

    // ========== REQUIRED OVERRIDES FOR OPENZEPPELIN V5 ==========

    /**
     * @dev Override _update for v5 compatibility
     */
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override(ERC721, ERC721Enumerable) returns (address) {
        return super._update(to, tokenId, auth);
    }

    /**
     * @dev Override _increaseBalance for v5 compatibility
     */
    function _increaseBalance(
        address account,
        uint128 value
    ) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }

    /**
     * @dev Override tokenURI
     */
    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    /**
     * @dev Override supportsInterface
     */
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721, ERC721URIStorage, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
