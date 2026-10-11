import SwiftUI

/// The patient's side: Ledger pairing, credential, incoming requests, shared proofs.
struct WalletView: View {
    @Environment(VaultStore.self) private var store
    @State private var connecting = false
    @State private var error: String?

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            List {
                Section {
                    LabeledContent("Device", value: store.ledger.displayName)
                    if let address = store.patientAddress {
                        LabeledContent("Address") { Text(address).font(.caption.monospaced()).textSelection(.enabled) }
                    } else {
                        Button {
                            Task { await connect() }
                        } label: {
                            HStack { Text("Connect Ledger"); if connecting { Spacer(); ProgressView() } }
                        }
                        .disabled(connecting)
                    }
                    Picker("Mode", selection: $store.ledgerMode) {
                        ForEach(VaultStore.LedgerMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if let error { Text(error).foregroundStyle(.red).font(.footnote) }
                } header: {
                    Text("Ledger")
                } footer: {
                    if store.ledgerMode == .emulator {
                        Text("Approve on the emulator's screen at localhost:5005. Start it with scripts/speculos.sh.")
                    }
                }

                if let credential = store.credential {
                    Section {
                        ForEach(Claim.allCases) { claim in
                            Label(claim.label, systemImage: credential.value(of: claim) == true ? "checkmark.circle.fill" : "xmark.circle")
                                .foregroundStyle(credential.value(of: claim) == true ? .green : .secondary)
                        }
                    } header: {
                        Text("Vaccine credential")
                    } footer: {
                        Text("Signed by \(credential.issuer). Only you see this list; providers get proof of just the facts they ask for.")
                    }
                }

                Section("Requests") {
                    let pending = store.requests.filter { $0.status == .pending }
                    if pending.isEmpty { Text("No pending requests").foregroundStyle(.secondary) }
                    ForEach(pending) { RequestRow(request: $0) }
                }

                Section("Shared proofs") {
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        let active = store.grants.filter { $0.expiresAt > ctx.date }
                        if active.isEmpty { Text("No provider holds a valid proof").foregroundStyle(.secondary) }
                        ForEach(active) { grant in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(grant.verifier).bold()
                                    Text(grant.presentation.revealed.map(\.claim.label).joined(separator: ", ")).font(.caption)
                                }
                                Spacer()
                                Text(timerInterval: ctx.date...grant.expiresAt, countsDown: true)
                                    .monospacedDigit().foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Audit log") {
                    ForEach(store.audit) { entry in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(entry.event.rawValue.capitalized) · \(entry.actor)").font(.subheadline.bold())
                            Text(entry.detail).font(.caption)
                            Text(entry.at, style: .time).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("My Vaccine Vault")
        }
    }

    private func connect() async {
        connecting = true
        defer { connecting = false }
        do { try await store.connectLedger(); error = nil } catch { self.error = error.localizedDescription }
    }
}

private struct RequestRow: View {
    @Environment(VaultStore.self) private var store
    let request: AccessRequest
    @State private var approving = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(request.verifier).font(.headline)
            if !request.purpose.isEmpty { Text("“\(request.purpose)”").font(.subheadline).foregroundStyle(.secondary) }
            VStack(alignment: .leading, spacing: 4) {
                Text("Wants proof of:").font(.caption.bold())
                ForEach(request.claims) { Text("• \($0.label)").font(.callout) }
            }
            Text("Name, birth date, dose dates and every other fact stay hidden. Valid for \(Int(request.duration / 60)) min.")
                .font(.caption).foregroundStyle(.secondary)

            if approving {
                HStack { ProgressView(); Text("Review and hold to sign on your Ledger…").font(.callout) }
            } else {
                HStack {
                    Button("Reject", role: .destructive) { store.deny(request.id) }
                        .buttonStyle(.bordered)
                    Spacer()
                    Button("Approve on Ledger") { Task { await approve() } }
                        .buttonStyle(.borderedProminent)
                }
            }
            if let error { Text(error).font(.footnote).foregroundStyle(.red) }
        }
        .padding(.vertical, 4)
    }

    private func approve() async {
        approving = true
        defer { approving = false }
        do { try await store.approve(request.id); error = nil } catch { self.error = error.localizedDescription }
    }
}
