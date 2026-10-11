import Foundation

/// Texts the student's Ledger displays and signs. The school's verifier
/// (web/src/lib/messages.ts) rebuilds the exact same strings, so keep both in
/// sync. Plain ASCII only: the Ledger shows anything else as hex.
enum Consent {
    static func short(_ hash: String) -> String {
        String((hash.hasPrefix("0x") ? String(hash.dropFirst(2)) : hash).prefix(32))
    }

    static func registration(name: String, requirementSet: String, proofHash: String) -> String {
        ["OBG Vault registration", "Student: \(name)", "Requirements: \(requirementSet)", "Proof: \(short(proofHash))"]
            .joined(separator: "\n")
    }

    /// Signed by the school's Ledger when it asks for a proof.
    static func request(school: String, student: String, requirementSet: String, nonce: String) -> String {
        ["OBG Vault request", "From: \(school)", "Student: \(student)", "Prove: \(requirementSet)", "Request: \(nonce.prefix(8))"]
            .joined(separator: "\n")
    }

    static func release(school: String, proofHash: String, nonce: String, expiresAt: Date) -> String {
        [
            "OBG Vault release",
            "Send proof to: \(school)",
            "Proof: \(short(proofHash))",
            "Request: \(nonce.prefix(8))",
            "Expires: \(minuteFormat.string(from: expiresAt)) UTC",
        ].joined(separator: "\n")
    }

    /// Release expiry, whole minutes so the text round-trips through the database.
    static func expiry(from now: Date = .now, minutes: Int = 15) -> Date {
        Date(timeIntervalSince1970: (now.timeIntervalSince1970 / 60).rounded(.down) * 60 + Double(minutes * 60))
    }

    static let minuteFormat: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    static func iso(_ date: Date) -> String {
        date.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false).timeZone(separator: .omitted))
    }
}
