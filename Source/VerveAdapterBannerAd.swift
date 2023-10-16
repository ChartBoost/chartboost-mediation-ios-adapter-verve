// Copyright 2023-2023 Chartboost, Inc.
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

        // Fail if we cannot fit a fixed size banner in the requested size.
        guard let (_, partnerSize) = fixedBannerSize(for: request.size ?? IABStandardAdSize) else {
            let error = error(.loadFailureInvalidBannerSize)
            log(.loadFailed(error))
            return completion(.failure(error))
        }

        guard let ad = HyBidAdView(size: partnerSize) else {
            let error = error(.loadFailureUnknown)
            log(.loadFailed(error))
            return completion(.failure(error))
        }

        self.loadCompletion = completion
        inlineView = ad
        // Load differently depending on whether this is a bidding or non-programatic ad
        if let adm = request.adm {
            ad.delegate = self
            ad.prepareCustomMarkup(from: adm)
        } else {
            ad.load(withZoneID: self.request.partnerPlacement, andWith: self)
        }
    }
    
    /// Shows a loaded ad.
    /// It will never get called for banner ads. You may leave the implementation blank for that ad format.
    /// - parameter viewController: The view controller on which the ad will be presented on.
    /// - parameter completion: Closure to be performed once the ad has been shown.
    func show(with viewController: UIViewController, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        // no-op
    }
}

extension VerveAdapterBannerAd : HyBidAdViewDelegate {
    func adViewDidLoad(_ adView: HyBidAdView!) {
        log(.loadSucceeded)
        self.inlineView = adView

        var partnerDetails: [String: String] = [:]
        if let loadedSize = fixedBannerSize(for: request.size ?? IABStandardAdSize) {
            partnerDetails["bannerWidth"] = "\(loadedSize.size.width)"
            partnerDetails["bannerHeight"] = "\(loadedSize.size.height)"
            partnerDetails["bannerType"] = "0" // Fixed banner
        }
        loadCompletion?(.success(partnerDetails)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func adView(_ adView: HyBidAdView!, didFailWithError error: Error!) {
        let error = error ?? self.error(.loadFailureUnknown)
        log(.loadFailed(error))
        loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func adViewDidTrackClick(_ adView: HyBidAdView!) {
        log(.didClick(error: nil))
        delegate?.didClick(self, details: [:]) ?? log(.delegateUnavailable)
    }

    func adViewDidTrackImpression(_ adView: HyBidAdView!) {
        log(.didTrackImpression)
        delegate?.didTrackImpression(self, details: [:])  ?? log(.delegateUnavailable)
    }
}

// MARK: - Helpers
extension VerveAdapterBannerAd {
    private func fixedBannerSize(for requestedSize: CGSize) -> (size: CGSize, partnerSize: HyBidAdSize)? {
        let sizes: [(size: CGSize, partnerSize: HyBidAdSize)] = [
            (size: IABLeaderboardAdSize, partnerSize: .size_728x90),
            (size: IABMediumAdSize, partnerSize: .size_300x250),
            (size: IABStandardAdSize, partnerSize: .size_320x50)
        ]
        // Find the largest size that can fit in the requested size.
        for (size, partnerSize) in sizes {
            // If height is 0, the pub has requested an ad of any height, so only the width matters.
            if requestedSize.width >= size.width &&
                (size.height == 0 || requestedSize.height >= size.height) {
                return (size, partnerSize)
            }
        }
        // The requested size cannot fit any fixed size banners.
        return nil
    }
}
