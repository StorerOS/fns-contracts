pragma solidity >=0.8.4;
// import './ensdomains/ens-contracts/contracts/registry/ENS.sol';
import './ensdomains/ens-contracts/contracts/resolvers/PublicResolver.sol';
import './ensdomains/ens-contracts/contracts/registry/ENSRegistry.sol';
import './ensdomains/ens-contracts/contracts/registry/FIFSRegistrar.sol';
import './ensdomains/ens-contracts/contracts/resolvers/Resolver.sol';
//import './ensdomains/ens-contracts/contracts/registry/ReverseRegistrar.sol';

// Construct a set of FNS contracts.
contract FnsDeployer {
    string private constant  LTD_NAME = 'fil';
    string private constant  RESOLVER_NAME = 'resolver';
    string private constant  REVERSE_NAME = 'reverse';
    string private constant  ADDR_NAME = 'addr';
    bytes32 public constant  TLD_LABEL = keccak256(bytes(LTD_NAME));
    bytes32 public constant  RESOLVER_LABEL = keccak256(bytes(RESOLVER_NAME));
    bytes32 public constant  REVERSE_REGISTRAR_LABEL = keccak256(bytes(REVERSE_NAME));
    bytes32 public constant  ADDR_LABEL = keccak256(bytes(ADDR_NAME));

    ENSRegistry private ens;
    FIFSRegistrar private fifsRegistrar;
    //ReverseRegistrar private reverseRegistrar;
    PublicResolver private publicResolver;

    function namehash(bytes32 node, bytes32 label) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(node, label));
    }

    function keccak(string memory name) public pure returns (bytes32) {
        return keccak256(bytes(name));
    }

    constructor() public {
        ens = new ENSRegistry();
        publicResolver = new PublicResolver(ens, INameWrapper(address(0)));
        // set up the TLD node
        bytes32 tldNode = namehash(bytes32(0), TLD_LABEL);
        // Set up the resolver
        bytes32 resolverNode = namehash(bytes32(0), RESOLVER_LABEL);

        ens.setSubnodeOwner(bytes32(0), RESOLVER_LABEL, address(this));
        ens.setResolver(resolverNode, address(publicResolver));
        publicResolver.setAddr(resolverNode, address(publicResolver));

        // Create a FIFS registrar for the TLD
        fifsRegistrar = new FIFSRegistrar(ens, namehash(bytes32(0), TLD_LABEL));

        ens.setSubnodeOwner(bytes32(0), TLD_LABEL, address(this));

        // Construct a new reverse registrar and point it at the public resolver
//        reverseRegistrar = new ReverseRegistrar(
//            ens
//        );

        // Set up the reverse registrar
//        ens.setSubnodeOwner(bytes32(0), REVERSE_REGISTRAR_LABEL, address(this));
//        ens.setSubnodeOwner(
//            namehash(bytes32(0), REVERSE_REGISTRAR_LABEL),
//            ADDR_LABEL,
//            address(reverseRegistrar)
//        );
    }

    //    /**
    //       * @dev Sets the record for a node.
    //     * @param node The node to update.
    //     * @param owner The address of the new owner.
    //     * @param resolver The address of the resolver.
    //     * @param ttl The TTL in seconds.
    //     */
    //    function setRecord(
    //        bytes32 node,
    //        address owner,
    //        address resolver,
    //        uint64 ttl
    //    ) public {
    //        ens.setRecord(node, owner, resolver, ttl);
    //    }
    //    /**
    //     * @dev Sets the record for a subnode.
    //     * @param node The parent node.
    //     * @param label The hash of the label specifying the subnode.
    //     * @param owner The address of the new owner.
    //     * @param resolver The address of the resolver.
    //     * @param ttl The TTL in seconds.
    //     */
    //    function setSubnodeRecord(
    //        bytes32 node,
    //        bytes32 label,
    //        address owner,
    //        address resolver,
    //        uint64 ttl
    //    ) public {
    //        ens.setSubnodeRecord(node, label, owner, resolver, ttl);
    //    }
    //
    //    /**
    //     * @dev Transfers ownership of a node to a new address. May only be called by the current owner of the node.
    //     * @param node The node to transfer ownership of.
    //     * @param owner The address of the new owner.
    //     */
    //    function setOwner(bytes32 node, address owner) public {
    //        ens.setOwner(node, owner);
    //    }
    //
    //    /**
    //     * @dev Transfers ownership of a subnode keccak256(node, label) to a new address. May only be called by the owner of the parent node.
    //     * @param node The parent node.
    //     * @param label The hash of the label specifying the subnode.
    //     * @param owner The address of the new owner.
    //     */
    //    function setSubnodeOwner(
    //        bytes32 node,
    //        bytes32 label,
    //        address owner
    //    ) public returns (bytes32) {
    //        return ens.setSubnodeOwner(node, label, owner);
    //    }
    //
    //    /**
    //     * @dev Sets the resolver address for the specified node.
    //     * @param node The node to update.
    //     * @param resolver The address of the resolver.
    //     */
    //    function setResolver(bytes32 node, address resolver) public {
    //        ens.setResolver(node, resolver);
    //    }
    //
    //    /**
    //     * Returns the address associated with an ENS node.
    //     * @param node The ENS node to query.
    //     * @return The associated address.
    //     */
    ////    function addr(bytes32 node)
    ////    public
    ////    view
    ////    virtual
    ////    override
    ////    returns (address payable)
    ////    {
    ////        bytes memory a = addr(node, COIN_TYPE_ETH);
    ////        if (a.length == 0) {
    ////            return payable(0);
    ////        }
    ////        return bytesToAddress(a);
    ////    }
    //
    //    /**
    //     * @dev Sets the TTL for the specified node.
    //     * @param node The node to update.
    //     * @param ttl The TTL in seconds.
    //     */
    //    function setTTL(bytes32 node, uint64 ttl) public {
    //        ens.setTTL(node, ttl);
    //    }
    //
    //    /**
    //     * @dev Enable or disable approval for a third party ("operator") to manage
    //     *  all of `msg.sender`'s ENS records. Emits the ApprovalForAll event.
    //     * @param operator Address to add to the set of authorized operators.
    //     * @param approved True if the operator is approved, false to revoke approval.
    //     */
    //    function setApprovalForAll(address operator, bool approved)
    //    public
    //    {
    //        ens.setApprovalForAll(operator, approved);
    //    }
    //
    //    /**
    //     * @dev Returns the address that owns the specified node.
    //     * @param node The specified node.
    //     * @return address of the owner.
    //     */
    //    function owner(bytes32 node) public view returns (address) {
    //        return ens.owner(node);
    //    }
    //
    //    /**
    //     * @dev Returns the address of the resolver for the specified node.
    //     * @param node The specified node.
    //     * @return address of the resolver.
    //     */
    //    function resolver(bytes32 node) public view returns (address) {
    //        return ens.resolver(node);
    //    }
    //
    //    /**
    //     * @dev Returns the TTL of a node, and any records associated with it.
    //     * @param node The specified node.
    //     * @return ttl of the node.
    //     */
    //    function ttl(bytes32 node) public view returns (uint64) {
    //        return ens.ttl(node);
    //    }
    //
    //    /**
    //     * @dev Returns whether a record has been imported to the registry.
    //     * @param node The specified node.
    //     * @return Bool if record exists
    //     */
    //    function recordExists(bytes32 node)
    //    public
    //    view
    //    returns (bool)
    //    {
    //        return ens.recordExists(node);
    //    }
    //
    //    /**
    //     * @dev Query if an address is an authorized operator for another address.
    //     * @param owner The address that owns the records.
    //     * @param operator The address that acts on behalf of the owner.
    //     * @return True if `operator` is an approved operator for `owner`, false otherwise.
    //     */
    //    function isApprovedForAll(address owner, address operator)
    //    external
    //    view
    //    returns (bool)
    //    {
    //        return ens.isApprovedForAll(owner, operator);
    //    }
}