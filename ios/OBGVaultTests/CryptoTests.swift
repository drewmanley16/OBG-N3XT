import XCTest
@testable import OBGVault

final class CryptoTests: XCTestCase {
    /// A signature produced by the Speculos emulator (Ledger Flex, Ethereum app 1.22.3, default seed).
    func testRecoversEmulatorLedgerAddress() {
        let message = ["OBG Health Vault consent", "Verifier: Campus Pharmacy", "Share: medications",
                       "Prove: penicillin_allergy", "Expires: 2026-10-07 19:30 UTC", "Request: test1"].joined(separator: "\n")
        let sig = Data(hex: "96825b66f3919ac79c2db24812b252370186b4bb6250cdeca803b14d72f76080"
            + "6602bcb9d2d6f84b8f4374ad682491118b931322cdee631aa73bc7d02efd5eef1b")!
        XCTAssertEqual(Ethereum.recoverAddress(message: message, signature: sig), "0xdad77910dbdfde764fc21fcd4e74d71bbaca6d8d")
    }

    func testPersonalSignAPDUChunking() {
        let apdus = EthereumAPDU.signPersonalMessage(Data(repeating: 0x41, count: 600))
        XCTAssertEqual(apdus.count, 3)
        XCTAssertEqual(apdus[0][2], 0x00)
        XCTAssertEqual(apdus[1][2], 0x80)
        XCTAssertTrue(apdus.allSatisfy { $0.count <= 5 + 255 })
    }

    func testEndToEndPresentationVerifies() async throws {
        let (presentation, issuer, engine) = try await makePresentation()
        let v = Verifier.verify(presentation, trustedIssuerKey: issuer.publicKey, engine: engine)
        XCTAssertTrue(v.ok, v.checks.filter { !$0.ok }.map(\.label).joined(separator: ", "))
        XCTAssertEqual(v.revealed.map(\.claim), [.covid19UpToDate])
        XCTAssertEqual(v.hiddenCount, Claim.allCases.count - 1)
    }

    func testConsentIsPlainASCII() async throws {
        let (p, _, _) = try await makePresentation()
        XCTAssertTrue(p.consentText.unicodeScalars.allSatisfy { $0.isASCII && ($0.value >= 0x20 || $0 == "\n") }, p.consentText)
    }

    func testTamperedClaimFails() async throws {
        var (p, issuer, engine) = try await makePresentation()
        p = Presentation(context: p.context, engine: p.engine, issuer: p.issuer, issuerPublicKey: p.issuerPublicKey, holder: p.holder,
                         validUntil: p.validUntil, digests: p.digests, issuerSignature: p.issuerSignature,
                         revealed: [Disclosure(claim: .covid19UpToDate, value: !p.revealed[0].value, salt: p.revealed[0].salt)],
                         consentText: p.consentText, ledgerSignature: p.ledgerSignature)
        XCTAssertFalse(Verifier.verify(p, trustedIssuerKey: issuer.publicKey, engine: engine).ok)
    }

    func testUntrustedIssuerFails() async throws {
        let (p, _, engine) = try await makePresentation()
        XCTAssertFalse(Verifier.verify(p, trustedIssuerKey: Issuer.make().publicKey, engine: engine).ok)
    }

    func testSignatureFromOtherKeyFails() async throws {
        var (p, issuer, engine) = try await makePresentation()
        p.ledgerSignature = try Ethereum.signPersonalMessage(p.consentText, privateKey: Data((1...32).map { UInt8($0) }))
        XCTAssertFalse(Verifier.verify(p, trustedIssuerKey: issuer.publicKey, engine: engine).ok)
    }

    private func makePresentation() async throws -> (Presentation, Issuer, ProofEngine) {
        let ledger = SimulatedLedger()
        let issuer = Issuer.make()
        let engine = SaltedHashEngine()
        let credential = try engine.issue(record: .sample, holder: try await ledger.address(), issuer: issuer)
        let ctx = PresentationContext(requestID: "r1", verifier: "McDonald Theatre", nonce: "n", expiresAt: .now.addingTimeInterval(300))
        var p = try engine.present(credential, reveal: [.covid19UpToDate], context: ctx)
        p.consentText = Consent.text(for: p)
        p.ledgerSignature = try await ledger.signPersonalMessage(p.consentText)
        return (p, issuer, engine)
    }
}
