import Foundation
import Observation
import Supabase

/// The student's app: onboarding (Epic import → ZK proof → Ledger-signed
/// registration in Supabase), then live school requests released via Ledger.
@MainActor @Observable
final class AppModel {
    enum LedgerMode: String, CaseIterable, Identifiable {
        case emulator = "Emulator"
        case simulated = "Simulated"
        var id: String { rawValue }
    }

    /// A school request after checking the school's Ledger signature.
    struct IncomingRequest: Identifiable {
        let row: ProofRequestRow
        let schoolVerified: Bool
        var id: UUID { row.id }
    }

    var ledgerMode: LedgerMode = .emulator
    var ledger: LedgerSigner { ledgerMode == .emulator ? SpeculosLedger() : SimulatedLedger() }
    private let db = AppConfig.supabase

    private(set) var registration: Registration? {
        didSet { save() }
    }
    private(set) var requests: [IncomingRequest] = []
    private var listening: Task<Void, Never>?

    init() {
        if ProcessInfo.processInfo.arguments.contains("-resetForUITest") { UserDefaults.standard.removeObject(forKey: "registration") }
        if let data = UserDefaults.standard.data(forKey: "registration") {
            registration = try? JSONDecoder().decode(Registration.self, from: data)
        }
    }

    // MARK: Onboarding

    func connectLedger() async throws -> String {
        try await ledger.address()
    }

    /// Simulated Epic (MyChart) import for the demo.
    func importFromEpic() async throws -> ImmunizationRecord {
        try await Task.sleep(for: .seconds(2.2))
        return .sample
    }

    func generateProof(record: ImmunizationRecord, holder: String) async throws -> Prover.Result {
        try await Prover.prove(record: record, holder: holder)
    }

    /// The Ledger signs the proof hash; the registry row lands in Supabase.
    func register(name: String, address: String, record: ImmunizationRecord, proof: Prover.Result) async throws {
        let message = Consent.registration(name: name, requirementSet: proof.requirementSet, proofHash: proof.proofHash)
        let signature = try await ledger.signPersonalMessage(message)
        guard Ethereum.recoverAddress(message: message, signature: signature) == address else { throw AppError.wrongLedger }

        let row = StudentRow(name: name, ledger_address: address, proof_hash: proof.proofHash,
                             requirement_set: proof.requirementSet, registration_message: message,
                             registration_signature: "0x" + signature.hex)
        let saved: StudentRow = try await db.from("students")
            .upsert(row, onConflict: "ledger_address").select().single().execute().value
        registration = Registration(studentID: saved.id!, name: name, ledgerAddress: address, requirementSet: proof.requirementSet,
                                    record: record, proof: proof.proof, publicInputs: proof.publicInputs,
                                    proofHash: proof.proofHash, commitment: proof.commitment, registeredAt: .now)
        await Notifications.shared.requestPermission()
        startListening()
    }

    // MARK: Requests

    /// Supabase Realtime: notify the moment a school asks.
    func startListening() {
        guard let registration, listening == nil else { return }
        listening = Task { [weak self] in
            guard let self else { return }
            await refresh()
            let channel = db.channel("student-\(registration.studentID)")
            let inserts = channel.postgresChange(InsertAction.self, schema: "public", table: "proof_requests",
                                                 filter: .eq("student_id", value: registration.studentID.uuidString))
            do { try await channel.subscribeWithError() } catch { print("realtime subscribe failed:", error); return }
            for await insert in inserts {
                await refresh()
                if let school = insert.record["school"]?.stringValue { Notifications.shared.schoolRequested(school) }
            }
        }
    }

    func refresh() async {
        guard let registration else { return }
        do {
            let rows: [ProofRequestRow] = try await db.from("proof_requests").select()
                .eq("student_id", value: registration.studentID).order("created_at", ascending: false).execute().value
            let schools: [SchoolRow] = try await db.from("schools").select().execute().value
            let registry = Dictionary(schools.map { ($0.name, $0.ledger_address) }, uniquingKeysWith: { a, _ in a })
            requests = rows.map { IncomingRequest(row: $0, schoolVerified: verifySchool($0, registry: registry, registration: registration)) }
        } catch {
            print("refresh failed:", error)
        }
    }

    /// The request text must be what this school's registered Ledger signed.
    private func verifySchool(_ r: ProofRequestRow, registry: [String: String], registration: Registration) -> Bool {
        guard let message = r.request_message, let sigHex = r.request_signature, let sig = Data(hex: sigHex),
              let address = r.school_address, registry[r.school] == address
        else { return false }
        let expected = Consent.request(school: r.school, student: registration.name,
                                       requirementSet: registration.requirementSet, nonce: r.nonce)
        return message == expected && Ethereum.recoverAddress(message: message, signature: sig) == address
    }

    /// Sign the release on the Ledger, then hand the proof to the school.
    func approve(_ request: IncomingRequest) async throws {
        guard let registration else { return }
        guard request.schoolVerified else { throw AppError.unverifiedSchool }
        let expiresAt = Consent.expiry()
        let message = Consent.release(school: request.row.school, proofHash: registration.proofHash,
                                      nonce: request.row.nonce, expiresAt: expiresAt)
        let signature = try await ledger.signPersonalMessage(message)
        guard Ethereum.recoverAddress(message: message, signature: signature) == registration.ledgerAddress
        else { throw AppError.wrongLedger }

        try await db.from("proof_requests").update(ReleaseUpdate(
            expires_at: Consent.iso(expiresAt), proof: registration.proof,
            public_inputs: registration.publicInputs, release_message: message, release_signature: "0x" + signature.hex
        )).eq("id", value: request.id).execute()
        await refresh()
    }

    func decline(_ request: IncomingRequest) async {
        _ = try? await db.from("proof_requests").update(["status": "denied"]).eq("id", value: request.id).execute()
        await refresh()
    }

    /// Demo reset: removes the registry row (and its requests) and local data.
    func reset() async {
        listening?.cancel()
        listening = nil
        if let id = registration?.studentID {
            _ = try? await db.from("students").delete().eq("id", value: id).execute()
        }
        await db.removeAllChannels()
        registration = nil
        requests = []
    }

    private func save() {
        if let registration, let data = try? JSONEncoder().encode(registration) {
            UserDefaults.standard.set(data, forKey: "registration")
        } else {
            UserDefaults.standard.removeObject(forKey: "registration")
        }
    }
}

enum AppError: LocalizedError {
    case wrongLedger, unverifiedSchool
    var errorDescription: String? {
        switch self {
        case .wrongLedger: "That signature didn't come from your registered Ledger."
        case .unverifiedSchool: "This request isn't signed by a registered school Ledger."
        }
    }
}
