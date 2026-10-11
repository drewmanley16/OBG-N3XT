import Foundation
import Observation

/// Holds both sides of the demo in one app: the patient's wallet and the
/// provider. In production these are separate devices talking over a network;
/// the provider would only ever see `Grant.presentation`.
@MainActor @Observable
final class VaultStore {
    enum LedgerMode: String, CaseIterable, Identifiable {
        case emulator = "Emulator"
        case simulated = "Simulated"
        var id: String { rawValue }
    }

    var ledgerMode: LedgerMode = .emulator {
        didSet { if ledgerMode != oldValue { reset() } }
    }
    var ledger: LedgerSigner { ledgerMode == .emulator ? SpeculosLedger() : SimulatedLedger() }

    let engine: ProofEngine = SaltedHashEngine()
    let issuer = Issuer.make()
    /// Issuers the provider trusts, by public key.
    var trustedIssuerKey: Data { issuer.publicKey }

    private(set) var patientAddress: String?
    private(set) var credential: Credential?
    private(set) var requests: [AccessRequest] = []
    private(set) var grants: [Grant] = []
    private(set) var audit: [AuditEntry] = []

    // MARK: Patient

    /// Pair with the Ledger; the health department then issues a credential bound to it.
    func connectLedger() async throws {
        let address = try await ledger.address()
        if patientAddress != address {
            patientAddress = address
            log(.paired, "Patient", "Ledger \(address)")
            credential = try engine.issue(record: .sample, holder: address, issuer: issuer)
            log(.issued, issuer.name, "Vaccine credential bound to \(address)")
        }
    }

    /// Derive the proof, have the patient sign the consent on the Ledger, release it.
    func approve(_ requestID: String) async throws {
        if credential == nil { try await connectLedger() }
        guard let credential, let i = requests.firstIndex(where: { $0.id == requestID }), requests[i].status == .pending
        else { return }
        let request = requests[i]
        let context = PresentationContext(requestID: request.id, verifier: request.verifier, nonce: request.nonce,
                                          expiresAt: .now.addingTimeInterval(request.duration))
        var presentation = try engine.present(credential, reveal: request.claims, context: context)
        presentation.consentText = Consent.text(for: presentation)
        presentation.ledgerSignature = try await ledger.signPersonalMessage(presentation.consentText)

        guard Ethereum.recoverAddress(message: presentation.consentText, signature: presentation.ledgerSignature) == credential.holder
        else { throw ApprovalError.wrongSigner }

        let grant = Grant(id: randomHex(4), requestID: request.id, verifier: request.verifier, presentation: presentation)
        grants.insert(grant, at: 0)
        requests[i].status = .approved
        requests[i].grantID = grant.id
        log(.approved, request.verifier, "Proved \(request.claims.map(\.label).joined(separator: ", "))")
    }

    func deny(_ requestID: String) {
        guard let i = requests.firstIndex(where: { $0.id == requestID }) else { return }
        requests[i].status = .denied
        log(.denied, requests[i].verifier, requests[i].purpose)
    }

    // MARK: Provider

    func sendRequest(verifier: String, purpose: String, claims: [Claim], minutes: Int) {
        let request = AccessRequest(id: randomHex(4), verifier: verifier, purpose: purpose, claims: claims,
                                    duration: TimeInterval(minutes * 60), nonce: randomHex(16), createdAt: .now)
        requests.insert(request, at: 0)
        log(.requested, verifier, claims.map(\.label).joined(separator: ", "))
    }

    /// Nil once expired: the provider loses access.
    func verify(grantID: String) -> Verification? {
        guard let grant = grants.first(where: { $0.id == grantID }) else { return nil }
        guard grant.expiresAt > .now else {
            log(.expired, grant.verifier, "Tried to use an expired proof")
            return nil
        }
        log(.verified, grant.verifier, "Checked proof \(grant.id)")
        return Verifier.verify(grant.presentation, trustedIssuerKey: trustedIssuerKey, engine: engine)
    }

    // MARK: -

    private func reset() {
        patientAddress = nil
        credential = nil
        requests = []
        grants = []
        audit = []
    }

    private func log(_ event: AuditEntry.Event, _ actor: String, _ detail: String) {
        audit.insert(AuditEntry(at: .now, event: event, actor: actor, detail: detail), at: 0)
    }
}

enum ApprovalError: LocalizedError {
    case wrongSigner
    var errorDescription: String? { "That signature didn't come from the Ledger this credential is bound to." }
}
