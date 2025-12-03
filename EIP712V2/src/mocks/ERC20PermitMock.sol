// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { SignatureRouter } from "../libraries/SignatureRouter.sol";

contract ERC20PermitMock {
    error NotOwner();
    error ZeroOwnerAddr();
    error ZeroSpenderAddr();
    error SpenderNotContract();
    error InvalidValue();
    error ExpiredRequest();
    error Permit_BadSig();
    error ZeroFromAddr();
    error ZeroToAddr();
    error InsufficientValue();
    error InsufficientAllowance();

    struct Permit {
        address realOwner;
        address spender;
        uint256 value;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    bytes32 internal constant STRUCT_HASH = keccak256(
        "Permit(address owner,address spender,uint256 value,uint256 deadline,uint256 nonce)"
    );
    bytes32 internal constant DOMAIN_HASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    bytes32 internal constant NAME_HASH = keccak256(bytes("ERC20PermitMock"));
    bytes32 internal constant VER_HASH = keccak256(bytes("1"));

    address public realOwner;
    mapping(address => uint256) public nonces;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor() {
        realOwner = msg.sender;
    }

    modifier onlyOwner() {
        if(msg.sender != realOwner) {
            revert NotOwner();
        }
        _;
    }

    event Mint(address indexed who, uint256 amount);
    event Submitted(address indexed owner, address indexed spender, uint256 value, uint256 deadline);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    function mintTokenOf(address who, uint256 amount) external onlyOwner {
        if(who == address(0)) {
            revert ZeroOwnerAddr();
        }
        balanceOf[who] += amount;
        emit Mint(who, amount);
    }

    function _structHash(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline
    ) internal view returns(bytes32) {
        uint256 nonce = nonces[owner];
        return keccak256(
            abi.encode(
                STRUCT_HASH, owner, spender, value, deadline, nonce
            )
        );
    }

    function _domainHash() internal view returns(bytes32) {
        return keccak256(
            abi.encode(
                DOMAIN_HASH,
                keccak256(bytes("ERC20PermitMock")),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }

    function _digest(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline
    ) internal view returns(bytes32) {
        bytes32 domainHash = _domainHash();
        bytes32 structHash = _structHash(owner, spender, value, deadline);
        return keccak256(
            abi.encodePacked(
                "\x19\x01", domainHash, structHash
            )
       );
    }

    function tokenDigest(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline
    ) external view returns(bytes32) {
        return _digest(owner, spender, value, deadline);
    }

    function _validateSignature(
        address owner,
        bytes32 dig,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view returns(bool) {
        return SignatureRouter._tryRecoverOr1271(owner, dig, v, r, s);
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        if(owner == address(0)) {
            revert ZeroOwnerAddr();
        }
        if(spender == address(0)) {
            revert ZeroSpenderAddr();
        }
        if(spender.code.length == 0) {
            revert SpenderNotContract();
        }
        if(value > balanceOf[owner]) {
            revert InvalidValue();
        }
        if(deadline < block.timestamp) {
            revert ExpiredRequest();
        }
        bytes32 dig = _digest(owner, spender, value, deadline);
        if(!_validateSignature(owner, dig, v, r, s)) {
            revert Permit_BadSig();
        }
        nonces[owner] = nonces[owner] + 1;
        allowance[owner][spender] = value;
        emit Submitted(owner, spender, value, deadline);
    }

    function transferFrom(address from, address to, uint256 amount) external {
        if(from == address(0)) {
            revert ZeroFromAddr();
        }
        if(to == address(0)) {
            revert ZeroToAddr();
        }
        if(allowance[from][msg.sender] < amount) {
            revert InsufficientAllowance();
        }
        if(balanceOf[from] < amount) {
            revert InsufficientValue();
        }
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }
}