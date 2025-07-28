// Copyright 2023-2025 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import HyBid

/// The Chartboost Mediation Verve adapter interstitial ad.
final class VerveAdapterInterstitialAd: VerveAdapterAd, PartnerFullscreenAd {
    /// The Verve ad instance.
    var ad: HyBidInterstitialAd?

    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Error?) -> Void) {
        log(.loadStarted)
        // Save completion so that delegate can call it
        loadCompletion = completion

        // Create the ad and set this object as the delegate
        let hyBidAd = HyBidInterstitialAd(zoneID: request.partnerPlacement, andWith: self)
        // Save a reference to it
        ad = hyBidAd
        // Load differently depending on whether this is a bidding or non-programatic ad
        if let signal = request.partnerSettings["signal"] as? String {
            // `hyBidAd.prepareAdWithContent` uses WebKit and must be called on main.
            DispatchQueue.main.async {
                hyBidAd.prepareAdWithContent(adContent: signal)
            }
        } else {
            hyBidAd.load()
        }

        // Some adapters assume success and call the completion at this point, but HyBidInterstitialAdDelegate
        // has a interstitialDidLoad() method that will call it on load success
    }

    /// Shows a loaded ad.
    /// Chartboost Mediation SDK will always call this method from the main thread.
    /// - parameter viewController: The view controller on which the ad will be presented on.
    /// - parameter completion: Closure to be performed once the ad has been shown.
    func show(with viewController: UIViewController, completion: @escaping (Error?) -> Void) {
        log(.showStarted)

        guard let ad, ad.isReady == true else {
            let error = error(.showFailureAdNotReady)
            log(.showFailed(error))
            completion(error)
            return
        }
        ad.show()
        // There's no delegate method that notifies us of a show failure so assume success
        completion(nil)
        log(.showSucceeded)
    }
}

extension VerveAdapterInterstitialAd: HyBidInterstitialAdDelegate {
    func interstitialDidLoad() {
        log(.loadSucceeded)
        loadCompletion?(nil) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func interstitialDidFailWithError(_ error: Error!) {
        let error = error ?? self.error(.loadFailureUnknown)
        log(.loadFailed(error))
        loadCompletion?(error) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func interstitialDidTrackClick() {
        log(.didClick(error: nil))
        delegate?.didClick(self) ?? log(.delegateUnavailable)
    }

    func interstitialDidTrackImpression() {
        log(.didTrackImpression)
        delegate?.didTrackImpression(self) ?? log(.delegateUnavailable)
    }

    func interstitialDidDismiss() {
        log(.didDismiss(error: nil))
        delegate?.didDismiss(self, error: nil) ?? log(.delegateUnavailable)
    }
}
