import SwiftUI

/// The patient's side: Ledger, credential, incoming requests, shared proofs, audit.
struct WalletView: View {
    @Environment(VaultStore.self) private var store

    var body: some View {
        Screen(title: "Vault", subtitle: "Patient · OBG") {
            // Incoming requests go first: they're what the patient has to act on.
            let pending = store.requests.filter { $0.status == .pending }
            if !pending.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow("Requests", trailing: "\(pending.count) pending")
                    ForEach(pending) { RequestCard(request: $0) }
                }
            }
            LedgerCard()
            if let credential = store.credential {
                CredentialPass(credential: credential)
            }

            SharedProofs()
            AuditLog()
        }
    }
}

// MARK: - Ledger

private struct LedgerCard: View {
    @Environment(VaultStore.self) private var store
    @State private var connecting = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Ledger")
            Card {
                HStack(spacing: 14) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(store.patientAddress == nil ? Theme.muted : Theme.accent)
                        .frame(width: 46, height: 46)
                        .background(Theme.raised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.ledger.displayName).lineLimit(1).minimumScaleFactor(0.8).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.text)
                        Text(store.patientAddress?.shortHex ?? "Not paired").font(Theme.mono(13)).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    if store.patientAddress != nil { Pill(text: "Paired") }
                }

                if store.patientAddress == nil {
                    Button {
                        Task { await connect() }
                    } label: {
                        HStack { if connecting { ProgressView().tint(.black) }; Text(connecting ? "Connecting…" : "Connect Ledger") }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(connecting)
                }

                ModeSwitch()
                if let error { Text(error).font(.footnote).foregroundStyle(Theme.danger) }
                if store.ledgerMode == .emulator {
                    Text("Approve on the emulator screen · localhost:5005").font(Theme.mono(11)).foregroundStyle(Theme.faint)
                }
            }
        }
    }

    private func connect() async {
        connecting = true
        defer { connecting = false }
        do { try await store.connectLedger(); error = nil } catch { self.error = error.localizedDescription }
    }
}

private struct ModeSwitch: View {
    @Environment(VaultStore.self) private var store
    var body: some View {
        HStack(spacing: 4) {
            ForEach(VaultStore.LedgerMode.allCases) { mode in
                let on = store.ledgerMode == mode
                Button { store.ledgerMode = mode } label: {
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

// MARK: - Credential

/// Styled like a physical pass.
private struct CredentialPass: View {
    let credential: Credential

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Credential", trailing: "Issuer-signed")
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("VACCINE RECORD").font(Theme.mono(11, .bold)).tracking(2).foregroundStyle(Theme.accent)
                        Text(credential.issuer).font(.system(size: 20, weight: .heavy)).foregroundStyle(Theme.text)
                    }
                    Spacer()
                    Image(systemName: "cross.case.fill").font(.system(size: 22)).foregroundStyle(Theme.text.opacity(0.85))
                }

                VStack(spacing: 10) {
                    ForEach(Claim.allCases) { claim in
                        let ok = credential.value(of: claim) == true
                        HStack(spacing: 12) {
                            Check(ok: ok)
                            Text(claim.label).font(.system(size: 15, weight: .medium)).foregroundStyle(ok ? Theme.text : Theme.muted)
                            Spacer()
                        }
                    }
                }

                HStack {
                    meta("Holder", credential.holder.shortHex)
                    Spacer()
                    meta("Valid until", credential.validUntil.formatted(.dateTime.month(.abbreviated).day().year()))
                }
            }
            .padding(20)
            .background(
                LinearGradient(colors: [Color(red: 0.13, green: 0.15, blue: 0.11), Theme.surface],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.accent.opacity(0.25)))

            Text("Only you see this. Providers get proof of just the facts they ask for.")
                .font(.footnote).foregroundStyle(Theme.faint).padding(.horizontal, 4)
        }
    }

    private func meta(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased()).font(Theme.mono(9, .semibold)).tracking(1.4).foregroundStyle(Theme.faint)
            Text(value).font(Theme.mono(13, .medium)).foregroundStyle(Theme.text)
        }
    }
}

