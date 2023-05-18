// Copyright 2022-2023 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import HyBid

/// The Chartboost Mediation Verve adapter banner ad.
final class VerveAdapterBannerAd: VerveAdapterAd, PartnerAd {
    
    /// The partner ad view to display inline. E.g. a banner view.
    /// Should be nil for full-screen ads.
    var inlineView: UIView?
    
    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.loadStarted)

        let size = getHyBidBannerAdSize(size: self.request.size)
        if let ad = HyBidAdView(size: size) {
            self.loadCompletion = completion
            inlineView = ad
            ad.load(withZoneID: self.request.partnerPlacement, andWith: self)
        } else {
            let error = error(.loadFailureUnknown)
            log(.loadFailed(error))
            completion(.failure(error))
        }
    }
    
    /// Shows a loaded ad.
    /// It will never get called for banner ads. You may leave the implementation blank for that ad format.
    /// - parameter viewController: The view controller on which the ad will be presented on.
    /// - parameter completion: Closure to be performed once the ad has been shown.
    func show(with viewController: UIViewController, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        // no-op
    }
    
    /// Map Chartboost Mediation's banner sizes to the Reference SDK's supported sizes.
    /// - Parameter size: The Chartboost Mediation's banner size.
    /// - Returns: The corresponding Verve banner size.
    func getHyBidBannerAdSize(size: CGSize?) -> HyBidAdSize {
        let height = size?.height ?? 50
        
        switch height {
        case 50..<89:
            return HyBidAdSize.size_320x50
        case 90..<249:
            return HyBidAdSize.size_728x90
        case 250...:
            return HyBidAdSize.size_300x250
        default:
            return HyBidAdSize.size_320x50
        }
    }
}

extension VerveAdapterBannerAd : HyBidAdViewDelegate {
    func adViewDidLoad(_ adView: HyBidAdView!) {
        log(.loadSucceeded)
        self.inlineView = adView
        loadCompletion?(.success([:])) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func adView(_ adView: HyBidAdView!, didFailWithError error: Error!) {
        let error = error ?? self.error(.loadFailureUnknown)
        log(.loadFailed(error))
        loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func adViewDidTrackClick(_ adView: HyBidAdView!) {
        delegate?.didClick(self, details: [:]) ?? log(.delegateUnavailable)
    }

    func adViewDidTrackImpression(_ adView: HyBidAdView!) {
        delegate?.didTrackImpression(self, details: [:])  ?? log(.delegateUnavailable)
    }
}
