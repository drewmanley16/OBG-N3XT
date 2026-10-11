import SwiftUI

/// Name → Ledger → Epic import → ZK proof → Ledger-signed registration.
struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var name = "Jordan Rivera"
    @State private var address: String?
    @State private var record: ImmunizationRecord?
    @State private var proof: Prover.Result?
    @State private var busy: Step?
    @State private var error: String?
    @State private var proofSeconds: Double?

    enum Step: Int { case ledger = 1, epic, proof, register }

    var body: some View {
        Screen(title: "Set up your vault", subtitle: "OBG Vault · School vaccines") {
            Text("Prove you meet school vaccine requirements without handing over your medical record. Your Ledger approves every release.")
                .foregroundStyle(Theme.muted)

            Card {
                Field(label: "Student name", text: $name)
            }

            step(1, "Connect your Ledger", done: address.map { "Paired · \($0.shortHex)" }, active: address == nil) {
                ModeSwitch()
                Button(busy == .ledger ? "Connecting…" : "Connect Ledger") { run(.ledger) { address = try await model.connectLedger() } }
                    .buttonStyle(PrimaryButtonStyle())
            }

            step(2, "Import records from Epic", done: record.map { "\($0.doses.count) doses · \($0.source)" },
                 active: address != nil && record == nil) {
                Text("Sign in to MyChart to pull your immunization history. (Simulated for the demo.)")
                    .font(.caption).foregroundStyle(Theme.muted)
                Button(busy == .epic ? "Importing from Epic…" : "Connect Epic MyChart") { run(.epic) { record = try await model.importFromEpic() } }
                    .buttonStyle(PrimaryButtonStyle())
            }
            if let record, proof == nil { RecordList(record: record) }

            step(3, "Generate zero-knowledge proof",
                 done: proof.map { p in "\(p.proof.count / 2 / 1024) KB proof\(proofSeconds.map { String(format: " · %.1fs", $0) } ?? "")" },
                 active: record != nil && proof == nil) {
                Text("Proves your record meets \(Requirement.oregonK12.label) requirements. The proof reveals no dates or counts.")
                    .font(.caption).foregroundStyle(Theme.muted)
                Button(busy == .proof ? "Proving…" : "Generate proof") {
                    run(.proof) {
                        let start = Date.now
                        proof = try await model.generateProof(record: record!, holder: address!)
                        proofSeconds = Date.now.timeIntervalSince(start)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }

            step(4, "Register on your Ledger", done: nil, active: proof != nil) {
                if let proof {
                    Text("Your Ledger signs the proof hash. Supabase stores only your name, that hash and your Ledger address.")
                        .font(.caption).foregroundStyle(Theme.muted)
                    Text(Consent.registration(name: name, requirementSet: proof.requirementSet, proofHash: proof.proofHash))
                        .font(Theme.mono(12)).foregroundStyle(Theme.accent)
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                if busy == .register { LedgerWaiting() }
                Button("Sign & register") {
                    run(.register) { try await model.register(name: name, address: address!, record: record!, proof: proof!) }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(busy != nil)
            }

            if let error { Text(error).font(.footnote).foregroundStyle(Theme.danger) }
        }
    }

    private func run(_ step: Step, _ work: @escaping () async throws -> Void) {
        guard busy == nil else { return }
        busy = step
        error = nil
        Task {
            do { try await work() } catch { self.error = error.localizedDescription }
            busy = nil
        }
    }

    @ViewBuilder
    private func step(_ n: Int, _ title: String, done: String?, active: Bool, @ViewBuilder content: () -> some View) -> some View {
        Card {
            HStack(spacing: 12) {
                Text(done != nil ? "✓" : "\(n)")
                    .font(Theme.mono(13, .bold))
                    .foregroundStyle(done != nil ? .black : (active ? Theme.text : Theme.faint))
                    .frame(width: 28, height: 28)
                    .background(done != nil ? Theme.accent : Theme.raised, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 17, weight: .bold)).foregroundStyle(active || done != nil ? Theme.text : Theme.faint)
                    if let done { Text(done).font(Theme.mono(12)).foregroundStyle(Theme.accent) }
                }
                Spacer()
            }
            if active { content() }
        }
    }
}

struct RecordList: View {
    let record: ImmunizationRecord
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Imported records", trailing: "Private · on this phone")
            Card(padding: 14) {
                ForEach(Vaccine.allCases, id: \.self) { v in
                    let dates = record.doses.filter { $0.vaccine == v }.map(\.date)
                    HStack(alignment: .firstTextBaseline) {
                        Text(v.rawValue).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text)
                        Spacer()
                        Text("\(dates.count) doses").font(Theme.mono(12, .bold)).foregroundStyle(Theme.accent)
                    }
                    Text(dates.map { $0.formatted(.dateTime.year().month(.abbreviated)) }.joined(separator: " · "))
                        .font(Theme.mono(11)).foregroundStyle(Theme.faint)
                }
            }
        }
    }
}

struct ModeSwitch: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppModel.LedgerMode.allCases) { mode in
                let on = model.ledgerMode == mode
                Button { model.ledgerMode = mode } label: {
                    Text(mode.rawValue.uppercased()).font(Theme.mono(11, .semibold)).tracking(1.2)
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .foregroundStyle(on ? .black : Theme.muted)
                        .background(on ? Theme.text : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

struct LedgerWaiting: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView().tint(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Check your Ledger").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.text)
                Text("Review the text, then hold to sign").font(.caption).foregroundStyle(Theme.muted)
            }
            Spacer()
            Pill(text: "Awaiting", pulsing: true)
        }
    }
}