// MARK: - Requests

private struct RequestCard: View {
    @Environment(VaultStore.self) private var store
    let request: AccessRequest
    @State private var approving = false
    @State private var error: String?

    var body: some View {
        Card(padding: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(request.verifier).font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.text)
                    if !request.purpose.isEmpty { Text(request.purpose).font(.subheadline).foregroundStyle(Theme.muted) }
                }
                Spacer()
                Pill(text: "\(Int(request.duration / 60)) min", color: Theme.warn)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("WANTS PROOF OF").font(Theme.mono(10, .semibold)).tracking(1.4).foregroundStyle(Theme.faint)
                ForEach(request.claims) { claim in
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.up.right").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.accent)
                        Text(claim.label).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.text)
                    }
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "eye.slash").foregroundStyle(Theme.muted)
                Text("Name, birth date, dose dates and \(Claim.allCases.count - request.claims.count) other facts stay hidden")
                    .font(.caption).foregroundStyle(Theme.muted)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.raised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            if approving {
                HStack(spacing: 12) {
                    ProgressView().tint(Theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Check your Ledger").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.text)
                        Text("Review the consent, then hold to sign").font(.caption).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Pill(text: "Awaiting", color: Theme.accent, pulsing: true)
                }
                .padding(.top, 4)
            } else {
                HStack(spacing: 10) {
                    Button("Reject") { store.deny(request.id) }
                        .buttonStyle(GhostButtonStyle(color: Theme.danger))
                        .frame(width: 110)
                    Button("Approve on Ledger") { Task { await approve() } }
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
            if let error { Text(error).font(.footnote).foregroundStyle(Theme.danger) }
        }
    }

    private func approve() async {
        approving = true
        defer { approving = false }
        do { try await store.approve(request.id); error = nil } catch { self.error = error.localizedDescription }
    }
}

// MARK: - Shared proofs

private struct SharedProofs: View {
    @Environment(VaultStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Shared proofs")
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                let active = store.grants.filter { $0.expiresAt > ctx.date }
                VStack(spacing: 10) {
                    if active.isEmpty {
                        Card { Text("No provider holds a valid proof").foregroundStyle(Theme.muted) }
                    }
                    ForEach(active) { grant in
                        let total = store.requests.first { $0.id == grant.requestID }?.duration ?? 60
                        let left = grant.expiresAt.timeIntervalSince(ctx.date)
                        Card {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(grant.verifier).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.text)
                                    Text(grant.presentation.revealed.map(\.claim.label).joined(separator: " · "))
                                        .font(.caption).foregroundStyle(Theme.muted)
                                }
                                Spacer()
                                Text(timerInterval: ctx.date...grant.expiresAt, countsDown: true)
                                    .font(Theme.mono(15, .bold)).foregroundStyle(Theme.accent).monospacedDigit()
                            }
                            ProgressView(value: max(0, min(1, left / max(total, 1))))
                                .tint(Theme.accent)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Audit

private struct AuditLog: View {
    @Environment(VaultStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Audit log", trailing: "\(store.audit.count) events")
            Card(padding: 14) {
                if store.audit.isEmpty { Text("Nothing yet").font(Theme.mono(12)).foregroundStyle(Theme.faint) }
                ForEach(store.audit) { entry in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(entry.at.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute().second()))
                            .font(Theme.mono(11)).foregroundStyle(Theme.faint)
                        Text(entry.event.rawValue.uppercased()).font(Theme.mono(11, .bold))
                            .foregroundStyle(color(entry.event)).frame(width: 74, alignment: .leading)
                        Text("\(entry.actor) — \(entry.detail)").font(Theme.mono(11)).foregroundStyle(Theme.muted)
                            .lineLimit(2)
                    }
                }
            }
        }
    }

    private func color(_ e: AuditEntry.Event) -> Color {
        switch e {
        case .approved, .verified, .issued, .paired: Theme.accent
        case .denied, .expired: Theme.danger
        case .requested: Theme.warn
        }
    }
}
