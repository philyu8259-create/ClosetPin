import XCTest
@testable import ClosetPin

final class SubscriptionStoreTests: XCTestCase {
    func testProEntitlementProductIDsAreConfiguredAsRequired() {
        XCTAssertEqual(
            Set(ProEntitlement.productIDs),
            Set([
                ProEntitlement.monthlyProductID,
                ProEntitlement.yearlyProductID
            ]),
            "Subscription product identifiers should include the monthly and yearly constants."
        )

        XCTAssertEqual(ProEntitlement.monthlyProductID, "closetpin.pro.monthly")
        XCTAssertEqual(ProEntitlement.yearlyProductID, "closetpin.pro.yearly")
    }

    func testProEntitlementLegalURLsUseConfiguredConstants() {
        let usesChineseLegalPages = Locale.current.language.languageCode?.identifier.hasPrefix("zh") == true
        let expectedPrivacyPath = usesChineseLegalPages ? "/closetpin/zh/privacy/" : "/closetpin/en/privacy/"
        let expectedSupportPath = usesChineseLegalPages ? "/closetpin/zh/support/" : "/closetpin/en/support/"

        XCTAssertEqual(
            ProEntitlement.privacyURL.absoluteString,
            "https://xufanzhilian.com\(expectedPrivacyPath)"
        )

        XCTAssertEqual(
            ProEntitlement.supportURL.absoluteString,
            "https://xufanzhilian.com\(expectedSupportPath)"
        )

        XCTAssertEqual(
            ProEntitlement.appleStandardEULAURL.absoluteString,
            "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
        )
    }

    func testInactiveProEntitlementDefaults() {
        XCTAssertFalse(ProEntitlement.inactive.isPro)
        XCTAssertNil(ProEntitlement.inactive.productID)
        XCTAssertNil(ProEntitlement.inactive.purchaseDate)
        XCTAssertNil(ProEntitlement.inactive.expirationDate)
        XCTAssertEqual(ProEntitlement.freeTrialDays, 7)
    }
}
