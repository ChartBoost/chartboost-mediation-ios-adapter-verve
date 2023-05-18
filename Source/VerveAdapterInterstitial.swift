// Copyright 2022-2023 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import HyBid

/// The Chartboost Mediation Verve adapter interstitial ad.
final class VerveAdapterInterstitialAd: VerveAdapterAd, PartnerAd {
    
    /// The partner ad view to display inline. E.g. a banner view.
    /// Should be nil for full-screen ads.
    var inlineView: UIView? { nil }
    
    /// The Verve ad instance.
    var ad: HyBidInterstitialAd?
    
    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.loadStarted)
        // Save completion so that delegate can call it
        loadCompletion = completion

        // Create the ad and set this object as the delegate
        let hyBidAd = HyBidInterstitialAd(zoneID: request.partnerPlacement, andWith: self)
        ad = hyBidAd
        hyBidAd.load()

        // Some adapters assume success and call the completion at this point, but HyBidInterstitialAdDelegate
        // has a interstitialDidLoad() method that will call it on load success
    }
    
    /// Shows a loaded ad.
    /// It will never get called for banner ads. You may leave the implementation blank for that ad format.
    /// - parameter viewController: The view controller on which the ad will be presented on.
    /// - parameter completion: Closure to be performed once the ad has been shown.
    func show(with viewController: UIViewController, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.showStarted)

        guard let ad = ad, ad.isReady == true else {
            let error = error(.showFailureAdNotReady)
            log(.showFailed(error))
            completion(.failure(error))
            return
        }
        showCompletion = completion

        ad.show()
    }
}


extension VerveAdapterInterstitialAd: HyBidInterstitialAdDelegate
{
    func interstitialDidLoad() {
        log(.loadSucceeded)
        loadCompletion?(.success([:])) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func interstitialDidFailWithError(_ error: Error!) {
        let error = error ?? self.error(.loadFailureUnknown)
        log(.loadFailed(error))
        loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func interstitialDidTrackClick() {
        log(.didClick(error: nil))
        delegate?.didClick(self, details: [:]) ?? log(.delegateUnavailable)
    }

    func interstitialDidTrackImpression() {
        log(.didTrackImpression)
        showCompletion?(.success([:])) ?? log(.showResultIgnored)
        showCompletion = nil
        delegate?.didTrackImpression(self, details: [:]) ?? log(.delegateUnavailable)
    }

    func interstitialDidDismiss() {
        log(.didDismiss(error: nil))
        delegate?.didDismiss(self, details: [:], error: nil) ?? log(.delegateUnavailable)
    }
}
