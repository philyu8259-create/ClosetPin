import Foundation

struct ProEntitlement: Equatable {
    let isPro: Bool
    let productID: String?
    let purchaseDate: Date?
    let expirationDate: Date?

    static let monthlyProductID = "closetpin.pro.monthly"
    static let yearlyProductID = "closetpin.pro.yearly"
    static let productIDs = [monthlyProductID, yearlyProductID]

    static let freeTrialDays = 7
    static let englishPrivacyURL = URL(string: "https://xufanzhilian.com/closetpin/en/privacy/")!
    static let chinesePrivacyURL = URL(string: "https://xufanzhilian.com/closetpin/zh/privacy/")!
    static let englishSupportURL = URL(string: "https://xufanzhilian.com/closetpin/en/support/")!
    static let chineseSupportURL = URL(string: "https://xufanzhilian.com/closetpin/zh/support/")!
    static var privacyURL: URL { usesChineseLegalPages ? chinesePrivacyURL : englishPrivacyURL }
    static var supportURL: URL { usesChineseLegalPages ? chineseSupportURL : englishSupportURL }
    static let appleStandardEULAURL = URL(
        string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
    )!

    private static var usesChineseLegalPages: Bool {
        Locale.current.language.languageCode?.identifier.hasPrefix("zh") == true
    }

    init(isPro: Bool = false, productID: String? = nil, purchaseDate: Date? = nil, expirationDate: Date? = nil) {
        self.isPro = isPro
        self.productID = productID
        self.purchaseDate = purchaseDate
        self.expirationDate = expirationDate
    }

    static let inactive: ProEntitlement = ProEntitlement()
}
