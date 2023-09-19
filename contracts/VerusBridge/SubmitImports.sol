// SPDX-License-Identifier: MIT
// Bridge between ethereum and verus

pragma solidity >=0.8.9;
pragma abicoder v2;

import "../Libraries/VerusObjects.sol";
import "../Libraries/VerusConstants.sol";
import "./Token.sol";
import "../Storage/StorageMaster.sol";


contract SubmitImports is VerusStorage {

    address immutable VETH;
    address immutable BRIDGE;
    address immutable VERUS;

    constructor(address vETH, address Bridge, address Verus){

        VETH = vETH;
        BRIDGE = Bridge;
        VERUS = Verus;
    }

    uint32 constant ELVCHOBJ_TXID_OFFSET = 32;
    uint32 constant ELVCHOBJ_NVINS_OFFSET = 45;
    uint32 constant FORKS_NOTARY_INDEX = 106;  // this is txid + stateroot + blockhash + NOTARIZER_INDEX_AND_FLAGS_OFFSET 
    uint32 constant FORKS_NOTARY_PROPOSER_POSITION = 128;
    function sendToVRSC(uint64 value, address sendTo, uint8 destinationType) public 
    {
        VerusObjects.CReserveTransfer memory LPtransfer;
        bool forceNewCCE;
      
        LPtransfer.version = 1;
        LPtransfer.destination.destinationtype = destinationType;
        LPtransfer.destcurrencyid = BRIDGE;
        LPtransfer.destsystemid = address(0);
        LPtransfer.secondreserveid = address(0);

        LPtransfer.flags = VerusConstants.VALID;

        if (sendTo == address(0)) {
            LPtransfer.flags += VerusConstants.BURN_CHANGE_PRICE ;
            LPtransfer.destination.destinationaddress = bytes(hex'B26820ee0C9b1276Aac834Cf457026a575dfCe84');
        } else {
            LPtransfer.destination.destinationaddress = abi.encodePacked(sendTo);
        }
        
        if (value == 0) {
            LPtransfer.currencyvalue.currency = VERUS;
            LPtransfer.fees = VerusConstants.verusTransactionFee; 
            LPtransfer.feecurrencyid = VERUS; 
            LPtransfer.currencyvalue.amount = uint64(remainingLaunchFeeReserves - VerusConstants.verusTransactionFee);
            forceNewCCE = true;
        } else {
            LPtransfer.currencyvalue.currency = VETH;
            LPtransfer.fees = VerusConstants.verusvETHTransactionFee; 
            LPtransfer.feecurrencyid = VETH;
            LPtransfer.currencyvalue.amount = uint64(value - VerusConstants.verusvETHTransactionFee);  
            forceNewCCE = false;
        } 

        // When the bridge launches to make sure a fresh block with no pending vrsc transfers is used as not to mix destination currencies.
        address verusBridgeAddress = contracts[uint(VerusConstants.ContractType.CreateExport)];

        (bool success,) = verusBridgeAddress.delegatecall(abi.encodeWithSignature("externalCreateExportCall(bytes)", abi.encode(LPtransfer, forceNewCCE)));
        require(success);
       // _createExports(LPtransfer, true, forceNewCCE);

    }

    function _createImports(bytes calldata data) external returns(uint64, uint176) {
              
        VerusObjects.CReserveTransferImport memory _import = abi.decode(data, (VerusObjects.CReserveTransferImport));
        bytes32 txidfound;
        bytes memory elVchObj = _import.partialtransactionproof.components[0].elVchObj;
        uint32 nVins;

        assembly
        {
            txidfound := mload(add(elVchObj, ELVCHOBJ_TXID_OFFSET)) 
            nVins := mload(add(elVchObj, ELVCHOBJ_NVINS_OFFSET)) 
        }

        if (processedTxids[txidfound]) 
        {
            revert("Known txid");
        } 

        bool success;
        bytes memory returnBytes;
        
        // reverse 32bit endianess
        nVins = ((nVins & 0xFF00FF00) >> 8) |  ((nVins & 0x00FF00FF) << 8);
        nVins = (nVins >> 16) | (nVins << 16);

        bytes32 hashOfTransfers;

        // [0..139]address of reward recipricent and [140..203]int64 fees
        uint64 fees;

        // [0..31]startheight [32..63]endheight [64..95]nIndex, [96..128] numberoftransfers packed into a uint128  
        uint128 CCEHeightsAndnIndex;

        hashOfTransfers = keccak256(_import.serializedTransfers);

        address verusProofAddress = contracts[uint(VerusConstants.ContractType.VerusProof)];

        (success, returnBytes) = verusProofAddress.delegatecall(abi.encodeWithSignature("proveImports(bytes)", abi.encode(_import, hashOfTransfers)));
        require(success);
        uint176 exporter;
        (fees, CCEHeightsAndnIndex, exporter) = abi.decode(returnBytes, (uint64, uint128, uint176));

        isLastCCEInOrder(uint32(CCEHeightsAndnIndex));
   
        // clear 4 bytes above first 64 bits, i.e. clear the nIndex 32 bit number, then convert to correct nIndex
        // Using the index for the proof (ouput of an export) - (header ( 2 * nvin )) == export output
        // NOTE: This depends on the serialization of the CTransaction header and the location of the vins being 45 bytes in.
        // NOTE: Also depends on it being a partial transaction proof, header = 1

        CCEHeightsAndnIndex  = (CCEHeightsAndnIndex & 0xffffffff00000000ffffffffffffffff) | (uint128(uint32(uint32(CCEHeightsAndnIndex >> 64) - (1 + (2 * nVins)))) << 64);  
        setLastImport(txidfound, hashOfTransfers, CCEHeightsAndnIndex);
        
        // Deserialize transfers and pack into send arrays, also pass in no. of transfers to calculate array size

        address verusTokenManagerAddress = contracts[uint(VerusConstants.ContractType.TokenManager)];

        (success, returnBytes) = verusTokenManagerAddress.delegatecall(abi.encodeWithSignature("processTransactions(bytes,uint8)", _import.serializedTransfers, uint8(CCEHeightsAndnIndex >> 96)));
        require(success);

        bytes memory refundsData;
        (refundsData) = abi.decode(returnBytes, (bytes));
        
        refund(refundsData);

        return (fees, exporter);

    }
  
    function refund(bytes memory refundAmount) private  {

        // Note each refund is 40 bytes = 32bytes + uint64 
        for(uint i = 0; i < (refundAmount.length / 40); i = i + 40) {

            bytes32 verusAddress;
            uint64 amount;
            assembly 
            {
                verusAddress := mload(add(add(refundAmount, 32), i))
                amount := mload(add(add(refundAmount, 40), i))
            }
            refunds[verusAddress] += amount; //verusNotarizerStorage.setOrAppendRefund(verusAddress, amount);
        }
     }

    function setLastImport(bytes32 processedTXID, bytes32 hashofTXs, uint128 CCEheightsandTXNum ) private {

        processedTxids[processedTXID] = true;
        lastTxIdImport = processedTXID;
        lastImportInfo[processedTXID] = VerusObjects.lastImportInfo(hashofTXs, processedTXID, uint32(CCEheightsandTXNum >> 64), uint32(CCEheightsandTXNum >> 32));
    } 

    function isLastCCEInOrder(uint32 height) private view {
      
        if ((lastImportInfo[lastTxIdImport].height + 1) == height)
        {
            return;
        } 
        else if (lastTxIdImport == bytes32(0))
        {
            return;
        } 
        else{
            revert();
        }
    }
    
    function getReadyExportsByRange(uint _startBlock,uint _endBlock) external view returns(VerusObjects.CReserveTransferSetCalled[] memory returnedExports){
    
        uint outputSize;
        uint heights = _startBlock;
        bool loop = cceLastEndHeight > 0;

        if(!loop) return returnedExports;

        while(loop){

            heights = _readyExports[heights].endHeight + 1;
            if (heights > _endBlock || heights == 1) {
                break;
            }
            outputSize++;
        }

        returnedExports = new VerusObjects.CReserveTransferSetCalled[](outputSize);
        VerusObjects.CReserveTransferSet memory tempSet;
        heights = _startBlock;

        for (uint i = 0; i < outputSize; i++)
        {
            tempSet = _readyExports[heights];
            returnedExports[i] = VerusObjects.CReserveTransferSetCalled(tempSet.exportHash, tempSet.prevExportHash, uint64(heights), tempSet.endHeight, tempSet.transfers);
            heights = tempSet.endHeight + 1;
        }
        return returnedExports;      
    }

    function setClaimableFees(uint64 fees, uint176 exporter) external
    {
        uint64 transactionBaseCost;

        transactionBaseCost = uint64((tx.gasprice * VerusConstants.VERUS_IMPORT_GAS_USEAGE) / VerusConstants.SATS_TO_WEI_STD);

        if (fees <= transactionBaseCost) {

            claimableFees[bytes32(uint256(uint160(VerusConstants.VDXF_SYSTEM_NOTARIZATION_NOTARYFEEPOOL)))] += fees;
           
        } else {

            bytes memory proposerBytes = bestForks[0];
            uint176 proposer;

            assembly {
                    proposer := mload(add(proposerBytes, FORKS_NOTARY_PROPOSER_POSITION))
            } 

            uint64 feeShare;

            feeShare = (fees - transactionBaseCost) / 3;
            claimableFees[bytes32(uint256(uint160(VerusConstants.VDXF_SYSTEM_NOTARIZATION_NOTARYFEEPOOL)))] += feeShare;
            setClaimedFees(bytes32(uint256(proposer)), feeShare); // 1/3 to proposer
            setClaimedFees(bytes32(uint256(exporter)), feeShare + ((fees - transactionBaseCost) % 3)); // any remainder from main division goes to exporter
        }
    }

    function setClaimedFees(bytes32 _address, uint256 fees) private  {

        claimableFees[_address] += fees;
    }

    function setNotaryClaimedFees(uint176 notary, uint256 fees) private  {

        notary |= (uint176(0x0c14) << VerusConstants.UINT160_BITS_SIZE); //set at type eth
        claimableFees[bytes32(uint256(notary))] += fees;
    }

    function claimfees() public {

        uint256 claimAmount;
        uint256 claimant;
        claimant = uint256(uint160(msg.sender));

        // Check claimant is type eth with length 20 and has fees to be got.
        claimant |= (uint256(0x0c14) << VerusConstants.UINT160_BITS_SIZE);
        claimAmount = claimableFees[bytes32(claimant)];

        if(claimAmount > 0)
        {
            //stored as SATS convert to WEI
            claimableFees[bytes32(claimant)] = 0;
            payable(msg.sender).transfer(claimAmount * VerusConstants.SATS_TO_WEI_STD);
        }
        else if ((claimableFees[bytes32(uint256(uint160(VerusConstants.VDXF_SYSTEM_NOTARIZATION_NOTARYFEEPOOL)))] *  VerusConstants.SATS_TO_WEI_STD) 
                    > (tx.gasprice * VerusConstants.SEND_NOTARY_PAYMENT_FEE))
        {
            bool notaryFound = false;
            for (uint i = 0; i < notaries.length; i++)
            {
                if (notaryAddressMapping[notaries[i]].main == msg.sender)
                {
                    notaryFound = true;
                }
            }

            if(notaryFound) {

                uint256 txReimburse;

                txReimburse = (tx.gasprice * notaries.length * VerusConstants.SEND_GAS_PRICE);

                if (claimableFees[bytes32(0)] > 0) {
                    // When there is no proposer fees are sent to bytes(0)
                    claimableFees[bytes32(uint256(uint160(VerusConstants.VDXF_SYSTEM_NOTARIZATION_NOTARYFEEPOOL)))] += claimableFees[bytes32(0)];
                    claimableFees[bytes32(0)] = 0;
                }

                claimAmount = claimableFees[bytes32(uint256(uint160(VerusConstants.VDXF_SYSTEM_NOTARIZATION_NOTARYFEEPOOL)))] - txReimburse;

                claimableFees[bytes32(uint256(uint160(VerusConstants.VDXF_SYSTEM_NOTARIZATION_NOTARYFEEPOOL)))] = 0;

                uint256 claimShare;
                
                claimShare = claimAmount / notaries.length;

                for (uint i = 0; i < notaries.length; i++)
                {
                    if (notaryAddressMapping[notaries[i]].state == VerusConstants.NOTARY_VALID)
                    {
                        claimAmount -= claimShare;
                        payable(notaryAddressMapping[notaries[i]].main).transfer(claimShare * VerusConstants.SATS_TO_WEI_STD);
                    }
                }
                claimableFees[bytes32(uint256(uint160(VerusConstants.VDXF_SYSTEM_NOTARIZATION_NOTARYFEEPOOL)))] = claimAmount;
                payable(msg.sender).transfer(txReimburse);

            }
        }
    }

    function claimRefund(uint176 verusAddress) public 
    {
        uint64 refundAmount;
        refundAmount = uint64(refunds[bytes32(uint256(verusAddress))]);
        require(bridgeConverterActive, "Bridge converter not active");

        if (refundAmount > 0)
        {
            refunds[bytes32(uint256(verusAddress))] = 0;
            sendToVRSC(refundAmount, address(uint160(verusAddress)), uint8(verusAddress >> 168));
        }
        else
        {
            revert("No fees avaiable");
        }
    }

    function sendfees(bytes32 publicKeyX, bytes32 publicKeyY) public 
    {
        require(bridgeConverterActive, "Bridge converter not active");
        uint8 leadingByte;

        leadingByte = (uint256(publicKeyY) & 1) == 1 ? 0x03 : 0x02;

        address rAddress = address(ripemd160(abi.encodePacked(sha256(abi.encodePacked(leadingByte, publicKeyX)))));
        address ethAddress = address(uint160(uint256(keccak256(abi.encodePacked(publicKeyX, publicKeyY)))));

        uint256 claimant; 

        claimant = uint256(uint160(rAddress));

        claimant |= (uint256(0x0214) << VerusConstants.UINT160_BITS_SIZE);  // is Claimient type R address and 20 bytes.

        if ((claimableFees[bytes32(claimant)] > VerusConstants.verusvETHTransactionFee) && msg.sender == ethAddress)
        {
            claimableFees[bytes32(claimant)] = 0;
            sendToVRSC(uint64(claimableFees[bytes32(claimant)]), rAddress, VerusConstants.DEST_PKH); //sent in as SATS
        }
        else
        {
            revert("No fees avaiable");
        }

    }

}