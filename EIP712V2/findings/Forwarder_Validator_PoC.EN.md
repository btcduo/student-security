Short English Digest
The ForwarderV2 enforces signature verification, nonce incrementation, and clamping the gas limit into a safe range before relaying the transaction.
The DomainRegistry enforces that each (domainId, chainId) pair is immutable and maps to exactly one ForwarderV2 instance.

The system assumes that upstream callers may arbitrarily relay transactions without independently checking that the parameters are fresh, unexpired, and unused.
The system assumes that the privileged owner may misconfigure the DomainRegistry by pointing a domain to an incorrect or malicious forwarder address.

It mitigates replay attacks by binding the forwarder to the DomainRegistry entry and incrementing each sender’s nonce before mutating state.
It mitigates routing abuse by rejecting any transaction whose context address and chainId do not match the forwarder recorded in the DomainRegistry.

The SignatureRouter enforces signature verification for EOAs via ECDSA and for contract signers via ERC1271.
The system assumes that the contract signers can always return EIP-1271-compliannt magic value withou validating the provided parameters.
Responsibility for preventing such issues lie with the contract signer rather than with the SignatureRouter.
Any misconfigured or permissive implementation would enables fund loss at their own risks.