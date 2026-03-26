import SwiftUI

// MARK: - WatchProUpsellView

struct WatchProUpsellView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {

                // Icon with glow
                ZStack {
                    Circle()
                        .fill(Color(hex: 0xFFBB00).opacity(0.15))
                        .frame(width: 60, height: 60)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xFFBB00))
                }
                .padding(.top, 4)

                // Title
                VStack(spacing: 2) {
                    Text("CHASE THE LIGHT")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(Color(hex: 0xFFBB00))
                        .tracking(1.5)
                    Text("Pro")
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundStyle(.white)
                }

                // Watch + lock icon row
                HStack(spacing: 6) {
                    Image(systemName: "applewatch")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.7))
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: 0xFFBB00).opacity(0.8))
                }

                // Unlock message
                Text("Upgrade in the Chase the Light iPhone app to unlock Chase the Light on your Apple Watch")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
            }
        }
        .background(Color(hex: 0x050B14))
        .containerBackground(Color(hex: 0x050B14), for: .navigation)
    }
}
