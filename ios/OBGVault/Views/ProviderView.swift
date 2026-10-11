import SwiftUI

/// The provider's side: ask for vaccine facts, then verify the proof.
struct ProviderView: View {
    @Environment(VaultStore.self) private var store
    @State private var verifier = Preset.all[0].verifier
    @State private var purpose = Preset.all[0].purpose
    @State private var claims = Set(Preset.all[0].claims)
    @State private var minutes = Preset.all[0].minutes

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(Preset.all, id: \.verifier) { p in
                                Button(p.verifier) { apply(p) }.buttonStyle(.bordered).font(.caption)
                            }
                        }
                    }
                    TextField("Provider", text: $verifier)
                    TextField("Reason", text: $purpose)
                    Stepper("Access for \(minutes) min", value: $minutes, in: 1...240)
                } header: { Text("New request") }

                Section("Ask the patient to prove") {
                    ForEach(Claim.allCases) { claim in
                        Toggle(claim.label, isOn: Binding(
                            get: { claims.contains(claim) },
                            set: { if $0 { claims.insert(claim) } else { claims.remove(claim) } }))
                    }
                }

                Section {
                    Button("Send request") {
                        store.sendRequest(verifier: verifier, purpose: purpose,
                                          claims: Claim.allCases.filter(claims.contains), minutes: minutes)
                    }
                    .disabled(verifier.isEmpty || claims.isEmpty)
                }

                Section("Requests") {
                    if store.requests.isEmpty { Text("None yet").foregroundStyle(.secondary) }
                    ForEach(store.requests) { request in
                        if let grantID = request.grantID {
                            NavigationLink { VerificationView(grantID: grantID) } label: { RequestSummary(request: request) }
                        } else {
                            RequestSummary(request: request)
                        }
                    }
                }
            }
            .navigationTitle("Provider")
        }
    }

    private func apply(_ p: Preset) {
        verifier = p.verifier
        purpose = p.purpose
        claims = Set(p.claims)
        minutes = p.minutes
    }
}

private struct Preset {
    let verifier: String
    let purpose: String
    let claims: [Claim]
    let minutes: Int

    static let all = [
        Preset(verifier: "McDonald Theatre", purpose: "Concert entry", claims: [.covid19UpToDate], minutes: 5),
        Preset(verifier: "University of Oregon", purpose: "Enrollment immunization requirement", claims: [.mmrComplete, .tdapCurrent], minutes: 30),
        Preset(verifier: "PeaceHealth Volunteer Office", purpose: "Hospital volunteer clearance",
               claims: [.influenzaThisSeason, .covid19UpToDate, .hepBComplete], minutes: 60),
    ]
}

private struct RequestSummary: View {
    let request: AccessRequest
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(request.verifier).bold()
                Spacer()
                Text(request.status == .approved ? "Proof received" : request.status.rawValue.capitalized)
                    .font(.caption).foregroundStyle(request.status == .approved ? .green : .secondary)
            }
            Text(request.claims.map(\.label).joined(separator: ", ")).font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct VerificationView: View {
    @Environment(VaultStore.self) private var store
    let grantID: String
    @State private var result: Verification??

    var body: some View {
        List {
            switch result {
            case .none:
                ProgressView()
            case .some(.none):
                Section { Label("Proof expired. Ask the patient again.", systemImage: "clock.badge.xmark").foregroundStyle(.red) }
            case let .some(.some(v)):
                Section {
                    Label(v.ok ? "Verified" : "Verification failed", systemImage: v.ok ? "checkmark.seal.fill" : "xmark.seal.fill")
                        .font(.title3.bold()).foregroundStyle(v.ok ? .green : .red)
                    ForEach(v.revealed, id: \.claim) { d in
                        Label(d.claim.label, systemImage: d.value ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(d.value ? .green : .red)
                    }
                } footer: {
                    Text("\(v.hiddenCount) other facts in the credential stayed hidden, including name and birth date.")
                }
                Section("Checks") {
                    ForEach(v.checks) { c in
                        Label(c.label, systemImage: c.ok ? "checkmark" : "xmark").foregroundStyle(c.ok ? Color.primary : .red)
                    }
                }
                if let grant = store.grants.first(where: { $0.id == grantID }) {
                    Section("What we received") {
                        Text(grant.presentation.consentText).font(.caption.monospaced())
                        LabeledContent("Ledger signature") {
                            Text("0x" + grant.presentation.ledgerSignature.hex).font(.caption2.monospaced()).lineLimit(2)
                        }
                        LabeledContent("Proof engine", value: grant.presentation.engine).font(.caption)
                    }
                }
            }
        }
        .navigationTitle("Proof")
        .onAppear { result = .some(store.verify(grantID: grantID)) }
    }
}
