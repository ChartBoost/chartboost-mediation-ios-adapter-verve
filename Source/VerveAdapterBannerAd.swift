// Copyright 2023-2024 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import HyBid

/// The Chartboost Mediation Verve adapter banner ad.
final class VerveAdapterBannerAd: VerveAdapterAd, PartnerBannerAd {
    /// The partner banner ad view to display.
    var view: UIView?

    /// The loaded partner ad banner size.
    var size: PartnerBannerSize?

    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerDetails, Error>) -> Void) {
        log(.loadStarted)

        // Fail if we cannot fit a fixed size banner in the requested size.
        guard let (loadedSize, partnerSize) = fixedBannerSize(for: request.bannerSize) else {
            let error = error(.loadFailureInvalidBannerSize)
            log(.loadFailed(error))
            return completion(.failure(error))
        }
        size = PartnerBannerSize(size: loadedSize, type: .fixed)

        guard let ad = HyBidAdView(size: partnerSize) else {
            let error = error(.loadFailureUnknown)
            log(.loadFailed(error))
            return completion(.failure(error))
        }

        self.loadCompletion = completion
        view = ad
        // Load differently depending on whether this is a bidding or non-programatic ad
        if let adm = request.adm {
            ad.delegate = self
            ad.renderAd(withContent: adm, with: self)
        } else {
            ad.load(withZoneID: self.request.partnerPlacement, andWith: self)
        }
    }
}

extension VerveAdapterBannerAd : HyBidAdViewDelegate {
    func adViewDidLoad(_ adView: HyBidAdView?) {
        log(.loadSucceeded)
        loadCompletion?(.success([:])) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func adView(_ adView: HyBidAdView?, didFailWithError error: Error!) {
        let error = error ?? self.error(.loadFailureUnknown)
        log(.loadFailed(error))
        loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }

    func adViewDidTrackClick(_ adView: HyBidAdView?) {
        log(.didClick(error: nil))
        delegate?.didClick(self, details: [:]) ?? log(.delegateUnavailable)
    }

    func adViewDidTrackImpression(_ adView: HyBidAdView?) {
        log(.didTrackImpression)
        delegate?.didTrackImpression(self, details: [:])  ?? log(.delegateUnavailable)
    }
}

// MARK: - Helpers
extension VerveAdapterBannerAd {
    private func fixedBannerSize(for requestedSize: BannerSize?) -> (size: CGSize, partnerSize: HyBidAdSize)? {
        guard let requestedSize else {
            return (IABStandardAdSize, .size_320x50)
        }
        let sizes: [(size: CGSize, partnerSize: HyBidAdSize)] = [
            (size: IABLeaderboardAdSize, partnerSize: .size_728x90),
            (size: IABMediumAdSize, partnerSize: .size_300x250),
            (size: IABStandardAdSize, partnerSize: .size_320x50)
        ]
        // Find the largest size that can fit in the requested size.
        for (size, partnerSize) in sizes {
            // If height is 0, the pub has requested an ad of any height, so only the width matters.
            if requestedSize.size.width >= size.width &&
                (size.height == 0 || requestedSize.size.height >= size.height) {
                return (size, partnerSize)
            }
        }
        // The requested size cannot fit any fixed size banners.
        return nil
    }
}
