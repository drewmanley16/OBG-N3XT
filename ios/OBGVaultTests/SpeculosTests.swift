import XCTest
@testable import OBGVault

/// Talks to the real Ledger emulator. Skipped unless it's running (scripts/speculos.sh).
/// Someone (or a script) must approve on the device screen while this runs.
final class SpeculosTests: XCTestCase {
    func testSignRegistrationOnEmulator() async throws {
        let ledger = SpeculosLedger()
        let address: String
        do { address = try await ledger.address() } catch { throw XCTSkip("Speculos not reachable: \(error)") }
        let message = Consent.registration(name: "Jordan Rivera", requirementSet: "oregon-k12-2026", proofHash: String(repeating: "ab", count: 32))
        let sig = try await ledger.signPersonalMessage(message)
        XCTAssertEqual(Ethereum.recoverAddress(message: message, signature: sig), address)
    }
}
