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
