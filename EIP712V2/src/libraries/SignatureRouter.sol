// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { ECDSA } from "../../lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import { ISignatureValidator } from "../interfaces/ISignatureValidator.sol";

library SignatureRouter {
    using ECDSA for bytes32;

    bytes4 internal constant MAGIC = 0x1626ba7e;
    bytes4 internal constant SEL = ISignatureValidator.isValidSignature.selector;

    function tryRecoverOr1271(
        address signer,
        bytes32 dig,
        bytes calldata sig
    ) internal view returns(bool) {
        if(signer.code.length == 0) {
            address recovered = dig.recover(sig);
            return signer == recovered;
        }
        (bool ok, bytes memory ret) =
            signer.staticcall(
                abi.encodeWithSelector(SEL, dig, sig)
            );
        if(!ok || ret.length < 4 || bytes4(ret) != MAGIC) {
            return false;
        }
        return true;
    }

        function _tryRecoverOr1271(
        address signer,
        bytes32 dig,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view returns(bool) {
        if(signer.code.length == 0) {
            address recovered = dig.recover(v, r, s);
            return signer == recovered;
        }
        bytes memory sig = abi.encodePacked(r, s, v);
        (bool ok, bytes memory ret) =
            signer.staticcall(
                abi.encodeWithSelector(SEL, dig, sig)
            );
        if(!ok || ret.length < 4 || bytes4(ret) != MAGIC) {
            return false;
        }
        return true;
    }
}