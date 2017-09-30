pragma solidity ^0.4.13;

/*
* TODO: Keep count of any extra ether or donations in the contract
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
    uint8 daysToDeliver;
    address owner;
    bool disabled;
  }

  mapping( string => Gig ) gigs;
  mapping( string => mapping( string => GigContract ) ) gigContractsMap;
  mapping( string => string ) contractGigMap;
  mapping( string => uint ) escrowedMap;
  mapping( string => uint ) delayRejectedMap;

  struct GigContract {
    string gigHash;
    address buyer;
    string contractIPFSHash;
    uint amount;
    uint feedbackStake;
    uint executionBlock;
  }

  /*
  ** create a gig. unique id of gig is same as initial ipfs hash
  */
  function createGig(string ipfsHash, uint8 category, uint8 price, uint8 daysToDeliver) {
    require( gigs[ipfsHash].daysToDeliver == 0 ); // ensures there is no existing gig for corresponding gigHash
    Gig memory gig;
    gig.ipfsHash = ipfsHash;
    gig.category = category;
    gig.price = price;
    gig.daysToDeliver = daysToDeliver;
    gig.owner = msg.sender;
    gig.disabled = false;
    gigs[ipfsHash] = gig;
    onGigCreated(ipfsHash);
  }

  /**
  ** update a gig. Diabling a gig should also the same method.
  **/
  function updateGig(string gigHash, string ipfsHash, uint8 category, uint8 price, uint8 daysToDeliver, bool disabled) {
    require( gigs[gigHash].owner == msg.sender ); // ensures owner is sender to update
    Gig memory gig;
    gig.ipfsHash = ipfsHash;
    gig.category = category;
    gig.price = price;
    gig.daysToDeliver = daysToDeliver;
    gig.disabled = disabled;
    gigs[gigHash] = gig;
    onGigUpdated(gigHash);
  }

  function contractGig(string gigHash, string contractIPFSHash) {
    require( ( gigContractsMap[gigHash][contractIPFSHash].price == 0 ) && ( msg.value >= gigs[gigHash].price + feedbackStakeWei ) ) ; // ensures no mapping exist for gigHash -> contractIPFSHash
    GigContract memory gContract;
    gContract.gigHash = gigHash;
    gContract.buyer = msg.sender;
    gContract.contractIPFSHash = contractIPFSHash;
    gContract.amount = gigs[gigHash].price; // price when it was contracted since that can change later
    gContract.executionBlock = block.number;
    gContract.feedbackStake = feedbackStakeWei; // should lock in case contract constant changes in future
    gigContractsMap[gigHash][contractIPFSHash] = gContract;
    contractGigMap[contractIPFSHash] = gigHash;
    escrowedMap[contractIPFSHash] = msg.value;
    onContract(gigHash, contractIPFSHash);
  }

  /**
  ** Seller can reject contract in can_honor_reject_blocks without any reputation damage
  ** Any rejected after that will show in rejected orders for seller.
  **/
  function sellerRejectContract( contractHash ) {
    require( gigs[contractGigMap[contractHash]].owner == msg.sender );
    // return back money to buyer.
    address u = gigContractsMap[contractGigMap[contractHash]][contractHash].buyer;
    u.transfer(escrowedMap[contractHash]);
    escrowedMap[contractHash] = 0;
    if( block.number > gigContractsMap[contractGigMap[contractHash]][contractHash].executionBlock + can_honor_reject_blocks ) {
      delayRejectedMap[msg.sender] = delayRejectedMap[msg.sender] + 1; // publicly available information 
    }
  }

  function sellerAcceptsContract() {

  }

  function sellerConfirmCompleted() {

  }

  function buyerWithdrawOnContractFailure() {

  }

  function sellerDeclareFailure() {

  }

  function buyerProvideFeedback() {

  }

  function getGig(string hash) constant returns(string,uint8, uint8, uint8) {
    return(gigs[hash].ipfsHash, gigs[hash].category, gigs[hash].price, gigs[hash].daysToDeliver);
  }

  function getUserGigs() {

  }

  function getGigsByCategory() {

  }
}
