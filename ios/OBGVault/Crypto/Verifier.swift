import Foundation

/// The consent text the Ledger displays and signs. It names the proof's
/// fingerprint, so the signature covers exactly that proof.
/// Keep it plain ASCII: the Ledger shows anything else as hex.
enum Consent {
    private static let expiryFormat: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd HH:mm 'UTC'"
        return f
    }()

    static func text(for p: Presentation) -> String {
        let expiry = expiryFormat.string(from: p.context.expiresAt)
        return [
            "OBG Vault consent",
            "Provider: \(p.context.verifier)",
            "Prove: \(p.revealed.map(\.claim.label).joined(separator: "; "))",
            "Reveal nothing else",
            "Expires: \(expiry)",
            "Proof: \(p.fingerprint)",
        ].joined(separator: "\n")
    }
}

struct Verification: Sendable {
    struct Check: Identifiable, Sendable {
        let id = UUID()
        let label: String
        let ok: Bool
    }

    let checks: [Check]
    let revealed: [Disclosure]
    let hiddenCount: Int
    var ok: Bool { checks.allSatisfy(\.ok) }
}

/// Provider side: verify using only the presentation and the issuer's public key.
enum Verifier {
    static func verify(_ p: Presentation, trustedIssuerKey: Data, engine: ProofEngine, now: Date = .now) -> Verification {
        let signer = Ethereum.recoverAddress(message: p.consentText, signature: p.ledgerSignature)
        return Verification(
            checks: [
                .init(label: "Issued by \(p.issuer)", ok: p.issuerPublicKey == trustedIssuerKey),
                .init(label: "Proof valid against the issuer's signature", ok: engine.verify(p, trustedIssuerKey: trustedIssuerKey)),
                .init(label: "Approved on the holder's Ledger", ok: signer == p.holder),
                .init(label: "Ledger approval covers this exact proof", ok: p.consentText == Consent.text(for: p)),
                .init(label: "Credential still valid", ok: p.validUntil > now),
                .init(label: "Proof not expired", ok: p.context.expiresAt > now),
            ],
            revealed: p.revealed,
            hiddenCount: p.digests.count - p.revealed.count
        )
    }
}
