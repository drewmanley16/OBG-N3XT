import Foundation

/// Vaccine facts the health department attests to. A provider asks for some of
/// these, and only those are revealed.
enum Claim: String, CaseIterable, Codable, Identifiable, Sendable {
    case covid19UpToDate = "covid19_up_to_date"
    case influenzaThisSeason = "influenza_this_season"
    case mmrComplete = "mmr_complete"
    case tdapCurrent = "tdap_current"
    case hepBComplete = "hepb_complete"
    case over18 = "over_18"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .covid19UpToDate: "COVID-19 vaccination up to date"
        case .influenzaThisSeason: "Flu shot this season"
        case .mmrComplete: "MMR series complete"
        case .tdapCurrent: "Tdap within 10 years"
        case .hepBComplete: "Hepatitis B series complete"
        case .over18: "18 or older"
        }
    }
}

struct Immunization: Codable, Sendable {
    let vaccine: String
    let date: Date
}

/// The raw record held by the clinic. It never leaves the issuer.
struct PatientRecord: Sendable {
    let name: String
    let dateOfBirth: Date
    let immunizations: [Immunization]

    static let sample: PatientRecord = {
        func d(_ s: String) -> Date { ISO8601DateFormatter().date(from: s + "T12:00:00Z")! }
        return PatientRecord(
            name: "Jordan Rivera",
            dateOfBirth: d("2004-03-14"),
            immunizations: [
                .init(vaccine: "COVID-19 (Pfizer)", date: d("2025-10-01")),
                .init(vaccine: "COVID-19 (Pfizer)", date: d("2026-09-20")),
                .init(vaccine: "Influenza", date: d("2026-09-20")),
                .init(vaccine: "Tdap", date: d("2022-08-15")),
                .init(vaccine: "MMR", date: d("2005-03-20")),
                .init(vaccine: "MMR", date: d("2008-04-02")),
                .init(vaccine: "Hepatitis B", date: d("2004-03-15")),
                .init(vaccine: "Hepatitis B", date: d("2004-04-20")),
                .init(vaccine: "Hepatitis B", date: d("2004-09-18")),
            ]
        )
    }()

    /// What a clinician decides from the record when issuing the credential.
    func attest(now: Date = .now) -> [Claim: Bool] {
        let cal = Calendar(identifier: .gregorian)
        func doses(_ match: String) -> [Date] {
            immunizations.filter { $0.vaccine.localizedCaseInsensitiveContains(match) }.map(\.date)
        }
        func within(years: Int, _ date: Date) -> Bool {
            date > cal.date(byAdding: .year, value: -years, to: now)!
        }
        // Flu season starts August 1.
        let year = cal.component(.year, from: now) - (cal.component(.month, from: now) >= 8 ? 0 : 1)
        let seasonStart = cal.date(from: DateComponents(year: year, month: 8, day: 1))!
        let covid = doses("COVID")
        return [
            .covid19UpToDate: covid.count >= 2 && covid.contains { within(years: 1, $0) },
            .influenzaThisSeason: doses("Influenza").contains { $0 >= seasonStart },
            .mmrComplete: doses("MMR").count >= 2,
            .tdapCurrent: doses("Tdap").contains { within(years: 10, $0) },
            .hepBComplete: doses("Hepatitis B").count >= 3,
            .over18: !within(years: 18, dateOfBirth),
        ]
    }
}
