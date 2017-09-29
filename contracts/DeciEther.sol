pragma solidity ^0.4.13;

import "./Ownable.sol";
import './Strings.sol';

contract DeciEther is Ownable {
  using strings for *;
  event onGigCreated(string ipfsHash);
  event onGigUpdated(string ipfsHash);

  struct Gig {
    string ipfsHash;
    uint8 category;
    uint8 price;
    uint8 daysToDeliver;
    address owner;
  }

  mapping( string => Gig ) gigs;

  struct GigContract {
    string gigHash;
    address buyer;
  }

  function createGig(string ipfsHash, uint8 category, uint8 price, uint8 daysToDeliver) {
    require( gigs[ipfsHash].daysToDeliver == 0 );
    Gig memory gig;
    gig.ipfsHash = ipfsHash;
    gig.category = category;
    gig.price = price;
    gig.daysToDeliver = daysToDeliver;
    gig.owner = msg.sender;
    gigs[ipfsHash] = gig;
    onGigCreated(ipfsHash);
  }

  function updateGig(string gigHash, string ipfsHash, uint8 category, uint8 price, uint8 daysToDeliver) {
    require( gigs[gigHash].owner == msg.sender );
    Gig memory gig;
    gig.ipfsHash = ipfsHash;
    gig.category = category;
    gig.price = price;
    gig.daysToDeliver = daysToDeliver;
    gigs[gigHash] = gig;
    onGigUpdated(gigHash);
  }

  function disableGig() {

  }

  function contractGig() {

  }

  function sellerRejectContract() {

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
