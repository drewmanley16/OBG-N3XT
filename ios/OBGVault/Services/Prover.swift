import Foundation

/// Calls the prover (web/src/app/api/prove), which runs the Noir circuit and
/// returns an UltraHonk proof that the dose counts meet the requirement.
enum Prover {
    struct Result: Decodable, Sendable {
        let proof: String
        let publicInputs: [String]
        let commitment: String
        let proofHash: String
        let requirementSet: String
    }

    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func prove(record: ImmunizationRecord, holder: String) async throws -> Result {
        var req = URLRequest(url: AppConfig.proverURL, timeoutInterval: 120)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["doses": record.doseCounts, "holder": holder])
        let (data, response) = try await URLSession.shared.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let error = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
            throw Failure(message: error ?? "Prover unavailable. Is the web app running (npm run dev in web/)?")
        }
        return try JSONDecoder().decode(Result.self, from: data)
    }
}

/// The AI step (web/src/app/api/agent): Claude reads the raw Epic export,
/// decides which doses count toward the school requirements, and drafts the
/// disclosure. The server checks every dose it proposes against the export;
/// the circuit then enforces the counts and the Ledger approves.
enum Agent {
    /// The raw export as Epic returns it, kept byte-for-byte to send for review.
    struct EpicExport: Sendable {
        struct Entry: Decodable, Sendable {
            struct Code: Decodable, Sendable { let text: String }
            let id: String
            let vaccineCode: Code
            let occurrenceDate: String
        }
        private struct Body: Decodable { let source: String; let entries: [Entry] }

        let raw: Data
        let source: String
        let entries: [Entry]

        init(raw: Data) throws {
            let body = try JSONDecoder().decode(Body.self, from: raw)
            self.raw = raw
            source = body.source
            entries = body.entries
        }

        func entry(_ id: String) -> Entry? { entries.first { $0.id == id } }
    }

    struct Review: Decodable, Sendable {
        struct CountedDose: Decodable, Sendable { let sourceId: String; let vaccine: Vaccine; let date: String }
        struct VaccineCheck: Decodable, Sendable { let vaccine: Vaccine; let validDoses: Int; let required: Int; let met: Bool; let note: String }
        struct Excluded: Decodable, Sendable { let sourceId: String; let reason: String }
        struct Disclosure: Decodable, Sendable { let schoolSees: [String]; let keptPrivate: [String] }

        let model: String
        let doses: [CountedDose]
        let meetsRequirements: Bool
        let vaccines: [VaccineCheck]
        let excluded: [Excluded]
        let disclosure: Disclosure
        let summary: String

        /// The doses that count, as the record the circuit proves.
        func record(source: String) -> ImmunizationRecord {
            let day = DateFormatter()
            day.dateFormat = "yyyy-MM-dd"
            day.timeZone = TimeZone(identifier: "UTC")
            return ImmunizationRecord(source: source, doses: doses.compactMap { d in
                day.date(from: d.date).map { Dose(vaccine: d.vaccine, date: $0.addingTimeInterval(12 * 3600)) }
            })
        }
    }

    static func importFromEpic() async throws -> EpicExport {
        let (data, response) = try await URLSession.shared.data(from: AppConfig.epicURL)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw Prover.Failure(message: "Couldn't reach Epic. Is the web app running (npm run dev in web/)?")
        }
        return try EpicExport(raw: data)
    }

    static func review(_ export: EpicExport) async throws -> Review {
        var req = URLRequest(url: AppConfig.agentURL, timeoutInterval: 120)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = export.raw
        let (data, response) = try await URLSession.shared.data(for: req)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            let error = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
            throw Prover.Failure(message: error ?? "AI review unavailable. Is the web app running (npm run dev in web/)?")
        }
        return try JSONDecoder().decode(Review.self, from: data)
    }
}
