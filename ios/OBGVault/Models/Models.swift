import Foundation

struct AccessRequest: Identifiable, Sendable {
    enum Status: String, Sendable { case pending, approved, denied }

    let id: String
    let verifier: String
    let purpose: String
    let claims: [Claim]
    let duration: TimeInterval
    /// Makes each proof single-use for this request.
    let nonce: String
    let createdAt: Date
    var status: Status = .pending
    var grantID: String?
}

/// What the provider holds after the patient approves, until it expires.
struct Grant: Identifiable, Sendable {
    let id: String
    let requestID: String
    let verifier: String
    let presentation: Presentation
    var expiresAt: Date { presentation.context.expiresAt }
}

struct AuditEntry: Identifiable, Sendable {
    enum Event: String, Sendable { case paired, issued, requested, approved, denied, verified, expired }

    let id = UUID()
    let at: Date
    let event: Event
    let actor: String
    let detail: String
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

func randomHex(_ bytes: Int) -> String {
    Data((0..<bytes).map { _ in UInt8.random(in: .min ... .max) }).hex
}
