import XCTest
@testable import OBGVault

/// Talks to the real Ledger emulator. Skipped unless it's running (scripts/speculos.sh).
/// Someone (or a script) must approve on the device screen while this runs.
final class SpeculosTests: XCTestCase {
    func testSignConsentOnEmulator() async throws {
        let ledger = SpeculosLedger()
        let address: String
        do { address = try await ledger.address() } catch { throw XCTSkip("Speculos not reachable: \(error)") }

        let issuer = Issuer.make()
        let engine = SaltedHashEngine()
        let credential = try engine.issue(record: .sample, holder: address, issuer: issuer)
        let ctx = PresentationContext(requestID: "it1", verifier: "McDonald Theatre", nonce: randomHex(8),
                                      expiresAt: .now.addingTimeInterval(300))
        var p = try engine.present(credential, reveal: [.covid19UpToDate], context: ctx)
        p.consentText = Consent.text(for: p)
        p.ledgerSignature = try await ledger.signPersonalMessage(p.consentText)

        let v = Verifier.verify(p, trustedIssuerKey: issuer.publicKey, engine: engine)
        XCTAssertTrue(v.ok, v.checks.filter { !$0.ok }.map(\.label).joined(separator: ", "))
    }
}
