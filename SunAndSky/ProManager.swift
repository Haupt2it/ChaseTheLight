import Foundation
import Combine
import StoreKit
import WatchConnectivity

// MARK: - ProManager

@MainActor
final class ProManager: NSObject, ObservableObject {

    static let productID = "com.Haupt2it.ChaseTheLight.pro"

    @Published private(set) var isPro:         Bool     = false
    @Published private(set) var product:       Product?
    @Published private(set) var purchaseError: String?
    @Published private(set) var isLoading:     Bool     = false

    // nonisolated(unsafe) lets deinit cancel the task without actor-isolation errors
    nonisolated(unsafe) private var updateListener: Task<Void, Never>?

    override init() {
        isPro = UserDefaults.standard.bool(forKey: "proUnlocked")
        super.init()
        updateListener = makeTransactionListener()
        Task {
            await loadProduct()
            await verifyEntitlements()
        }
        setupWatchConnectivity()
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
        syncToWatch()
    }

    // MARK: - WatchConnectivity

    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Push current Pro status and alert settings to the watch.
    func syncToWatch() {
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated,
              WCSession.default.isWatchAppInstalled else { return }

        let ud = UserDefaults.standard
        let ctx: [String: Any] = [
            "isPro":                    isPro,
            "sunriseAlertEnabled":      ud.bool(forKey: "sunriseAlertEnabled"),
            "sunriseLeadMinutes":       ud.object(forKey: "sunriseLeadMinutes") as? Int ?? 15,
            "sunsetAlertEnabled":       ud.bool(forKey: "sunsetAlertEnabled"),
            "sunsetLeadMinutes":        ud.object(forKey: "sunsetLeadMinutes") as? Int ?? 15,
            "goldenHourAlertEnabled":   ud.bool(forKey: "goldenHourAlertEnabled"),
            "blueHourAlertEnabled":     ud.bool(forKey: "blueHourAlertEnabled"),
        ]
        try? WCSession.default.updateApplicationContext(ctx)
    }
}

// MARK: - WCSessionDelegate

extension ProManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith state: WCSessionActivationState,
                             error: Error?) {
        if state == .activated {
            Task { @MainActor in self.syncToWatch() }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
}

private enum ProError: Error { case failedVerification }
