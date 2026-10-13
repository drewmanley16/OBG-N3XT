import Foundation
import Supabase

/// Values from Config/Base.xcconfig + Config/Secrets.xcconfig via Info.plist.
enum AppConfig {
    private static func value(_ key: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String) ?? ""
    }

    static let supabaseURL = URL(string: "https://\(value("SupabaseProjectRef")).supabase.co")!
    static let supabaseKey = value("SupabaseAnonKey")
    static let proverURL = URL(string: "http://\(value("ProverHost"))/api/prove")!
    static let epicURL = URL(string: "http://\(value("ProverHost"))/api/epic")!
    static let agentURL = URL(string: "http://\(value("ProverHost"))/api/agent")!
    static let speculosURL = URL(string: "http://\(value("SpeculosHost"))")!

    static let supabase = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseKey)
}
