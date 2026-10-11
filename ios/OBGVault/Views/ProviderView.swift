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
            Screen(title: "Verify", subtitle: "Provider") {
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow("New request")
                    Card {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Preset.all, id: \.verifier) { p in
                                    let on = p.verifier == verifier
                                    Button(p.verifier) { apply(p) }
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(on ? .black : Theme.text)
                                        .padding(.horizontal, 12).padding(.vertical, 8)
                                        .background(on ? Theme.accent : Theme.raised, in: Capsule())
                                        .overlay(Capsule().strokeBorder(Theme.hairline))
                                }
                            }
                        }
                        Field(label: "Provider", text: $verifier)
                        Field(label: "Reason", text: $purpose)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow("Ask the patient to prove", trailing: "\(claims.count) selected")
                    Card(padding: 6) {
                        ForEach(Claim.allCases) { claim in
                            let on = claims.contains(claim)
                            Button {
                                if on { claims.remove(claim) } else { claims.insert(claim) }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: on ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 20)).foregroundStyle(on ? Theme.accent : Theme.faint)
                                    Text(claim.label).font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(on ? Theme.text : Theme.muted)
                                    Spacer()
                                }
                                .padding(10).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Card {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ACCESS WINDOW").font(Theme.mono(10, .semibold)).tracking(1.4).foregroundStyle(Theme.faint)
                            Text("\(minutes) min").font(Theme.mono(22, .bold)).foregroundStyle(Theme.text)
                        }
                        Spacer()
                        Stepper("", value: $minutes, in: 1...240).labelsHidden()
                    }
                    Button("Send request") {
                        store.sendRequest(verifier: verifier, purpose: purpose,
                                          claims: Claim.allCases.filter(claims.contains), minutes: minutes)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(verifier.isEmpty || claims.isEmpty)
                    .opacity(verifier.isEmpty || claims.isEmpty ? 0.4 : 1)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow("Requests")
                    if store.requests.isEmpty { Card { Text("None yet").foregroundStyle(Theme.muted) } }
                    ForEach(store.requests) { request in
                        if let grantID = request.grantID {
                            NavigationLink { VerificationView(grantID: grantID) } label: { RequestSummary(request: request) }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("open-proof")
                        } else {
                            RequestSummary(request: request)
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
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
        Card(padding: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(request.verifier).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.text)
                    Text(request.claims.map(\.label).joined(separator: " · ")).font(.caption).foregroundStyle(Theme.muted)
                }
                Spacer()
                switch request.status {
                case .approved:
                    HStack(spacing: 6) {
                        Pill(text: "Proof received")
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.faint)
                    }
                case .pending: Pill(text: "Pending", color: Theme.warn, pulsing: true)
                case .denied: Pill(text: "Denied", color: Theme.danger)
                }
            }
        }
    }
}

struct VerificationView: View {
    @Environment(VaultStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let grantID: String
    @State private var result: Verification??

    var body: some View {
        Screen(title: "Proof", subtitle: "Verification") {
            switch result {
            case .none:
                ProgressView().tint(Theme.accent)
            case .some(.none):
                Card {
                    Label("Proof expired. Ask the patient again.", systemImage: "clock.badge.xmark")
                        .font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.danger)
                }
            case let .some(.some(v)):
                verdict(v)
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow("Checks", trailing: "\(v.checks.filter(\.ok).count)/\(v.checks.count)")
                    Card {
                        ForEach(v.checks) { c in
                            HStack(spacing: 12) {
                                Check(ok: c.ok)
                                Text(c.label).font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.text)
                            }
                        }
                    }
                }
                if let grant = store.grants.first(where: { $0.id == grantID }) { received(grant) }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: { Image(systemName: "chevron.left").foregroundStyle(Theme.text) }
            }
        }
        .navigationBarBackButtonHidden()
        .onAppear { result = .some(store.verify(grantID: grantID)) }
    }

    private func verdict(_ v: Verification) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(systemName: v.ok ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .font(.system(size: 40)).foregroundStyle(v.ok ? Theme.accent : Theme.danger)
                VStack(alignment: .leading, spacing: 2) {
                    Text(v.ok ? "Verified" : "Rejected").font(.system(size: 28, weight: .heavy)).foregroundStyle(Theme.text)
                    Text("Cryptographically checked").font(Theme.mono(11)).foregroundStyle(Theme.muted)
                }
            }
            ForEach(v.revealed, id: \.claim) { d in
                HStack(spacing: 12) {
                    Check(ok: d.value)
                    Text(d.claim.label).font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.text)
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "eye.slash.fill")
                Text("\(v.hiddenCount) other facts stayed hidden, including name and birth date")
            }
            .font(.caption).foregroundStyle(Theme.muted)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((v.ok ? Theme.accent : Theme.danger).opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder((v.ok ? Theme.accent : Theme.danger).opacity(0.35)))
    }

    private func received(_ grant: Grant) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Signed on Ledger")
            VStack(alignment: .leading, spacing: 12) {
                Text(grant.presentation.consentText).font(Theme.mono(12)).foregroundStyle(Theme.accent)
                Rectangle().fill(Theme.hairline).frame(height: 1)
                Text("sig 0x" + grant.presentation.ledgerSignature.hex).font(Theme.mono(10)).foregroundStyle(Theme.faint).lineLimit(3)
                Text("engine \(grant.presentation.engine)").font(Theme.mono(10)).foregroundStyle(Theme.faint)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.hairline))
        }
    }
}
