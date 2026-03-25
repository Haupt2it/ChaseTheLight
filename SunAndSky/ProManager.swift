import Foundation
import Combine
import StoreKit

// MARK: - ProManager

@MainActor
final class ProManager: ObservableObject {

    static let productID = "com.Haupt2it.ChaseTheLight.pro"

    @Published private(set) var isPro:         Bool     = false
    @Published private(set) var product:       Product?
    @Published private(set) var purchaseError: String?
    @Published private(set) var isLoading:     Bool     = false

    // nonisolated(unsafe) lets deinit cancel the task without actor-isolation errors
    nonisolated(unsafe) private var updateListener: Task<Void, Never>?

    init() {
        isPro = UserDefaults.standard.bool(forKey: "proUnlocked")
        updateListener = makeTransactionListener()
        Task {
            await loadProduct()
            await verifyEntitlements()
        }
    }

    deinit {
        updateListener?.cancel()
    }

    // MARK: - Public API

    func purchase() async {
        guard let product else {
            purchaseError = "Product unavailable — please try again later."
            return
        }
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let tx = try checkVerified(verification)
                await tx.finish()
                setPro(true)
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    func restorePurchases() async {
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await verifyEntitlements()
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    /// Displayed price from App Store, falls back to hard-coded string before product loads.
    var priceString: String { product?.displayPrice ?? "$1.99" }

    // MARK: - Private

    private func loadProduct() async {
        guard let products = try? await Product.products(for: [Self.productID]) else { return }
        product = products.first
    }

    private func verifyEntitlements() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               tx.productID == Self.productID,
               tx.revocationDate == nil {
                setPro(true)
                return
            }
        }
    }

    private func makeTransactionListener() -> Task<Void, Never> {
        // Runs on main actor (inherited from @MainActor init context)
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let tx) = result,
                   tx.productID == ProManager.productID,
                   tx.revocationDate == nil {
                    self.setPro(true)
                    await tx.finish()
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        guard case .verified(let value) = result else { throw ProError.failedVerification }
        return value
    }

    private func setPro(_ value: Bool) {
        isPro = value
        UserDefaults.standard.set(value, forKey: "proUnlocked")
    }
}

private enum ProError: Error { case failedVerification }
