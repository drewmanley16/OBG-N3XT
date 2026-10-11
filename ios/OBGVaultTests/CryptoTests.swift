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

    /// Must match web/src/lib/messages.ts exactly, or the school's verifier rejects the signature.
    func testMessagesMatchWebVerifier() {
        let hash = "e642f79bebe73ab6e80883b45a4e66c09f676a04aaaaaaaaaaaaaaaaaaaaaaaa"
        XCTAssertEqual(Consent.registration(name: "Jordan Rivera", requirementSet: "oregon-k12-2026", proofHash: hash),
                       "OBG Vault registration\nStudent: Jordan Rivera\nRequirements: oregon-k12-2026\nProof: e642f79bebe73ab6e80883b45a4e66c0")
        let exp = Date(timeIntervalSince1970: 1_791_766_200) // 2026-10-12 00:50 UTC
        XCTAssertEqual(Consent.release(school: "South Eugene High School", proofHash: hash, nonce: "0123456789abcdef", expiresAt: exp),
                       "OBG Vault release\nSend proof to: South Eugene High School\nProof: e642f79bebe73ab6e80883b45a4e66c0\nRequest: 01234567\nExpires: 2026-10-12 00:50 UTC")
        XCTAssertEqual(Consent.request(school: "South Eugene High School", student: "Jordan Rivera", requirementSet: "oregon-k12-2026", nonce: "0123456789abcdef"),
                       "OBG Vault request\nFrom: South Eugene High School\nStudent: Jordan Rivera\nProve: oregon-k12-2026\nRequest: 01234567")
        XCTAssertEqual(Consent.iso(exp), "2026-10-12T00:50:00Z")
    }

    func testExpiryIsWholeMinutes() {
        let e = Consent.expiry(from: Date(timeIntervalSince1970: 1_000_000_037), minutes: 15)
        XCTAssertEqual(e.timeIntervalSince1970.truncatingRemainder(dividingBy: 60), 0)
        XCTAssertEqual(e.timeIntervalSince1970, 1_000_000_020 + 900)
    }

    func testSampleRecordMeetsOregonK12() {
        XCTAssertTrue(ImmunizationRecord.sample.meets(.oregonK12))
        XCTAssertEqual(ImmunizationRecord.sample.doseCounts, [5, 4, 2, 2, 3, 2, 1])
    }

    func testSimulatedLedgerSignatureRecovers() async throws {
        let ledger = SimulatedLedger()
        let message = Consent.registration(name: "A", requirementSet: "r", proofHash: "ff")
        let sig = try await ledger.signPersonalMessage(message)
        let address = try await ledger.address()
        XCTAssertEqual(Ethereum.recoverAddress(message: message, signature: sig), address)
    }
}
