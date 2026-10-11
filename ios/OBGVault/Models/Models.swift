import Foundation

/// Vaccines in the order the ZK circuit expects (circuits/school_vaccines).
enum Vaccine: String, CaseIterable, Codable, Sendable {
    case dtap = "DTaP", polio = "Polio", mmr = "MMR", varicella = "Varicella"
    case hepB = "Hepatitis B", hepA = "Hepatitis A", tdap = "Tdap"
}

struct Requirement: Sendable {
    let id: String
    let label: String
    let minDoses: [Vaccine: Int]

    static let oregonK12 = Requirement(
        id: "oregon-k12-2026",
        label: "Oregon K-12 school entry",
        minDoses: [.dtap: 5, .polio: 4, .mmr: 2, .varicella: 2, .hepB: 3, .hepA: 2, .tdap: 1])
}

struct Dose: Codable, Hashable, Sendable {
    let vaccine: Vaccine
    let date: Date
}

/// What the (simulated) Epic import returns. Stays on the phone.
struct ImmunizationRecord: Codable, Sendable {
    let source: String
    let doses: [Dose]

    func count(_ v: Vaccine) -> Int { doses.filter { $0.vaccine == v }.count }
    var doseCounts: [Int] { Vaccine.allCases.map(count) }

    func meets(_ r: Requirement) -> Bool { Vaccine.allCases.allSatisfy { count($0) >= (r.minDoses[$0] ?? 0) } }

    /// A high schooler with a complete Oregon K-12 record.
    static let sample: ImmunizationRecord = {
        func d(_ s: String) -> Date { ISO8601DateFormatter().date(from: s + "T12:00:00Z")! }
        let doses: [(Vaccine, String)] = [
            (.dtap, "2010-05-02"), (.dtap, "2010-07-06"), (.dtap, "2010-09-08"), (.dtap, "2011-06-10"), (.dtap, "2014-03-12"),
            (.polio, "2010-05-02"), (.polio, "2010-07-06"), (.polio, "2011-01-11"), (.polio, "2014-03-12"),
            (.mmr, "2011-03-15"), (.mmr, "2014-03-12"),
            (.varicella, "2011-03-15"), (.varicella, "2014-03-12"),
            (.hepB, "2010-03-01"), (.hepB, "2010-05-02"), (.hepB, "2010-09-08"),
            (.hepA, "2011-03-15"), (.hepA, "2011-09-20"),
            (.tdap, "2021-08-24"),
        ]
        return ImmunizationRecord(source: "Epic · PeaceHealth Sacred Heart", doses: doses.map { Dose(vaccine: $0.0, date: d($0.1)) })
    }()
}

/// Saved on the phone after onboarding.
struct Registration: Codable, Sendable {
    let studentID: UUID
    let name: String
    let ledgerAddress: String
    let requirementSet: String
    let record: ImmunizationRecord
    let proof: String // hex
    let publicInputs: [String]
    let proofHash: String
    let commitment: String
    let registeredAt: Date
}

// MARK: - Supabase rows

struct StudentRow: Codable, Sendable {
    var id: UUID?
    let name: String
    let ledger_address: String
    let proof_hash: String
    let requirement_set: String
    let registration_message: String
    let registration_signature: String
}

struct ProofRequestRow: Codable, Identifiable, Sendable {
    let id: UUID
    let student_id: UUID
    let school: String
    let nonce: String
    let status: String
    let created_at: Date
    let expires_at: Date?
    let school_address: String?
    let request_message: String?
    let request_signature: String?

    var isPending: Bool { status == "pending" }
}

struct SchoolRow: Codable, Sendable {
    let name: String
    let ledger_address: String
}

struct ReleaseUpdate: Encodable, Sendable {
    let status = "approved"
    let expires_at: String
    let proof: String
    let public_inputs: [String]
    let release_message: String
    let release_signature: String
}

extension Data {
    var hex: String { map { String(format: "%02x", $0) }.joined() }

    init?(hex: String) {
        let s = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        guard s.count.isMultiple(of: 2) else { return nil }
        var bytes = [UInt8]()
        var i = s.startIndex
        while i < s.endIndex {
            let j = s.index(i, offsetBy: 2)
            guard let b = UInt8(s[i..<j], radix: 16) else { return nil }
            bytes.append(b)
            i = j
        }
        self.init(bytes)
    }
}
