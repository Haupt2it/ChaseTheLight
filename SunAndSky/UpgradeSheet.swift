import SwiftUI

// MARK: - UpgradeSheet

struct UpgradeSheet: View {
    @EnvironmentObject private var proManager: ProManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // ── Background: deep-night-sky-to-golden-dusk gradient ─────
            LinearGradient(
                stops: [
                    .init(color: Color(hex: 0x020810), location: 0.00),
                    .init(color: Color(hex: 0x12062A), location: 0.30),
                    .init(color: Color(hex: 0x3D1500), location: 0.62),
                    .init(color: Color(hex: 0x0A1628), location: 1.00),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {

                    // ── Dismiss ──────────────────────────────────────────
                    HStack {
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                    // ── Hero icon ────────────────────────────────────────
                    ZStack {
                        Circle()
                            .fill(Color(hex: 0xFFBB00).opacity(0.08))
                            .frame(width: 140, height: 140)
                        Circle()
                            .fill(Color(hex: 0xFFBB00).opacity(0.14))
                            .frame(width: 104, height: 104)
                        Image(systemName: "sun.horizon.fill")
                            .font(.system(size: 54))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(hex: 0xFFDD44), Color(hex: 0xFF8800)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .shadow(color: Color(hex: 0xFFBB00).opacity(0.55), radius: 22, x: 0, y: 0)
                    }
                    .padding(.top, 16)

                    // ── Title block ──────────────────────────────────────
                    VStack(spacing: 6) {
                        Text("CHASE THE LIGHT")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(Color(hex: 0xFFBB00))
                            .tracking(2.5)

                        Text("Pro")
                            .font(.system(size: 58, weight: .heavy))
                            .foregroundStyle(.white)
                            .shadow(color: Color(hex: 0xFFBB00).opacity(0.25), radius: 16)

                        Text("Never miss the perfect light")
                            .font(.system(size: 19).italic())
                            .foregroundStyle(.white.opacity(0.72))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 18)

                    // ── Feature list ─────────────────────────────────────
                    VStack(alignment: .leading, spacing: 18) {
                        UpgradeFeatureRow(text: "Departure reminders for sunrise & sunset")
                        UpgradeFeatureRow(text: "Golden Hour & Blue Hour alerts")
                        UpgradeFeatureRow(text: "Custom lead time — set how early to leave")
                        UpgradeFeatureRow(text: "Full light phase countdowns")
                        UpgradeFeatureRow(text: "24-hour forecast strip")
                        UpgradeFeatureRow(text: "Live satellite imagery")
                    }
                    .padding(.horizontal, 36)
                    .padding(.top, 40)

                    // ── Divider ──────────────────────────────────────────
                    Rectangle()
                        .fill(.white.opacity(0.08))
                        .frame(height: 1)
                        .padding(.horizontal, 36)
                        .padding(.top, 36)

                    // ── Purchase button ───────────────────────────────────
                    Button {
                        Task { await proManager.purchase() }
                    } label: {
                        ZStack {
                            if proManager.isLoading {
                                ProgressView().tint(Color(hex: 0x0A0A0A))
                            } else {
                                Text("Unlock Pro — \(proManager.priceString)")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(Color(hex: 0x0D0D0D))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 62)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: 0xFFDD00), Color(hex: 0xFF9500)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 18)
                        )
                        .shadow(color: Color(hex: 0xFFAA00).opacity(0.40), radius: 16, x: 0, y: 6)
                    }
                    .disabled(proManager.isLoading)
                    .padding(.horizontal, 24)
                    .padding(.top, 28)

                    // ── Restore ───────────────────────────────────────────
                    Button {
                        Task { await proManager.restorePurchases() }
                    } label: {
                        Text("Restore Purchase")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.50))
                    }
                    .padding(.top, 18)

                    // ── Purchase error ────────────────────────────────────
                    if let err = proManager.purchaseError {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundStyle(.red.opacity(0.80))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .padding(.top, 12)
                    }

                    // ── Legal note ────────────────────────────────────────
                    Text("One-time purchase · No subscription · No ads")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.28))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 20)
                        .padding(.bottom, 44)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - UpgradeFeatureRow

private struct UpgradeFeatureRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(Color(hex: 0xFFBB00))
                .frame(width: 26)
            Text(text)
                .font(.system(size: 17))
                .foregroundStyle(.white.opacity(0.88))
            Spacer()
        }
    }
}

// MARK: - ProBadge  (shared across the app)

struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.system(size: 11, weight: .black))
            .foregroundStyle(Color(hex: 0xFFBB00))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Color(hex: 0xFFBB00).opacity(0.16), in: Capsule())
            .overlay(Capsule().strokeBorder(Color(hex: 0xFFBB00).opacity(0.50), lineWidth: 1))
    }
}
