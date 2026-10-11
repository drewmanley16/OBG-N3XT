import CryptoKit
import Foundation

// MARK: - The seam for zero-knowledge proofs

/// Binds a presentation to one request, so it can't be replayed elsewhere.
struct PresentationContext: Codable, Hashable, Sendable {
    let requestID: String
    let verifier: String
    let nonce: String
    let expiresAt: Date
}

/// Issues credentials, derives presentations that reveal only some claims, and
/// verifies them. Swap the implementation for BBS (or another ZK scheme) later
/// without touching the app: everything else talks to this protocol.
protocol ProofEngine: Sendable {
    var name: String { get }
    func issue(record: PatientRecord, holder: String, issuer: Issuer) throws -> Credential
    func present(_ credential: Credential, reveal claims: [Claim], context: PresentationContext) throws -> Presentation
    func verify(_ presentation: Presentation, trustedIssuerKey: Data) -> Bool
}

/// Health department that signs credentials.
struct Issuer: Sendable {
    let name: String
    let signingKey: P256.Signing.PrivateKey
    var publicKey: Data { signingKey.publicKey.rawRepresentation }

    static func make(name: String = "Lane County Public Health") -> Issuer {
        Issuer(name: name, signingKey: .init())
    }
}

struct Disclosure: Codable, Hashable, Sendable {
    let claim: Claim
    let value: Bool
    let salt: String
}

/// Held only by the patient.
struct Credential: Codable, Sendable {
    let issuer: String
    let issuerPublicKey: Data
    let holder: String // patient's Ledger address
    let validUntil: Date
    let digests: [String] // one per claim; values hidden behind salted hashes
    let issuerSignature: Data
    let disclosures: [Disclosure] // the patient's private openings for every claim

    func value(of claim: Claim) -> Bool? { disclosures.first { $0.claim == claim }?.value }
}

/// What the provider receives: revealed claims plus proof material, and the
/// patient's Ledger signature over the consent that names this exact proof.
struct Presentation: Codable, Sendable {
    let context: PresentationContext
    let engine: String
    let issuer: String
    let issuerPublicKey: Data
    let holder: String
    let validUntil: Date
    let digests: [String]
    let issuerSignature: Data
    let revealed: [Disclosure]
    var consentText: String = ""
    var ledgerSignature: Data = Data()

    /// Fingerprint of everything except the consent and Ledger signature.
    var fingerprint: String {
        var copy = self
        copy.consentText = ""
        copy.ledgerSignature = Data()
        let data = (try? JSONEncoder.canonical.encode(copy)) ?? Data()
        return SHA256.hash(data: data).prefix(8).map { String(format: "%02x", $0) }.joined()
    }
}

extension JSONEncoder {
    static var canonical: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        e.dateEncodingStrategy = .secondsSince1970
        return e
    }
}

// MARK: - Placeholder engine: salted-hash selective disclosure

/// Real selective disclosure, but not zero-knowledge. The issuer signs salted
/// hashes of every claim; the patient opens only the requested ones. Hidden
/// claims stay hidden, but the same digests appear in every presentation, so
/// providers could link them. BBS fixes that: each proof looks fresh.
struct SaltedHashEngine: ProofEngine {
    let name = "salted-hash-v1 (placeholder for BBS)"

    private static func digest(_ d: Disclosure) -> String {
        SHA256.hash(data: Data("\(d.salt)|\(d.claim.rawValue)=\(d.value)".utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func signedPayload(issuer: String, holder: String, validUntil: Date, digests: [String]) -> Data {
        let fields = ["issuer=\(issuer)", "holder=\(holder)", "valid_until=\(Int(validUntil.timeIntervalSince1970))"] + digests.sorted()
        return Data(fields.joined(separator: "\n").utf8)
    }

    func issue(record: PatientRecord, holder: String, issuer: Issuer) throws -> Credential {
        let attested = record.attest()
        let disclosures = Claim.allCases.map { Disclosure(claim: $0, value: attested[$0] ?? false, salt: randomHex(16)) }
        let digests = disclosures.map(Self.digest)
        // Short-lived, like CoronaCheck: refresh instead of revocation lists.
        let validUntil = Date.now.addingTimeInterval(30 * 86_400)
        let holder = holder.lowercased()
        let signature = try issuer.signingKey.signature(
            for: Self.signedPayload(issuer: issuer.name, holder: holder, validUntil: validUntil, digests: digests))
        return Credential(issuer: issuer.name, issuerPublicKey: issuer.publicKey, holder: holder, validUntil: validUntil,
                          digests: digests, issuerSignature: signature.rawRepresentation, disclosures: disclosures)
    }

    func present(_ credential: Credential, reveal claims: [Claim], context: PresentationContext) throws -> Presentation {
        Presentation(context: context, engine: name, issuer: credential.issuer, issuerPublicKey: credential.issuerPublicKey,
                     holder: credential.holder, validUntil: credential.validUntil, digests: credential.digests,
                     issuerSignature: credential.issuerSignature,
                     revealed: credential.disclosures.filter { claims.contains($0.claim) })
    }

    func verify(_ p: Presentation, trustedIssuerKey: Data) -> Bool {
        guard p.issuerPublicKey == trustedIssuerKey,
              let key = try? P256.Signing.PublicKey(rawRepresentation: trustedIssuerKey),
              let sig = try? P256.Signing.ECDSASignature(rawRepresentation: p.issuerSignature),
              key.isValidSignature(sig, for: Self.signedPayload(issuer: p.issuer, holder: p.holder, validUntil: p.validUntil, digests: p.digests))
        else { return false }
        return p.revealed.allSatisfy { p.digests.contains(Self.digest($0)) }
    }
}
