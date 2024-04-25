// Copyright 2023-2024 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import HyBid
import UIKit


final class VerveAdapter: PartnerAdapter {
    private let APP_TOKEN_KEY: String = "app_token"

    /// The version of the partner SDK.
    let partnerSDKVersion = HyBid.sdkVersion() ?? "Unknown"  // SDK returns an optional string
    
    /// The version of the adapter.
    /// It should have either 5 or 6 digits separated by periods, where the first digit is Chartboost Mediation SDK's major version, the last digit is the adapter's build version, and intermediate digits are the partner SDK's version.
    /// Format: `<Chartboost Mediation major version>.<Partner major version>.<Partner minor version>.<Partner patch version>.<Partner build version>.<Adapter build version>` where `.<Partner build version>` is optional.
    let adapterVersion = "4.2.21.0.0"
    
    /// The partner's unique identifier.
    let partnerID = "verve"
    
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
    func setUp(with configuration: PartnerConfiguration, completion: @escaping (Result<PartnerDetails, Error>) -> Void) {
        log(.setUpStarted)

        guard let appToken = configuration.credentials[APP_TOKEN_KEY] as? String else {
            let error = error(.initializationFailureInvalidCredentials, description: "The app token was invalid")
            log(.setUpFailed(error))
            completion(.failure(error))
            return
        }

        // Apply initial consents
        setConsents(configuration.consents, modifiedKeys: Set(configuration.consents.keys))
        setIsUserUnderage(configuration.isUserUnderage)

        HyBid.initWithAppToken(appToken) { success in
            if success {
                self.log(.setUpSucceded)
                completion(.success([:]))
            } else {
                let error = self.error(.initializationFailureUnknown)
                self.log(.setUpFailed(error))
                completion(.failure(error))
            }
        }
    }
    
    /// Fetches bidding tokens needed for the partner to participate in an auction.
    /// - parameter request: Information about the ad load request.
    /// - parameter completion: Closure to be performed with the fetched info.
    func fetchBidderInformation(request: PartnerAdPreBidRequest, completion: @escaping (Result<[String : String], Error>) -> Void) {
        log(.fetchBidderInfoStarted(request))
        let signalData = HyBid.getCustomRequestSignalData("cb")
        log(.fetchBidderInfoSucceeded(request))
        completion(.success(signalData.map { ["signal_data": $0] } ?? [:]))
    }
    
    /// Indicates that the user consent has changed.
    /// - parameter consents: The new consents value, including both modified and unmodified consents.
    /// - parameter modifiedKeys: A set containing all the keys that changed.
    func setConsents(_ consents: [ConsentKey: ConsentValue], modifiedKeys: Set<ConsentKey>) {
        // GDPR
        if modifiedKeys.contains(partnerID) || modifiedKeys.contains(ConsentKeys.gdprConsentGiven) {
            let consent = consents[partnerID] ?? consents[ConsentKeys.gdprConsentGiven]
            switch consent {
            case ConsentValues.granted:
                HyBidUserDataManager.sharedInstance().grantConsent()
                log(.privacyUpdated(setting: "GDPR", value: "grantConsent"))
            case ConsentValues.denied:
                HyBidUserDataManager.sharedInstance().denyConsent()
                log(.privacyUpdated(setting: "GDPR", value: "denyConsent"))
            default:
                break   // do nothing
            }
        }

        // TCF
        if modifiedKeys.contains(ConsentKeys.tcf), let tcfString = consents[ConsentKeys.tcf] {
            HyBidUserDataManager.sharedInstance().setIABGDPRConsentString(tcfString)
            log(.privacyUpdated(setting: "IABGDPRConsentString", value: tcfString))
        }

        // CCPA
        if modifiedKeys.contains(ConsentKeys.usp), let uspString = consents[ConsentKeys.usp] {
            HyBidUserDataManager.sharedInstance().setIABUSPrivacyString(uspString)
            log(.privacyUpdated(setting: "IABUSPrivacyString", value: uspString))
        }
    }

    /// Indicates that the user is underage signal has changed.
    /// - parameter isUserUnderage: `true` if the user is underage as determined by the publisher, `false` otherwise.
    func setIsUserUnderage(_ isUserUnderage: Bool) {
        // No COPPA methods available on HyBidUserDataManager
    }

    /// Creates a new banner ad object in charge of communicating with a single partner SDK ad instance.
    /// Chartboost Mediation SDK calls this method to create a new ad for each new load request. Ad instances are never reused.
    /// Chartboost Mediation SDK takes care of storing and disposing of ad instances so you don't need to.
    /// ``PartnerAd/invalidate()`` is called on ads before disposing of them in case partners need to perform any custom logic before the
    /// object gets destroyed.
    /// If, for some reason, a new ad cannot be provided, an error should be thrown.
    /// Chartboost Mediation SDK will always call this method from the main thread.
    /// - parameter request: Information about the ad load request.
    /// - parameter delegate: The delegate that will receive ad life-cycle notifications.
    func makeBannerAd(request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) throws -> PartnerBannerAd {
        // This partner supports multiple loads for the same partner placement.
        VerveAdapterBannerAd(adapter: self, request: request, delegate: delegate)
    }

    /// Creates a new ad object in charge of communicating with a single partner SDK ad instance.
    /// Chartboost Mediation SDK calls this method to create a new ad for each new load request. Ad instances are never reused.
    /// Chartboost Mediation SDK takes care of storing and disposing of ad instances so you don't need to.
    /// ``PartnerAd/invalidate()`` is called on ads before disposing of them in case partners need to perform any custom logic before the
    /// object gets destroyed.
    /// If, for some reason, a new ad cannot be provided, an error should be thrown.
    /// - parameter request: Information about the ad load request.
    /// - parameter delegate: The delegate that will receive ad life-cycle notifications.
    func makeFullscreenAd(request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) throws -> PartnerFullscreenAd {
        // This partner supports multiple loads for the same partner placement.
        switch request.format {
        case PartnerAdFormats.interstitial:
            return VerveAdapterInterstitialAd(adapter: self, request: request, delegate: delegate)
        case PartnerAdFormats.rewarded:
            return VerveAdapterRewardedAd(adapter: self, request: request, delegate: delegate)
        default:
            throw error(.loadFailureUnsupportedAdFormat)
        }
    }
}
