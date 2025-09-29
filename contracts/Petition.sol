// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title Petition
 * @dev A decentralized petition platform where users can create and sign petitions
 * @author Your Name
 */
contract Petition {
    struct PetitionData {
        uint256 id;
        address owner;
        string title;
        string description;
        string imageUrl;
        uint256 startDate;
        uint256 endDate;
        uint256 signatureCount;
        bool isActive;
        uint256 createdAt;
    }

    struct UpdateLog {
        uint256 timestamp;
        string fieldUpdated;
        string oldValue;
        string newValue;
    }

    uint256 private petitionCounter;
    
    mapping(uint256 => PetitionData) public petitions;
    mapping(uint256 => mapping(address => bool)) public hasSigned;
    mapping(uint256 => address[]) public signers;
    mapping(uint256 => UpdateLog[]) public updateLogs;
    
    event PetitionCreated(
        uint256 indexed petitionId,
        address indexed owner,
        string title,
        uint256 startDate,
        uint256 endDate
    );
    
    event PetitionSigned(
        uint256 indexed petitionId,
        address indexed signer,
        uint256 signatureCount
    );
    
    event PetitionUpdated(
        uint256 indexed petitionId,
        string fieldUpdated,
        uint256 timestamp
    );
    
    event PetitionStatusChanged(
        uint256 indexed petitionId,
        bool isActive
    );

    modifier onlyPetitionOwner(uint256 petitionId) {
        require(petitions[petitionId].owner == msg.sender, "Only petition owner can call this");
        _;
    }

    modifier petitionExists(uint256 petitionId) {
        require(petitions[petitionId].owner != address(0), "Petition does not exist");
        _;
    }

    modifier petitionIsActive(uint256 petitionId) {
        require(petitions[petitionId].isActive, "Petition is not active");
        require(block.timestamp >= petitions[petitionId].startDate, "Petition has not started yet");
        require(block.timestamp <= petitions[petitionId].endDate, "Petition has ended");
        _;
    }

    /**
     * @dev Create a new petition
     * @param title Title of the petition
     * @param description Detailed description of the petition
     * @param imageUrl URL to petition image
     * @param startDate Unix timestamp for petition start
     * @param endDate Unix timestamp for petition end
     * @return petitionId The ID of the created petition
     */
    function createPetition(
        string memory title,
        string memory description,
        string memory imageUrl,
        uint256 startDate,
        uint256 endDate
    ) external returns (uint256) {
        require(bytes(title).length > 0, "Title cannot be empty");
        require(bytes(description).length > 0, "Description cannot be empty");
        require(startDate < endDate, "End date must be after start date");
        require(endDate > block.timestamp, "End date must be in the future");

        uint256 petitionId = petitionCounter++;
        
        petitions[petitionId] = PetitionData({
            id: petitionId,
            owner: msg.sender,
            title: title,
            description: description,
            imageUrl: imageUrl,
            startDate: startDate,
            endDate: endDate,
            signatureCount: 0,
            isActive: true,
            createdAt: block.timestamp
        });

        emit PetitionCreated(petitionId, msg.sender, title, startDate, endDate);
        
        return petitionId;
    }

    /**
     * @dev Sign a petition
     * @param petitionId ID of the petition to sign
     */
    function signPetition(uint256 petitionId) 
        external 
        petitionExists(petitionId) 
        petitionIsActive(petitionId) 
    {
        require(!hasSigned[petitionId][msg.sender], "You have already signed this petition");

        hasSigned[petitionId][msg.sender] = true;
        signers[petitionId].push(msg.sender);
        petitions[petitionId].signatureCount += 1;

        emit PetitionSigned(petitionId, msg.sender, petitions[petitionId].signatureCount);
    }

    /**
     * @dev Update petition title
     * @param petitionId ID of the petition
     * @param newTitle New title
     */
    function updateTitle(uint256 petitionId, string memory newTitle) 
        external 
        petitionExists(petitionId) 
        onlyPetitionOwner(petitionId) 
    {
        require(bytes(newTitle).length > 0, "Title cannot be empty");
        
        string memory oldTitle = petitions[petitionId].title;
        petitions[petitionId].title = newTitle;
        
        updateLogs[petitionId].push(UpdateLog({
            timestamp: block.timestamp,
            fieldUpdated: "title",
            oldValue: oldTitle,
            newValue: newTitle
        }));

        emit PetitionUpdated(petitionId, "title", block.timestamp);
    }

    /**
     * @dev Update petition description
     * @param petitionId ID of the petition
     * @param newDescription New description
     */
    function updateDescription(uint256 petitionId, string memory newDescription) 
        external 
        petitionExists(petitionId) 
        onlyPetitionOwner(petitionId) 
    {
        require(bytes(newDescription).length > 0, "Description cannot be empty");
        
        string memory oldDescription = petitions[petitionId].description;
        petitions[petitionId].description = newDescription;
        
        updateLogs[petitionId].push(UpdateLog({
            timestamp: block.timestamp,
            fieldUpdated: "description",
            oldValue: oldDescription,
            newValue: newDescription
        }));

        emit PetitionUpdated(petitionId, "description", block.timestamp);
    }

    /**
     * @dev Update petition image
     * @param petitionId ID of the petition
     * @param newImageUrl New image URL
     */
    function updateImage(uint256 petitionId, string memory newImageUrl) 
        external 
        petitionExists(petitionId) 
        onlyPetitionOwner(petitionId) 
    {
        string memory oldImageUrl = petitions[petitionId].imageUrl;
        petitions[petitionId].imageUrl = newImageUrl;
        
        updateLogs[petitionId].push(UpdateLog({
            timestamp: block.timestamp,
            fieldUpdated: "imageUrl",
            oldValue: oldImageUrl,
            newValue: newImageUrl
        }));

        emit PetitionUpdated(petitionId, "imageUrl", block.timestamp);
    }

    /**
     * @dev Update petition end date
     * @param petitionId ID of the petition
     * @param newEndDate New end date (unix timestamp)
     */
    function updateEndDate(uint256 petitionId, uint256 newEndDate) 
        external 
        petitionExists(petitionId) 
        onlyPetitionOwner(petitionId) 
    {
        require(newEndDate > block.timestamp, "End date must be in the future");
        require(newEndDate > petitions[petitionId].startDate, "End date must be after start date");
        
        uint256 oldEndDate = petitions[petitionId].endDate;
        petitions[petitionId].endDate = newEndDate;
        
        updateLogs[petitionId].push(UpdateLog({
            timestamp: block.timestamp,
            fieldUpdated: "endDate",
            oldValue: uintToString(oldEndDate),
            newValue: uintToString(newEndDate)
        }));

        emit PetitionUpdated(petitionId, "endDate", block.timestamp);
    }

    /**
     * @dev Set petition active status
     * @param petitionId ID of the petition
     * @param active New active status
     */
    function setPetitionStatus(uint256 petitionId, bool active) 
        external 
        petitionExists(petitionId) 
        onlyPetitionOwner(petitionId) 
    {
        petitions[petitionId].isActive = active;
        emit PetitionStatusChanged(petitionId, active);
    }

    /**
     * @dev Get petition details
     * @param petitionId ID of the petition
     * @return PetitionData struct with all petition information
     */
    function getPetition(uint256 petitionId) 
        external 
        view 
        petitionExists(petitionId) 
        returns (PetitionData memory) 
    {
        return petitions[petitionId];
    }

    /**
     * @dev Get all signers of a petition
     * @param petitionId ID of the petition
     * @return Array of signer addresses
     */
    function getSigners(uint256 petitionId) 
        external 
        view 
        petitionExists(petitionId) 
        returns (address[] memory) 
    {
        return signers[petitionId];
    }

    /**
     * @dev Get update logs for a petition
     * @param petitionId ID of the petition
     * @return Array of update logs
     */
    function getUpdateLogs(uint256 petitionId) 
        external 
        view 
        petitionExists(petitionId) 
        returns (UpdateLog[] memory) 
    {
        return updateLogs[petitionId];
    }

    /**
     * @dev Check if an address has signed a petition
     * @param petitionId ID of the petition
     * @param signer Address to check
     * @return Whether the address has signed
     */
    function hasAddressSigned(uint256 petitionId, address signer) 
        external 
        view 
        petitionExists(petitionId) 
        returns (bool) 
    {
        return hasSigned[petitionId][signer];
    }

    /**
     * @dev Get total number of petitions created
     * @return Total petition count
     */
    function getTotalPetitions() external view returns (uint256) {
        return petitionCounter;
    }

    /**
     * @dev Get petition statistics
     * @param petitionId ID of the petition
     * @return signatureCount Number of signatures
     * @return isActive Whether petition is active
     * @return hasEnded Whether petition has ended
     * @return hasStarted Whether petition has started
     */
    function getPetitionStats(uint256 petitionId) 
        external 
        view 
        petitionExists(petitionId) 
        returns (
            uint256 signatureCount,
            bool isActive,
            bool hasEnded,
            bool hasStarted
        ) 
    {
        PetitionData memory p = petitions[petitionId];
        return (
            p.signatureCount,
            p.isActive,
            block.timestamp > p.endDate,
            block.timestamp >= p.startDate
        );
    }

    /**
     * @dev Helper function to convert uint to string
     * @param value The uint to convert
     * @return The string representation
     */
    function uintToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}