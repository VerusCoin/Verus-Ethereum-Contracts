// SPDX-License-Identifier: MIT
// Bridge between ethereum and verus

pragma solidity >=0.8.9;
pragma abicoder v2;

import "../Libraries/VerusObjects.sol";
import "../Libraries/VerusConstants.sol";
import "./Token.sol";
import "../Storage/StorageMaster.sol";
import "./CreateExports.sol";
import "./TokenManager.sol";


contract SubmitImports is VerusStorage {

    address immutable VETH;
    address immutable BRIDGE;
    address immutable VERUS;
    address immutable DAI;
    address immutable MKR;

    constructor(address vETH, address Bridge, address Verus, address Dai, address Mkr){

        VETH = vETH;
        BRIDGE = Bridge;
        VERUS = Verus;
        DAI = Dai;
        MKR = Mkr;
    }

    uint32 constant ELVCHOBJ_TXID_OFFSET = 32;
    uint32 constant ELVCHOBJ_NVINS_OFFSET = 45;
    uint32 constant FORKS_NOTARY_PROPOSER_POSITION = 128;
    uint32 constant TYPE_REFUND = 1;
    uint constant TYPE_BYTE_LOCATION_IN_UINT176 = 168;
    enum Currency {VETH, DAI, VERUS, MKR}

    function buildReserveTransfer (uint64 value, uint176 sendTo, address sendingCurrency, uint64 fees, address feecurrencyid) private view returns (VerusObjects.CReserveTransfer memory) {
        
        VerusObjects.CReserveTransfer memory LPtransfer;
      
        LPtransfer.version = 1;
        LPtransfer.destination.destinationtype = uint8(sendTo >> TYPE_BYTE_LOCATION_IN_UINT176);
        LPtransfer.destcurrencyid = BRIDGE;
        LPtransfer.destsystemid = address(0);
        LPtransfer.secondreserveid = address(0);
        LPtransfer.flags = VerusConstants.VALID;
        LPtransfer.destination.destinationaddress = abi.encodePacked(sendTo);
        LPtransfer.currencyvalue.currency = sendingCurrency;
        LPtransfer.feecurrencyid = feecurrencyid;
        LPtransfer.fees = fees;
        LPtransfer.currencyvalue.amount = value;          
        
        return LPtransfer;
    }

    function sendBurnBackToVerus (uint64 sendAmount, address currency, uint64 fees) public view returns (VerusObjects.CReserveTransfer memory) {
        
        VerusObjects.CReserveTransfer memory LPtransfer;

        if (currency == VERUS) {
            LPtransfer =  buildReserveTransfer(uint64(remainingLaunchFeeReserves - VerusConstants.verusTransactionFee),
                                               uint176(0x0214B26820ee0C9b1276Aac834Cf457026a575dfCe84),
                                               VERUS,
                                               VerusConstants.verusTransactionFee,
                                               VERUS );
        } else if (currency == DAI) {
            LPtransfer =  buildReserveTransfer(sendAmount,
                                               uint176(0x0214B26820ee0C9b1276Aac834Cf457026a575dfCe84),
                                               DAI,
                                               fees,
                                               DAI );
        } 

        LPtransfer.flags += VerusConstants.BURN_CHANGE_PRICE ;

        return LPtransfer;
    }

    function getImportFeeForReserveTransfer(address currency) public view returns (uint64) {
        
        uint64 feeShare;
        uint feeCalculation;
        uint reserves = claimableFees[bytes32(uint256(uint160(VerusConstants.VDXF_ETH_DAI_VRSC_LAST_RESERVES)))];

        // Get the uint64 location in the uin256 word to calculate fees
        if (currency == DAI){
            feeCalculation = uint(Currency.DAI) << 6;
        } else if (currency == MKR){
            feeCalculation = uint(Currency.MKR) << 6;
        } else if(currency == VETH) {
            feeCalculation = uint(Currency.VETH) << 6;
        }        

        if (currency != BRIDGE) {
            feeCalculation = VerusConstants.VERUS_IMPORT_FEE_X2 * uint64(reserves >> feeCalculation);
            feeShare = uint64(feeCalculation / uint(uint64(reserves >> (uint(Currency.VERUS) << 6))));
        }
        else {
            revert();
            // Paying fees in bridge not possible.
            // feeCalculation = VerusConstants.VERUS_IMPORT_FEE_X2 * uint64(reserves >> (uint(Currency.VERUS) << 6));
            // feeShare = uint64(feeCalculation * 4);
        } 

        return feeShare;
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
        (CCEHeightsAndnIndex, exporter) = abi.decode(returnBytes, (uint128, uint176));

        isLastCCEInOrder(uint32(CCEHeightsAndnIndex));
   
        // clear 4 bytes above first 64 bits, i.e. clear the nIndex 32 bit number, then convert to correct nIndex
        // Using the index for the proof (ouput of an export) - (header ( 2 * nvin )) == export output
        // NOTE: This depends on the serialization of the CTransaction header and the location of the vins being 45 bytes in.
        // NOTE: Also depends on it being a partial transaction proof, header = 1

        CCEHeightsAndnIndex  = (CCEHeightsAndnIndex & 0xffffffff00000000ffffffffffffffff) | (uint128(uint32(uint32(CCEHeightsAndnIndex >> 64) - (1 + (2 * nVins)))) << 64);  
        setLastImport(txidfound, hashOfTransfers, CCEHeightsAndnIndex);
        
        // Deserialize transfers and pack into send arrays, also pass in no. of transfers to calculate array size

        address verusTokenManagerAddress = contracts[uint(VerusConstants.ContractType.TokenManager)];

        (success, returnBytes) = verusTokenManagerAddress.delegatecall(abi.encodeWithSelector(TokenManager.processTransactions.selector, _import.serializedTransfers, uint8(CCEHeightsAndnIndex >> 96)));
        require(success);
        
        (returnBytes, fees) = abi.decode(returnBytes, (bytes, uint64));
        if (returnBytes.length > 0) {
            refund(returnBytes);
        }

        return (fees, exporter);

    }
  
    function refund(bytes memory refundAmount) private  {

        if (refundAmount.length < 50) return; //early return if no refunds.

        // Note each refund is 50 bytes = 22bytes(uint176) + uint64 + uint160 (currency)
        for(uint i = 0; i < (refundAmount.length / 50); i = i + 50) {

            uint176 verusAddress;
            uint64 amount;
            address currency;
            assembly 
            {
                verusAddress := mload(add(add(refundAmount, 22), i))
                amount := mload(add(add(refundAmount, 30), i))
                currency := mload(add(add(refundAmount, 50), i))
            }

            bytes32 refundAddress;

            // The leftmost byte is the TYPE_REFUND;
            refundAddress = bytes32(uint256(verusAddress) | uint256(TYPE_REFUND) << 244);

            refunds[refundAddress][currency] += amount;

        }
     }

    function setLastImport(bytes32 processedTXID, bytes32 hashofTXs, uint128 CCEheightsandTXNum ) private {

        processedTxids[processedTXID] = true;
       // lastTxIdImport = processedTXID;
        lastImportInfo[VerusConstants.SUBMIT_IMPORTS_LAST_TXID] = VerusObjects.lastImportInfo(hashofTXs, processedTXID, uint32(CCEheightsandTXNum >> 64), uint32(CCEheightsandTXNum >> 32));
    } 

    function isLastCCEInOrder(uint32 height) private view {
      
        if ((lastImportInfo[VerusConstants.SUBMIT_IMPORTS_LAST_TXID].height + 1) == height)
        {
            return;
        } 
        else if (lastImportInfo[VerusConstants.SUBMIT_IMPORTS_LAST_TXID].hashOfTransfers == bytes32(0))
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

            claimableFees[VerusConstants.VDXF_SYSTEM_NOTARIZATION_NOTARYFEEPOOL] += fees;
           
        } else {

            bytes memory proposerBytes = bestForks[0];
            uint176 proposer;

            assembly {
                    proposer := mload(add(proposerBytes, FORKS_NOTARY_PROPOSER_POSITION))
            } 

            uint64 feeShare;

            feeShare = (fees - transactionBaseCost) / 3;
            claimableFees[VerusConstants.VDXF_SYSTEM_NOTARIZATION_NOTARYFEEPOOL] += feeShare;
            setClaimedFees(bytes32(uint256(proposer)), feeShare); // 1/3 to proposer
            setClaimedFees(bytes32(uint256(exporter)), feeShare + ((fees - transactionBaseCost) % 3)); // any remainder from main division goes to exporter
        }
    }

    function setClaimedFees(bytes32 _address, uint256 fees) private  {

        claimableFees[_address] += fees;
    }

    function claimfees() public {

        uint256 claimAmount;

        if ((claimableFees[VerusConstants.VDXF_SYSTEM_NOTARIZATION_NOTARYFEEPOOL] *  VerusConstants.SATS_TO_WEI_STD) 
                    > (tx.gasprice * VerusConstants.SEND_NOTARY_PAYMENT_FEE))
        {
            uint256 txReimburse;

            txReimburse = (tx.gasprice * notaries.length * VerusConstants.SEND_GAS_PRICE);

            if (claimableFees[bytes32(0)] > 0) {
                // When there is no proposer fees are sent to bytes(0)
                claimableFees[VerusConstants.VDXF_SYSTEM_NOTARIZATION_NOTARYFEEPOOL] += claimableFees[bytes32(0)];
                claimableFees[bytes32(0)] = 0;
            }

            claimAmount = claimableFees[VerusConstants.VDXF_SYSTEM_NOTARIZATION_NOTARYFEEPOOL] - txReimburse;

            claimableFees[VerusConstants.VDXF_SYSTEM_NOTARIZATION_NOTARYFEEPOOL] = 0;

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
            claimableFees[VerusConstants.VDXF_SYSTEM_NOTARIZATION_NOTARYFEEPOOL] = claimAmount;
            payable(msg.sender).transfer(txReimburse);
        }
    }

    function claimRefund(uint176 verusAddress, address currency) external payable returns (uint)
    {
        uint256 refundAmount;
        bytes32 refundAddressFormatted;
        VerusObjects.CReserveTransfer memory LPtransfer;
        bool success;
        refundAddressFormatted = bytes32(uint256(verusAddress) | uint256(TYPE_REFUND) << 244);

        refundAmount = refunds[refundAddressFormatted][currency];
        require(bridgeConverterActive, "Bridge converter not active");

        if (refundAmount > 0 ) {
        
                delete refunds[refundAddressFormatted][currency];
                uint64 fees;
                address feeCurrency;

                if (currency != VETH && currency != DAI && currency != VERUS && currency != MKR && currency != BRIDGE) {
                    fees = getImportFeeForReserveTransfer(VETH);
                    if (msg.value < (fees * VerusConstants.SATS_TO_WEI_STD)) {
                        return fees;
                    }
                    //may have put too much in, so update fees for correct accounting.
                    fees = uint64(msg.value / VerusConstants.SATS_TO_WEI_STD);
                    feeCurrency = VETH;
                } else {
                   fees = getImportFeeForReserveTransfer(currency);
                   require (refundAmount > fees, "Refund amount less than fees");
                   feeCurrency = currency;
                }

                LPtransfer  = buildReserveTransfer(uint64(refundAmount), verusAddress, currency, fees, feeCurrency);

                if(verusAddress != uint176(0))  {

                    (success, ) = contracts[uint(VerusConstants.ContractType.CreateExport)]
                                        .delegatecall(abi.encodeWithSelector(CreateExports.externalCreateExportCallPayable.selector, abi.encode(LPtransfer, false)));
                    require(success);
                    return 0;
                } 

                if (currency == VETH ) {
                    claimableFees[VerusConstants.VDXF_SYSTEM_NOTARIZATION_NOTARYFEEPOOL] += refundAmount;
                    return 0;

                } else {
                    
                    VerusObjects.mappedToken memory mappedCurrency = verusToERC20mapping[currency];

                    uint256 claimShare;
                
                    claimShare = refundAmount / notaries.length;

                    for (uint i = 0; i < notaries.length; i++)
                    {
                        // TODO: Possible to upgrade to send ERC1155 and ERC721 NFTs out too.
                        if (notaryAddressMapping[notaries[i]].state == VerusConstants.NOTARY_VALID)
                        {
                            refundAmount -= claimShare;
                            IERC20(mappedCurrency.erc20ContractAddress).transfer(notaryAddressMapping[notaries[i]].main, claimShare);
                        }
                    }
                }
                return 0;
        }
        revert();
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
            uint64 feeShare;
            feeShare = uint64(claimableFees[bytes32(claimant)]);
            claimableFees[bytes32(claimant)] = 0;
            payable(msg.sender).transfer(feeShare * VerusConstants.SATS_TO_WEI_STD);
        }
        else
        {
            revert("No fees avaiable");
        }

    }

}