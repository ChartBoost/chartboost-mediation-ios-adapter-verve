// Copyright 2022-2023 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import HyBid

/// The Chartboost Mediation Verve adapter rewarded ad.
final class VerveAdapterRewardedAd: VerveAdapterAd, PartnerAd {
    
    /// The partner ad view to display inline. E.g. a banner view.
    /// Should be nil for full-screen ads.
    var inlineView: UIView? { nil }
    
    /// The Verve ad instance.
    var ad: HyBidRewardedAd?
    
    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.loadStarted)
        // Save completion so that delegate can call it
        loadCompletion = completion

        // Create the ad and set this object as the delegate
        ad = HyBidRewardedAd(zoneID: request.partnerPlacement, andWith: self)
        ad?.load()

        // Some adapters assume success and call the completion at this point, but HyBidRewardedAdDelegate
        // has a rewardedDidLoad() method that will call it on load success
    }
    
    /// Shows a loaded ad.
    /// It will never get called for banner ads. You may leave the implementation blank for that ad format.
    /// - parameter viewController: The view controller on which the ad will be presented on.
    /// - parameter completion: Closure to be performed once the ad has been shown.
    func show(with viewController: UIViewController, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.showStarted)

        guard ad?.isReady == true else {
            let error = error(.showFailureAdNotReady)
            log(.loadFailed(error))
            completion(.failure(error))
            return
        }
        showCompletion = completion

        ad?.show()
    }
}


extension VerveAdapterRewardedAd: HyBidRewardedAdDelegate
{
    func rewardedDidLoad() {
        log(.loadSucceeded)
        loadCompletion?(.success([:])) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func rewardedDidFailWithError(_ error: Error!) {
        let error = error ?? self.error(.loadFailureUnknown)
        log(.loadFailed(error))
        loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func rewardedDidTrackClick() {
        log(.didClick(error: nil))
        delegate?.didClick(self, details: [:]) ?? log(.delegateUnavailable)
    }

    func rewardedDidTrackImpression() {
        log(.didTrackImpression)
        showCompletion?(.success([:])) ?? log(.showResultIgnored)
        showCompletion = nil
        delegate?.didTrackImpression(self, details: [:]) ?? log(.delegateUnavailable)
    }

    func rewardedDidDismiss() {
        log(.didDismiss(error: nil))
        delegate?.didDismiss(self, details: [:], error: nil) ?? log(.delegateUnavailable)
    }

    func onReward() {
        log(.didReward)
        delegate?.didReward(self, details: [:])
    }
}
