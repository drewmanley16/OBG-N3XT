import SwiftUI

/// After onboarding: the proof pass, live school requests, history, private records.
struct HomeView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Screen(title: "Vault", subtitle: "Student · OBG") {
            if let reg = model.registration {
                let pending = model.requests.filter(\.row.isPending)
                if !pending.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow("Requests", trailing: "\(pending.count) pending")
                        ForEach(pending) { RequestCard(request: $0) }
                    }
                }

                ProofPass(registration: reg)

                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow("History")
                    let done = model.requests.filter { !$0.row.isPending }
                    if done.isEmpty { Card { Text("No schools have asked yet").foregroundStyle(Theme.muted) } }
                    ForEach(done) { r in
                        Card(padding: 14) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(r.row.school).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.text)
                                    Text(r.row.created_at.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                                        .font(Theme.mono(11)).foregroundStyle(Theme.faint)
                                }
                                Spacer()
                                if r.row.status == "approved" {
                                    Pill(text: "Proof sent")
                                } else {
                                    Pill(text: "Declined", color: Theme.danger)
                                }
                            }
                        }
                    }
                }

                RecordList(record: reg.record)

                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow("Ledger")
                    Card {
                        ModeSwitch()
                        Button("Reset demo") { Task { await model.reset() } }
                            .buttonStyle(GhostButtonStyle(color: Theme.danger))
                    }
                }
            }
        }
        .refreshable { await model.refresh() }
    }
}

private struct ProofPass: View {
    let registration: Registration

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Your proof", trailing: "Registered on Supabase")
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ZERO-KNOWLEDGE PROOF").font(Theme.mono(11, .bold)).tracking(2).foregroundStyle(Theme.accent)
                        Text(Requirement.oregonK12.label).font(.system(size: 22, weight: .heavy)).foregroundStyle(Theme.text)
                        Text(registration.name).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 30)).foregroundStyle(Theme.accent)
                }
                HStack(spacing: 6) {
                    ForEach(Vaccine.allCases, id: \.self) { v in
                        Text(v.rawValue.replacingOccurrences(of: "Hepatitis ", with: "Hep"))
                            .font(Theme.mono(10, .semibold)).foregroundStyle(.black)
                            .padding(.horizontal, 6).padding(.vertical, 4)
                            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    }
                }
                HStack {
                    meta("Ledger", registration.ledgerAddress.shortHex)
                    Spacer()
                    meta("Proof hash", String(registration.proofHash.prefix(10)) + "…")
                    Spacer()
                    meta("Size", "\(registration.proof.count / 2 / 1024) KB")
                }
            }
            .padding(20)
            .background(LinearGradient(colors: [Color(red: 0.13, green: 0.15, blue: 0.11), Theme.surface],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.accent.opacity(0.25)))
        }
    }

    private func meta(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased()).font(Theme.mono(9, .semibold)).tracking(1.4).foregroundStyle(Theme.faint)
            Text(value).font(Theme.mono(12, .medium)).foregroundStyle(Theme.text)
        }
    }
}

private struct RequestCard: View {
    @Environment(AppModel.self) private var model
    let request: AppModel.IncomingRequest
    @State private var approving = false
    @State private var error: String?

    var body: some View {
        Card(padding: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(request.row.school).font(.system(size: 19, weight: .bold)).foregroundStyle(Theme.text)
                Text("wants proof you meet \(Requirement.oregonK12.label) requirements")
                    .font(.subheadline).foregroundStyle(Theme.muted)
            }
            HStack(spacing: 8) {
                Image(systemName: request.schoolVerified ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                Text(request.schoolVerified
                     ? "Signed by the school's Ledger \(request.row.school_address?.shortHex ?? "")"
                     : "Not signed by a registered school. Don't approve.")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(request.schoolVerified ? Theme.accent : Theme.danger)

            HStack(spacing: 8) {
                Image(systemName: "eye.slash").foregroundStyle(Theme.muted)
                Text("They get a yes/no proof. No dates, doses, providers or birth date.").font(.caption).foregroundStyle(Theme.muted)
            }
            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            if approving {
                LedgerWaiting()
            } else {
                HStack(spacing: 10) {
                    Button("Decline") { Task { await model.decline(request) } }
                        .buttonStyle(GhostButtonStyle(color: Theme.danger)).frame(width: 110)
                    Button("Approve on Ledger") { Task { await approve() } }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!request.schoolVerified)
                        .opacity(request.schoolVerified ? 1 : 0.4)
                }
            }
            if let error { Text(error).font(.footnote).foregroundStyle(Theme.danger) }
        }
    }

    private func approve() async {
        approving = true
        defer { approving = false }
        do { try await model.approve(request); error = nil } catch { self.error = error.localizedDescription }
    }
}
