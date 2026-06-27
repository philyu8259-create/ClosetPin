import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @ObservedObject var store: SubscriptionStore

    @State private var pendingProductID: String?
    @State private var actionMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    if store.isPro {
                        statusCard(
                            systemImage: "checkmark.seal.fill",
                            text: L10n.text("subscription.status.active")
                        )
                    }

                    pricingCard

                    if let actionMessage {
                        statusCard(
                            systemImage: "info.circle.fill",
                            text: actionMessage
                        )
                    }

                    legalCard

                    restoreCard
                }
                .padding(DesignSystem.Spacing.lg)
                .safeAreaPadding(.bottom, 20)
            }
            .background(DesignSystem.background)
            .navigationTitle(L10n.text("subscription.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.text("common.close"), role: .cancel) {
                        dismiss()
                    }
                }
            }
            .task {
                await store.loadProducts()
                await store.syncEntitlement()
            }
        }
    }

    private var pricingCard: some View {
        LuxurySurfaceCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(L10n.text("subscription.title"))
                        .font(DesignSystem.editorialSectionFont(size: 26))
                        .foregroundStyle(DesignSystem.ink)

                    Text(L10n.text("subscription.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(ProEntitlement.productIDs, id: \.self) { productID in
                        planButton(for: productID)
                    }
                }

                if !store.isPro {
                    Text(L10n.string("subscription.trial_badge", arguments: ProEntitlement.freeTrialDays))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DesignSystem.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DesignSystem.surface)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
                }

                Text(L10n.text("subscription.auto_renewal_notice"))
                    .font(.caption)
                    .foregroundStyle(DesignSystem.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var legalCard: some View {
        LuxurySurfaceCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                paywallSectionHeader(
                    title: L10n.text("subscription.legal.section"),
                    subtitle: L10n.text("subscription.legal.subtitle")
                )

                linkRow(
                    title: L10n.text("subscription.legal.eula"),
                    actionTitle: L10n.text("subscription.legal.open"),
                    systemImage: "doc.text.fill",
                    url: ProEntitlement.appleStandardEULAURL
                )

                linkRow(
                    title: L10n.text("subscription.legal.privacy"),
                    actionTitle: L10n.text("subscription.legal.open"),
                    systemImage: "lock.shield.fill",
                    url: ProEntitlement.privacyURL
                )

                linkRow(
                    title: L10n.text("subscription.legal.support"),
                    actionTitle: L10n.text("subscription.legal.open"),
                    systemImage: "questionmark.circle.fill",
                    url: ProEntitlement.supportURL
                )
            }
        }
    }

    private func paywallSectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(DesignSystem.editorialSectionFont(size: 22))
                .foregroundStyle(DesignSystem.ink)

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(DesignSystem.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var restoreCard: some View {
        LuxurySurfaceCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text(L10n.text("subscription.restore.title"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DesignSystem.ink)

                Text(L10n.text("subscription.restore.body"))
                    .font(.caption)
                    .foregroundStyle(DesignSystem.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)

                Button(L10n.text("subscription.restore.button")) {
                    Task {
                        await store.restorePurchases()
                        if let statusMessage = store.statusMessage {
                            actionMessage = statusMessage
                        } else if store.isPro {
                            actionMessage = L10n.text("subscription.restore.success")
                        } else {
                            actionMessage = L10n.text("subscription.restore.empty")
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(DesignSystem.accent)
                .disabled(store.state == .restoring || store.state == .purchasing)
            }
        }
    }

    private func planButton(for productID: String) -> some View {
        let isPending = pendingProductID == productID
        let title = planTitle(for: productID)
        let price = store.product(for: productID)?.displayPrice ?? L10n.text("subscription.price.loading")

        return Button {
            pendingProductID = productID
            actionMessage = nil
            Task {
                let result = await store.purchase(productID: productID)
                pendingProductID = nil
                actionMessage = resultMessage(for: result)
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(L10n.text("subscription.plan.description"))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.88))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Text(price)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
            }
            .padding(DesignSystem.Spacing.md)
            .background(
                LinearGradient(
                    colors: [DesignSystem.accent, DesignSystem.wine],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
            .overlay {
                if isPending {
                    ProgressView()
                        .tint(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isPending || store.state == .purchasing || store.state == .restoring)
    }

    private func linkRow(
        title: String,
        actionTitle: String,
        systemImage: String,
        url: URL
    ) -> some View {
            Button {
                openURL(url)
            } label: {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DesignSystem.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: DesignSystem.Spacing.md)
                Text(actionTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignSystem.accent)
            }
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func statusCard(systemImage: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(DesignSystem.accent)

            Text(text)
                .font(.footnote.weight(.medium))
                .foregroundStyle(DesignSystem.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.paper)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
    }

    private func planTitle(for productID: String) -> String {
        switch productID {
        case ProEntitlement.monthlyProductID:
            L10n.text("subscription.plan.monthly.title")
        case ProEntitlement.yearlyProductID:
            L10n.text("subscription.plan.yearly.title")
        default:
            L10n.text("subscription.plan.title")
        }
    }

    private func resultMessage(for outcome: SubscriptionStore.PurchaseOutcome) -> String {
        switch outcome {
        case .success:
            L10n.text("subscription.purchase.success")
        case .userCancelled:
            L10n.text("subscription.purchase.cancelled")
        case .pending:
            L10n.text("subscription.purchase.pending")
        case .productUnavailable:
            L10n.text("subscription.purchase.product_unavailable")
        case .unverified:
            L10n.text("subscription.purchase.unverified")
        case .failed:
            store.statusMessage ?? L10n.text("subscription.purchase.failed")
        }
    }
}
