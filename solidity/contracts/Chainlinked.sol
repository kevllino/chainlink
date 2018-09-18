pragma solidity ^0.4.24;

import "./ChainlinkLib.sol";
import "./ENSResolver.sol";
import "./Oracle.sol";
import "ens/contracts/ENS.sol";
import "linkToken/contracts/LinkToken.sol";

contract Chainlinked {
  using ChainlinkLib for ChainlinkLib.Run;
  using SafeMath for uint256;

  uint256 constant internal clArgsVersion = 1;
  uint256 constant internal linkDivisibility = 10**18;

  LinkToken internal link;
  Oracle internal oracle;
  uint256 internal requests = 1;
  mapping(bytes32 => address) internal unfulfilledRequests;

  ENS internal ens;
  bytes32 internal ensNode;
  bytes32 constant internal ensTokenSubname = "link";
  bytes32 constant internal ensOracleSubname = "oracle";

  event ChainlinkRequested(bytes32 id);
  event ChainlinkFulfilled(bytes32 id);
  event ChainlinkCancelled(bytes32 id);

  function newRun(
    bytes32 _specId,
    address _callbackAddress,
    string _callbackFunctionSignature
  ) internal pure returns (ChainlinkLib.Run memory) {
    ChainlinkLib.Run memory run;
    return run.initialize(_specId, _callbackAddress, _callbackFunctionSignature);
  }

  function chainlinkRequest(ChainlinkLib.Run memory _run, uint256 _wei)
    internal
    returns(bytes32)
  {
    _run.requestId = bytes32(requests);
    _run.close();
    require(link.transferAndCall(oracle, _wei, _run.encodeForOracle(clArgsVersion)), "unable to transferAndCall to oracle");
    emit ChainlinkRequested(_run.requestId);
    unfulfilledRequests[_run.requestId] = oracle;
    requests += 1;
    return _run.requestId;
  }

  function cancelChainlinkRequest(bytes32 _requestId)
    internal
  {
    oracle.cancel(_requestId);
    unfulfilledRequests[_requestId] = 0x0;
    emit ChainlinkCancelled(_requestId);
  }

  function LINK(uint256 _amount) internal view returns (uint256) {
    return _amount.mul(linkDivisibility);
  }

  function setOracle(address _oracle) internal {
    oracle = Oracle(_oracle);
  }

  function setLinkToken(address _link) internal {
    link = LinkToken(_link);
  }

  function newChainlinkWithENS(address _ens, bytes32 _node) internal {
    ens = ENS(_ens);
    ensNode = _node;
    ENSResolver resolver = ENSResolver(ens.resolver(ensNode));
    bytes32 linkSubnode = keccak256(abi.encodePacked(ensNode, ensTokenSubname));
    setLinkToken(resolver.addr(linkSubnode));
    updateOracleWithENS();
  }

  function updateOracleWithENS() internal {
    ENSResolver resolver = ENSResolver(ens.resolver(ensNode));
    bytes32 oracleSubnode = keccak256(abi.encodePacked(ensNode, ensOracleSubname));
    setOracle(resolver.addr(oracleSubnode));
  }

  modifier checkChainlinkFulfillment(bytes32 _requestId) {
    require(msg.sender == unfulfilledRequests[_requestId], "source must be the oracle of the request");
    _;
    unfulfilledRequests[_requestId] = 0x0;
    emit ChainlinkFulfilled(_requestId);
  }
}