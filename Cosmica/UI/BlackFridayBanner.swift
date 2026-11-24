import SwiftUI

/// v4.0.6 — one-line Black Friday banner on the Observatory (same shape as the Seasonal Trail
/// banner). Shown only while `BlackFridaySale.onSale` is true for the bundle this player can
/// buy; tapping it opens the Shop, where the premium card carries the sale tag.
struct BlackFridayBanner: View {
    @Environment(IAPManager.self) private var iap
    @Environment(NotificationManager.self) private var notif

    private static let tint = Color(red: 1.0, green: 0.72, blue: 0.25)

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { ctx in
            if let id = BlackFridaySale.productId(for: iap.premiumOffer),
               let product = iap.product(for: id),
               BlackFridaySale.onSale(now: ctx.date, price: product.price,
                                      regular: BlackFridaySale.regular(id)?.price) {
                Button { notif.pendingTab = .shop } label: {
                    row(name: id == IAPManager.ultimateBundleProductId ? "Ultimate Bundle" : "Deluxe Upgrade",
                        price: product.displayPrice, now: ctx.date)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.top, 2)
            }
        }
    }

    private func row(name: String, price: String, now: Date) -> some View {
        let tint = Self.tint
        return HStack(spacing: 10) {
            Image(systemName: "tag.fill").foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 1) {
                Text("Black Friday Sale").font(.subheadline.bold()).foregroundStyle(.white)
                Text("\(name) \(price)").font(.caption).foregroundStyle(tint)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            Spacer()
            Text("\(Formatter.duration(BlackFridaySale.end.timeIntervalSince(now))) left")
                .font(.caption.bold()).foregroundStyle(tint).monospacedDigit()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            LinearGradient(colors: [tint.opacity(0.26), tint.opacity(0.08)], startPoint: .leading, endPoint: .trailing),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(tint.opacity(0.5), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the Shop")
    }
}
