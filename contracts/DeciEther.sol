pragma solidity ^0.4.13;

/*
* TODO: Keep count of any extra ether or donations in the contract
* TODO: check overflows
* TODO: verify money leaks
*/
import "./Ownable.sol";
import './Strings.sol';

contract DeciEther is Ownable {
  using strings for *;

  /**
  * define all constants below. Should be update-able
  **/
  uint feedbackStakeWei = 10000000000000000;
  uint totalEscrowedWei = 0; // initialise 0 on deploying contract
  uint can_honor_reject_blocks = 3456;

  event onGigCreated(string ipfsHash);
  event onGigUpdated(string ipfsHash);
  event onContract( string gigHash, string contractHash );

  struct Gig {
    string ipfsHash;
    uint8 category;
    uint price;
    uint blocksToDeliver;
    address owner;
    bool disabled;
  }

  mapping( string => Gig ) gigs; // map gigHash to a gig
  mapping( string => string[] ) gigContractsMap; // map a gig to all contracts ( as array of contractHash ) done for a gig
  mapping( string => GigContract ) contractMap; // map contractHash to contract
  mapping( string => uint ) escrowedMap;  // map of all amounts escrowed for a contract
  mapping( address => uint ) delayNotAcceptedMap; // map of all contracts rejected by seller after delay
  mapping( address => uint ) timelyNotDeliveredMap; // map of all contracts rejected by seller after delay
  mapping( address => uint ) totalVouch;

  struct GigContract {
    string gigHash;
    address buyer;
    string contractIPFSHash;
    uint amount;
    uint feedbackStake;
    uint startBlock;
    uint acceptBlock;
    uint deliverBlock;
    uint blocksToDeliver;
    uint8 contractStatus;
    string feedbackHash;
    uint vouch;
  }

  /*
  ** create a gig. unique id of gig is same as initial ipfs hash
  */
  function createGig(string ipfsHash, uint8 category, uint8 price, uint blocksToDeliver) {
    require( gigs[ipfsHash].blocksToDeliver == 0 ); // ensures there is no existing gig for corresponding gigHash
    Gig memory gig;
    gig.ipfsHash = ipfsHash;
    gig.category = category;
    gig.price = price;
    gig.blocksToDeliver = blocksToDeliver;
    gig.owner = msg.sender;
    gig.disabled = false;
    gigs[ipfsHash] = gig;
    onGigCreated(ipfsHash);
  }

  /**
  ** update a gig. Diabling a gig should also the same method.
  **/
  function updateGig(string gigHash, string ipfsHash, uint8 category, uint8 price, uint blocksToDeliver, bool disabled) {
    require( gigs[gigHash].owner == msg.sender ); // ensures owner is sender to update
    Gig memory gig;
    gig.ipfsHash = ipfsHash;
    gig.category = category;
    gig.price = price;
    gig.blocksToDeliver = blocksToDeliver;
    gig.disabled = disabled;
    gigs[gigHash] = gig;
    onGigUpdated(gigHash);
  }

  function contractGig(string gigHash, string contractIPFSHash) {
    require( ( contractMap[contractIPFSHash].contractStatus == 0 ) && ( msg.value >= gigs[gigHash].price + feedbackStakeWei ) ) ; // ensures no mapping exist for gigHash -> contractIPFSHash
    GigContract memory gContract;
    gContract.gigHash = gigHash;
    gContract.buyer = msg.sender;
    gContract.contractIPFSHash = contractIPFSHash;
    gContract.amount = msg.value - feedbackStakeWei; // in case seller wanted to pay more...
    gContract.startBlock = block.number;
    gContract.feedbackStake = feedbackStakeWei; // should lock in case contract constant changes in future
    gContract.blocksToDeliver = gigs[gigHash].blocksToDeliver;
    gContract.contractStatus = 11;
    contractMap[contractIPFSHash] = gContract;
    gigContractsMap[gigHash].push( contractIPFSHash );
    escrowedMap[contractIPFSHash] = msg.value;
    onContract(gigHash, contractIPFSHash);
  }

  /**
  ** Seller can reject contract in can_honor_reject_blocks without any reputation damage
  ** Any rejected after that will show in rejected orders for seller.
  **/
  function sellerRejectContract( string contractHash ) {
    require( gigs[ contractMap[contractHash].gigHash ].owner == msg.sender && contractMap[contractHash].contractStatus < 21 );
    // return back money to buyer.
    address u = contractMap[contractHash].buyer;
    u.transfer(escrowedMap[contractHash]);
    escrowedMap[contractHash] = 0;
    contractMap[contractHash].contractStatus = 21;
    if( block.number > contractMap[contractHash].startBlock + can_honor_reject_blocks ) {
      delayNotAcceptedMap[msg.sender] = delayNotAcceptedMap[msg.sender] + 1; // publicly available information
      contractMap[contractHash].deliverBlock = block.number;  // if delivered but not accepted means rejected
    }
  }

  function sellerAcceptsContract( string contractHash ) {
    require( ( gigs[ contractMap[contractHash].gigHash ].owner == msg.sender ) && ( contractMap[contractHash].acceptBlock == 0 )  && contractMap[contractHash].contractStatus < 21 );
    contractMap[contractHash].acceptBlock = block.number;
    contractMap[contractHash].contractStatus = 41;
  }

  function buyerWithdrawOnContractFailure( string contractHash ) {
    require( ( contractMap[contractHash].buyer == msg.sender ) && ( contractMap[contractHash].deliverBlock == 0 ) );
    address u;
    if( contractMap[contractHash].acceptBlock == 0 ) {
      if( block.number > contractMap[contractHash].startBlock + can_honor_reject_blocks ) {
        delayNotAcceptedMap[msg.sender] = delayNotAcceptedMap[msg.sender] + 1; // publicly available information
        contractMap[contractHash].contractStatus = 31;
        // return back money to buyer.
        u = contractMap[contractHash].buyer;
        u.transfer(escrowedMap[contractHash]);
        escrowedMap[contractHash] = 0;
      }
    } else {
      // check for delivery date has passed
      if( block.number > contractMap[contractHash].acceptBlock + contractMap[contractHash].blocksToDeliver ) {
        contractMap[contractHash].contractStatus = 51;
        timelyNotDeliveredMap[msg.sender] = timelyNotDeliveredMap[msg.sender] + 1; // publicly available information
        // return back money to buyer.
        u = contractMap[contractHash].buyer;
        u.transfer(escrowedMap[contractHash]);
        escrowedMap[contractHash] = 0;
      }
    }
  }

  function sellerConfirmCompleted( string contractHash ) {
    require( ( gigs[ contractMap[contractHash].gigHash ].owner == msg.sender ) && ( contractMap[contractHash].deliverBlock == 0 ) && ( contractMap[contractHash].acceptBlock > 0 ) );
    address u = msg.sender;
    u.transfer(contractMap[contractHash].amount);
    escrowedMap[contractHash] = escrowedMap[contractHash] - contractMap[contractHash].amount;
    contractMap[contractHash].deliverBlock == block.number;
    contractMap[contractHash].contractStatus = 61;
  }

  function buyerProvideFeedback( string contractHash, string feedbackHash, uint vouch ) {
    require( ( contractMap[contractHash].buyer == msg.sender ) && contractMap[contractHash].contractStatus > 61 && contractMap[contractHash].contractStatus < 71 ); // feedback will override
    contractMap[contractHash].contractStatus = 71;
    contractMap[contractHash].feedbackHash = feedbackHash;
    address u = msg.sender;
    u.transfer(escrowedMap[contractHash]);
    escrowedMap[contractHash] = 0;
    if( vouch> 0 ) {
      address us = gigs[ contractMap[contractHash].gigHash ].owner;
      us.transfer(vouch);
      contractMap[contractHash].vouch = vouch;
      totalVouch[us] = totalVouch[us] + vouch;
    }
  }

  function getGig(string hash) constant returns(string,uint8, uint, uint) {
    return(gigs[hash].ipfsHash, gigs[hash].category, gigs[hash].price, gigs[hash].blocksToDeliver);
  }

  function getGigContract(string contractHash) constant returns(string) {
    return(contractMap[contractHash].gigHash);
  }

  function getUserGigs() {

  }

  function getGigsByCategory() {

  }
}
