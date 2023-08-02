// Copyright 2022-2023 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import HyBid
import UIKit


final class VerveAdapter: PartnerAdapter {
    private let APP_TOKEN_KEY: String = "app_token"

    /// Verve uses the app token as a bidding token
    var appToken: String? = nil

    /// The version of the partner SDK.
    let partnerSDKVersion = HyBid.sdkVersion() ?? "Unknown"  // SDK returns an optional string
    
    /// The version of the adapter.
    /// It should have either 5 or 6 digits separated by periods, where the first digit is Chartboost Mediation SDK's major version, the last digit is the adapter's build version, and intermediate digits are the partner SDK's version.
    /// Format: `<Chartboost Mediation major version>.<Partner major version>.<Partner minor version>.<Partner patch version>.<Partner build version>.<Adapter build version>` where `.<Partner build version>` is optional.
    let adapterVersion = "4.2.18.1.0"
    
    /// The partner's unique identifier.
    let partnerIdentifier = "verve"
    
    /// The human-friendly partner name.
    let partnerDisplayName = "Verve"
    
    /// The designated initializer for the adapter.
    /// Chartboost Mediation SDK will use this constructor to create instances of conforming types.
    /// - parameter storage: An object that exposes storage managed by the Chartboost Mediation SDK to the adapter.
    /// It includes a list of created `PartnerAd` instances. You may ignore this parameter if you don't need it.
    init(storage: PartnerAdapterStorage) {
        // Perform any initialization tasks that are needed prior to setUp() here.
        // You may keep a reference to `storage` and use it later to gather some information from previously created ads.
    }
    
    /// Does any setup needed before beginning to load ads.
    /// - parameter configuration: Configuration data for the adapter to set up.
    /// - parameter completion: Closure to be performed by the adapter when it's done setting up. It should include an error indicating the cause for failure or `nil` if the operation finished successfully.
    func setUp(with configuration: PartnerConfiguration, completion: @escaping (Error?) -> Void) {
        log(.setUpStarted)

        guard let appToken = configuration.credentials[APP_TOKEN_KEY] as? String else {
            let error = error(.initializationFailureInvalidCredentials, description: "The app token was invalid")
            log(.setUpFailed(error))
            completion(error)
            return
        }
        self.appToken = appToken

        HyBid.initWithAppToken(appToken) { success in
            if success {
                self.log(.setUpSucceded)
                completion(nil)
            } else {
                let error = self.error(.initializationFailureUnknown)
                self.log(.setUpFailed(error))
                completion(error)
            }
        }
    }
    
    /// Fetches bidding tokens needed for the partner to participate in an auction.
    /// - parameter request: Information about the ad load request.
    /// - parameter completion: Closure to be performed with the fetched info.
    func fetchBidderInformation(request: PreBidRequest, completion: @escaping ([String : String]?) -> Void) {
        guard let appToken else {
            let error = error(.prebidFailureInvalidArgument, description: "App token is empty")
            log(.fetchBidderInfoFailed(request, error: error))
            completion([:])
            return
        }
        completion(["app_auth_token": appToken])
    }
    
    /// Indicates if GDPR applies or not and the user's GDPR consent status.
    /// - parameter applies: `true` if GDPR applies, `false` if not, `nil` if the publisher has not provided this information.
    /// - parameter status: One of the `GDPRConsentStatus` values depending on the user's preference.
    func setGDPR(applies: Bool?, status: GDPRConsentStatus) {
        if status == .granted {
            HyBidUserDataManager.sharedInstance().grantConsent()
            log(.privacyUpdated(setting: "GDPR", value: "grantConsent"))
        } else if status == .denied {
            HyBidUserDataManager.sharedInstance().denyConsent()
            log(.privacyUpdated(setting: "GDPR", value: "denyConsent"))
        }
    }
    
    /// Indicates the CCPA status both as a boolean and as an IAB US privacy string.
    /// - parameter hasGivenConsent: A boolean indicating if the user has given consent.
    /// - parameter privacyString: An IAB-compliant string indicating the CCPA status.
    func setCCPA(hasGivenConsent: Bool, privacyString: String) {
        HyBidUserDataManager.sharedInstance().setIABUSPrivacyString(privacyString)
        log(.privacyUpdated(setting: "IABUSPrivacyString", value: privacyString))
    }
    
    /// Indicates if the user is subject to COPPA or not.
    /// - parameter isChildDirected: `true` if the user is subject to COPPA, `false` otherwise.
    func setCOPPA(isChildDirected: Bool) {
        // No COPPA methods available on HyBidUserDataManager
    }
    
    /// Creates a new ad object in charge of communicating with a single partner SDK ad instance.
    /// Chartboost Mediation SDK calls this method to create a new ad for each new load request. Ad instances are never reused.
    /// Chartboost Mediation SDK takes care of storing and disposing of ad instances so you don't need to.
    /// `invalidate()` is called on ads before disposing of them in case partners need to perform any custom logic before the object gets destroyed.
    /// If, for some reason, a new ad cannot be provided, an error should be thrown.
    /// - parameter request: Information about the ad load request.
    /// - parameter delegate: The delegate that will receive ad life-cycle notifications.
    func makeAd(request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) throws -> PartnerAd {
        switch request.format {
        case .banner:
            return VerveAdapterBannerAd(adapter: self, request: request, delegate: delegate)
        case .interstitial:
            return VerveAdapterInterstitialAd(adapter: self, request: request, delegate: delegate)
        case .rewarded:
            return VerveAdapterRewardedAd(adapter: self, request: request, delegate: delegate)
        default:
            throw error(.loadFailureUnsupportedAdFormat)
        }
    }
}
