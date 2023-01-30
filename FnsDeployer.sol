pragma solidity >=0.8.4;

import "./ensdomains/ens-contracts/contracts/ethregistrar/PriceOracle.sol";
import "./ensdomains/ens-contracts/contracts/ethregistrar/StablePriceOracle.sol";
import "./ensdomains/ens-contracts/contracts/ethregistrar/BaseRegistrarImplementation.sol";
import "./ensdomains/ens-contracts/contracts/ethregistrar/StringUtils.sol";
import "./ensdomains/ens-contracts/contracts/resolvers/Resolver.sol";
import "./ensdomains/ens-contracts/contracts/resolvers/profiles/AddrResolver.sol";
import "./ensdomains/ens-contracts/contracts/registry/ENSRegistry.sol";
import "./ensdomains/ens-contracts/contracts/resolvers/OwnedResolver.sol";

contract MyOracle {
    int256 value;

    constructor(int _value) public {
        set(_value);
    }

    function set(int _value) public {
        value = _value;
    }

    function latestAnswer() public returns (int256) {
        return value;
    }
}


/**
 * @dev A registrar controller for registering and renewing names at fixed cost.
 */
contract FnsDeployer is Ownable {
    using StringUtils for *;
    uint[] private rentPrices = new uint[](6); //租赁定价系数(域名越短，系数越大)

    string private constant   LTD_NAME = 'fil';
    string private constant   RESOLVER_NAME = 'resolver';
    string private constant   REVERSE_NAME = 'reverse';
    string private constant   ADDR_NAME = 'addr';
    bytes32 private constant  TLD_LABEL = keccak256(bytes(LTD_NAME));
    bytes32 private constant  RESOLVER_LABEL = keccak256(bytes(RESOLVER_NAME));
    bytes32 private constant  REVERSE_REGISTRAR_LABEL = keccak256(bytes(REVERSE_NAME));
    bytes32 private constant  ADDR_LABEL = keccak256(bytes(ADDR_NAME));
    uint constant private     MIN_REGISTRATION_DURATION = 28 days;

    bytes4 constant private INTERFACE_META_ID = bytes4(keccak256("supportsInterface(bytes4)"));
    bytes4 constant private COMMITMENT_CONTROLLER_ID = bytes4(
        keccak256("rentPrice(string,uint256)") ^
        keccak256("available(string)") ^
        keccak256("makeCommitment(string,address,bytes32)") ^
        keccak256("commit(bytes32)") ^
        keccak256("register(string,address,uint256,bytes32)") ^
        keccak256("renew(string,uint256)")
    );

    bytes4 constant private COMMITMENT_WITH_CONFIG_CONTROLLER_ID = bytes4(
        keccak256("registerWithConfig(string,address,uint256,bytes32,address,address)") ^
        keccak256("makeCommitmentWithConfig(string,address,bytes32,address,address)")
    );

    bytes32 private baseNode; //根节点
    MyOracle private oracle; //价格生成器
    ENSRegistry private ens; //ENS注册器
    BaseRegistrarImplementation private  base; //基本注册器实现
    PriceOracle private prices; //定价预言机
    OwnedResolver private publicResolver;
    uint private minCommitmentAge;
    uint private maxCommitmentAge;

    mapping(bytes32 => uint) public commitments;

    event FnsNameRegistered(string name, bytes32 indexed label, address indexed owner, uint cost, uint expires);
    event FnsNameRenewed(string name, bytes32 indexed label, uint cost, uint expires);
    event FnsNewPriceOracle(address indexed oracle);

    constructor() public {
        minCommitmentAge = 0;
        maxCommitmentAge = 0;
        rentPrices = [10000000, 100000, 10000, 1000, 100, 0]; //定价系数
        oracle = new MyOracle(7);
        prices = new StablePriceOracle(AggregatorInterface(address(oracle)), rentPrices);
        baseNode = namehash(bytes32(0), TLD_LABEL);
        ens = new ENSRegistry();
        publicResolver = new OwnedResolver();
        base = new BaseRegistrarImplementation(ens, baseNode);
        ens.setSubnodeRecord(bytes32(0), TLD_LABEL, address(base), address(publicResolver), 0);
        base.addController(address(this));
    }

    function namehash(bytes32 node, bytes32 label) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(node, label));
    }

    function keccak(string memory name) public pure returns (bytes32) {
        return keccak256(bytes(name));
    }

    function rentPrice(string memory name, uint duration) view public returns (uint) {
        bytes32 hash = keccak256(bytes(name));
        return prices.price(name, base.nameExpires(uint256(hash)), duration);
    }

    function valid(string memory name) public pure returns (bool) {
        return name.strlen() >= 3;
    }

    function available(string memory name) public view returns (bool) {
        bytes32 label = keccak256(bytes(name));
        return valid(name) && base.available(uint256(label));
    }

    function addr(string memory name) public view returns (address) {
        bytes32 label = keccak256(bytes(name));
        bytes32 node = namehash(baseNode, label);
        address resolver = ens.resolver(node);
        if(resolver == address(0)) {
            return address(0);
        }
        return Resolver(resolver).addr(node);
    }

    function ownerOf(string memory name) public view returns (address) {
        bytes32 label = keccak256(bytes(name));
        bytes32 node = namehash(baseNode, label);
        return ens.owner(node);
    }

    function resolver(string memory name) public view returns (address) {
        bytes32 label = keccak256(bytes(name));
        bytes32 node = namehash(baseNode, label);
        return ens.resolver(node);
    }

    /*---------------------------------------------------------------------------------------------------------------*/

    function makeCommitment(string memory name, address owner, bytes32 secret) pure public returns (bytes32) {
        return makeCommitmentWithConfig(name, owner, secret, address(0), address(0));
    }

    function makeCommitmentWithConfig(string memory name, address owner, bytes32 secret, address resolver, address addr) pure public returns (bytes32) {
        bytes32 label = keccak256(bytes(name));
        if (resolver == address(0) && addr == address(0)) {
            return keccak256(abi.encodePacked(label, owner, secret));
        }
        require(resolver != address(0));
        return keccak256(abi.encodePacked(label, owner, resolver, addr, secret));
    }

    function commit(bytes32 commitment) public {
        require(commitments[commitment] + maxCommitmentAge < block.timestamp);
        commitments[commitment] = block.timestamp;
    }

    function setResolver(string memory name, address resolver) public {
        bytes32 label = keccak256(bytes(name));
        bytes32 node = namehash(baseNode, label);
        address owner = ens.owner(node);
        require(owner == msg.sender, "msg sender is not domain owner");
        require(resolver != address(0), "name resolver is empty");
        ens.setResolver(node, resolver);
    }

    function setAddr(string memory name, address addr) public {
        bytes32 label = keccak256(bytes(name));
        bytes32 node = namehash(baseNode, label);
        address owner = ens.owner(node);
        require(owner == msg.sender, "msg sender is not domain owner");
        address resolver = ens.resolver(node);
        require(resolver != address(0), "name resolver is empty");
        Resolver(resolver).setAddr(node, addr);
    }

    function register(string calldata name, address owner, uint duration, bytes32 secret) external payable {
        registerWithConfig(name, owner, duration, secret, address(publicResolver), owner);
    }

    //    event FnsLog(string log);
    function registerWithConfig(string memory name, address owner, uint duration, bytes32 secret, address resolver, address addr) public payable {
        bytes32 commitment = makeCommitmentWithConfig(name, owner, secret, resolver, addr);
        uint cost = _consumeCommitment(name, duration, commitment);

        bytes32 label = keccak256(bytes(name));
        uint256 tokenId = uint256(label);

        uint expires;
        if (resolver != address(0)) {
            // Set this contract as the (temporary) owner, giving it
            // permission to set up the resolver.
            expires = base.register(tokenId, address(this), duration);

            // The nodehash of this label
            bytes32 nodehash = keccak256(abi.encodePacked(base.baseNode(), label));

            // Set the resolver
            base.ens().setResolver(nodehash, resolver);

            // Configure the resolver
            if (addr != address(0)) {
                Resolver(resolver).setAddr(nodehash, addr);
            }

            // Now transfer full ownership to the expeceted owner
            base.reclaim(tokenId, owner);
            base.transferFrom(address(this), owner, tokenId);
        } else {
            require(addr == address(0), "address must be 0");
            expires = base.register(tokenId, owner, duration);
        }
        emit FnsNameRegistered(name, label, owner, cost, expires);
        //Refund any extra payment
        if (msg.value > cost) {
            payable(msg.sender).transfer(msg.value - cost);
        }
    }

    function renew(string calldata name, uint duration) external payable {
        uint cost = rentPrice(name, duration);
        require(msg.value >= cost);

        bytes32 label = keccak256(bytes(name));
        uint expires = base.renew(uint256(label), duration);

        if (msg.value > cost) {
            payable(msg.sender).transfer(msg.value - cost);
        }

        emit FnsNameRenewed(name, label, cost, expires);
    }

    function setPriceOracle(PriceOracle _prices) public onlyOwner {
        prices = _prices;
        emit FnsNewPriceOracle(address(prices));
    }

    function setCommitmentAges(uint _minCommitmentAge, uint _maxCommitmentAge) public onlyOwner {
        minCommitmentAge = _minCommitmentAge;
        maxCommitmentAge = _maxCommitmentAge;
    }

    function withdraw() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    function supportsInterface(bytes4 interfaceID) external pure returns (bool) {
        return interfaceID == INTERFACE_META_ID ||
        interfaceID == COMMITMENT_CONTROLLER_ID ||
        interfaceID == COMMITMENT_WITH_CONFIG_CONTROLLER_ID;
    }

    function _consumeCommitment(string memory name, uint duration, bytes32 commitment) internal returns (uint256) {
        // Require a valid commitment
        // require(commitments[commitment] + minCommitmentAge <= block.timestamp, "min commit age not valid");

        // If the commitment is too old, or the name is registered, stop
        //require(commitments[commitment] + maxCommitmentAge > block.timestamp, "max commit age not valid");
        require(available(name), "name is registered");

        delete (commitments[commitment]);

        uint cost = rentPrice(name, duration);
        require(duration >= MIN_REGISTRATION_DURATION, "duration is less than min registration duration");
        require(msg.value >= cost, "msg.value is less than cost");

        return cost;
    }
}
