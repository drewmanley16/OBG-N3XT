import Foundation

/// The patient's Ledger. It never exposes keys: it returns an address and
/// signs only what the patient approves on the device.
protocol LedgerSigner: Sendable {
    var displayName: String { get }
    func address() async throws -> String
    /// Shows `message` on the device; returns a 65-byte r‖s‖v signature once the patient approves.
    func signPersonalMessage(_ message: String) async throws -> Data
}

enum LedgerError: LocalizedError {
    case status(UInt16)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .status(0x6985): "Rejected on the Ledger."
        case .status(0x6E00), .status(0x6D00), .status(0x6511): "Open the Ethereum app on the Ledger."
        case .status(0x5515): "Unlock the Ledger."
        case let .status(sw): String(format: "Ledger error 0x%04X", sw)
        case .badResponse: "Unexpected response from the Ledger."
        }
    }
}

/// Ethereum app APDUs, shared by any transport (emulator over HTTP today,
/// Bluetooth for a real Nano X / Stax / Flex later).
enum EthereumAPDU {
    /// m/44'/60'/0'/0/0
    static let path: [UInt32] = [0x8000_002C, 0x8000_003C, 0x8000_0000, 0, 0]

    static var pathBytes: [UInt8] {
        [UInt8(path.count)] + path.flatMap(\.bigEndianBytes)
    }

    static func getAddress() -> [UInt8] {
        [0xE0, 0x02, 0x00, 0x00, UInt8(pathBytes.count)] + pathBytes
    }

    /// SIGN ETH PERSONAL MESSAGE, split into ≤255-byte chunks.
    static func signPersonalMessage(_ message: Data) -> [[UInt8]] {
        var payload = pathBytes + UInt32(message.count).bigEndianBytes + [UInt8](message)
        var apdus: [[UInt8]] = []
        while !payload.isEmpty {
            let chunk = Array(payload.prefix(255))
            payload.removeFirst(chunk.count)
            apdus.append([0xE0, 0x08, apdus.isEmpty ? 0x00 : 0x80, 0x00, UInt8(chunk.count)] + chunk)
        }
        return apdus
    }

    static func parseAddress(_ r: [UInt8]) throws -> String {
        guard let keyLen = r.first.map(Int.init), r.count > keyLen + 1 else { throw LedgerError.badResponse }
        let addrLen = Int(r[keyLen + 1])
        guard r.count >= keyLen + 2 + addrLen,
              let ascii = String(bytes: r[(keyLen + 2)..<(keyLen + 2 + addrLen)], encoding: .ascii)
        else { throw LedgerError.badResponse }
        return "0x" + ascii.lowercased()
    }

    /// Device returns v‖r‖s; we use r‖s‖v like Ethereum tooling.
    static func parseSignature(_ r: [UInt8]) throws -> Data {
        guard r.count >= 65 else { throw LedgerError.badResponse }
        return Data(r[1..<65] + [r[0]])
    }
}

/// Ledger's official emulator (Speculos), reached over its REST API.
/// Start it with `npm run speculos` / `scripts/speculos.sh` at the repo root.
struct SpeculosLedger: LedgerSigner {
    var baseURL = URL(string: "http://localhost:5005")!
    var displayName: String { "Ledger Flex (emulator)" }

    func address() async throws -> String {
        try EthereumAPDU.parseAddress(try await exchange(EthereumAPDU.getAddress()))
    }

    func signPersonalMessage(_ message: String) async throws -> Data {
        var response: [UInt8] = []
        for apdu in EthereumAPDU.signPersonalMessage(Data(message.utf8)) {
            response = try await exchange(apdu) // the last call waits for the patient to approve
        }
        return try EthereumAPDU.parseSignature(response)
    }

    private func exchange(_ apdu: [UInt8]) async throws -> [UInt8] {
        var req = URLRequest(url: baseURL.appending(path: "apdu"), timeoutInterval: 600)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["data": Data(apdu).hex])
        let (data, _) = try await URLSession.shared.data(for: req)
        guard let hex = try JSONDecoder().decode([String: String].self, from: data)["data"],
              let bytes = Data(hex: hex).map(Array.init), bytes.count >= 2
        else { throw LedgerError.badResponse }
        let sw = UInt16(bytes[bytes.count - 2]) << 8 | UInt16(bytes[bytes.count - 1])
        guard sw == 0x9000 else { throw LedgerError.status(sw) }
        return Array(bytes.dropLast(2))
    }
}

/// No device and no Docker: signs in-app with a well-known test key. Demo only.
struct SimulatedLedger: LedgerSigner {
    private let key = Data(hex: "59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d")!
    var displayName: String { "Simulated Ledger (no device)" }

    func address() async throws -> String { try Ethereum.address(privateKey: key) }

    func signPersonalMessage(_ message: String) async throws -> Data {
        try await Task.sleep(for: .seconds(1)) // pretend the patient is reading the screen
        return try Ethereum.signPersonalMessage(message, privateKey: key)
    }
}

extension UInt32 {
    var bigEndianBytes: [UInt8] { withUnsafeBytes(of: bigEndian, Array.init) }
}
