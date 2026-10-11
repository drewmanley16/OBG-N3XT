import CryptoSwift
import Foundation
import P256K

/// Ethereum personal_sign (EIP-191) helpers, used to check that a consent was
/// signed by the patient's Ledger.
enum Ethereum {
    static func keccak256(_ bytes: [UInt8]) -> [UInt8] {
        SHA3(variant: .keccak256).calculate(for: bytes)
    }

    /// The hash the Ledger Ethereum app signs for a personal message.
    static func personalMessageDigest(_ message: String) -> [UInt8] {
        let m = Array(message.utf8)
        return keccak256(Array("\u{19}Ethereum Signed Message:\n\(m.count)".utf8) + m)
    }

    /// Lowercase 0x address from a 65-byte uncompressed public key.
    static func address(uncompressedPublicKey key: Data) -> String {
        "0x" + Data(keccak256(Array(key.dropFirst())).suffix(20)).hex
    }

    /// Recovers the signer's address from a 65-byte r‖s‖v signature, or nil.
    static func recoverAddress(message: String, signature: Data) -> String? {
        guard signature.count == 65 else { return nil }
        let v = Int32(signature[64])
        let recoveryID = v >= 27 ? v - 27 : v
        guard (0...3).contains(recoveryID),
              let sig = try? P256K.Recovery.ECDSASignature(compactRepresentation: signature.prefix(64), recoveryId: recoveryID)
        else { return nil }
        let key = P256K.Recovery.PublicKey(HashDigest(personalMessageDigest(message)), signature: sig, format: .uncompressed)
        return address(uncompressedPublicKey: key.dataRepresentation)
    }

    /// Signs like a Ledger would. Only used by the simulated Ledger.
    static func signPersonalMessage(_ message: String, privateKey: Data) throws -> Data {
        let key = try P256K.Recovery.PrivateKey(dataRepresentation: privateKey)
        let compact = key.signature(for: HashDigest(personalMessageDigest(message))).compactRepresentation
        return compact.signature + Data([UInt8(27 + compact.recoveryId)])
    }

    static func address(privateKey: Data) throws -> String {
        let key = try P256K.Recovery.PrivateKey(dataRepresentation: privateKey, format: .uncompressed)
        return address(uncompressedPublicKey: key.publicKey.dataRepresentation)
    }
}
