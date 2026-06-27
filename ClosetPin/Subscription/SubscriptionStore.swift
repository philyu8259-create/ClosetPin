import Foundation
import StoreKit

@MainActor
final class SubscriptionStore: ObservableObject {
    enum PurchaseState: Equatable {
        case idle
        case loading
        case purchasing
        case restoring
    }

    enum PurchaseOutcome: Equatable {
        case success
        case userCancelled
        case pending
        case productUnavailable
        case failed
        case unverified
    }

    @Published private(set) var entitlement: ProEntitlement = .inactive
    @Published private(set) var products: [Product] = []
    @Published private(set) var state: PurchaseState = .idle
    @Published private(set) var statusMessage: String?

    var isPro: Bool {
        entitlement.isPro
    }

    private var purchasedProduct: [String: Product] = [:]
    private var updatesTask: Task<Void, Never>?

    init() {
        startListeningForUpdates()
        Task {
            await syncEntitlement()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts() async {
        state = .loading
        statusMessage = nil
        defer { state = .idle }

        do {
            let fetchedProducts = try await Product.products(for: ProEntitlement.productIDs)
            let orderedProducts = ProEntitlement.productIDs.compactMap { productID in
                fetchedProducts.first(where: { $0.id == productID })
            }
            products = orderedProducts
            purchasedProduct = Dictionary(uniqueKeysWithValues: orderedProducts.map { ($0.id, $0) })
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        state = .restoring
        statusMessage = nil
        defer { state = .idle }

        do {
            try await AppStore.sync()
            await syncEntitlement()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func syncEntitlement() async {
        entitlement = await currentEntitlement()
    }

    func purchase(productID: String) async -> PurchaseOutcome {
        guard let product = purchasedProduct[productID] else {
            return .productUnavailable
        }

        state = .purchasing
        statusMessage = nil
        defer { state = .idle }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verificationResult):
                switch verificationResult {
                case .verified(let transaction):
                    await transaction.finish()
                    await syncEntitlement()
                    return .success
                case .unverified:
                    return .unverified
                }
            case .userCancelled:
                return .userCancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed
            }
        } catch {
            statusMessage = error.localizedDescription
            return .failed
        }
    }

    func fallbackPrice(for productID: String) -> String {
        switch productID {
        case ProEntitlement.monthlyProductID:
            "$2.99"
        case ProEntitlement.yearlyProductID:
            "$17.99"
        default:
            ""
        }
    }

    func product(for productID: String) -> Product? {
        purchasedProduct[productID] ?? products.first(where: { $0.id == productID })
    }

    private func startListeningForUpdates() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = update {
                    await transaction.finish()
                    await self.syncEntitlement()
                }
            }
        }
    }

    private func currentEntitlement() async -> ProEntitlement {
        var found: ProEntitlement = .inactive

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard ProEntitlement.productIDs.contains(transaction.productID) else { continue }
            guard isTransactionActive(transaction) else { continue }

            if found.expirationDate == nil {
                found = ProEntitlement(
                    isPro: true,
                    productID: transaction.productID,
                    purchaseDate: transaction.purchaseDate,
                    expirationDate: transaction.expirationDate
                )
                continue
            }

            if let currentExpiration = found.expirationDate,
               let transactionExpiration = transaction.expirationDate,
               transactionExpiration > currentExpiration {
                found = ProEntitlement(
                    isPro: true,
                    productID: transaction.productID,
                    purchaseDate: transaction.purchaseDate,
                    expirationDate: transaction.expirationDate
                )
            }
        }

        return found
    }

    private func isTransactionActive(_ transaction: Transaction) -> Bool {
        guard transaction.revocationDate == nil else { return false }
        guard let expirationDate = transaction.expirationDate else { return true }
        return expirationDate > Date()
    }
}
