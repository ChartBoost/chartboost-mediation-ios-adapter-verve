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
        guard
            let requestedSize = request.bannerSize,
            let fittingSize = BannerSize.largestStandardFixedSizeThatFits(in: requestedSize),
            let verveSize = fittingSize.verveAdSize
        else {
            let error = error(.loadFailureInvalidBannerSize)
            log(.loadFailed(error))
            return completion(.failure(error))
        }
        size = PartnerBannerSize(size: fittingSize.size, type: .fixed)

        guard let ad = HyBidAdView(size: verveSize) else {
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

extension BannerSize {
    fileprivate var verveAdSize: HyBidAdSize? {
        switch self {
        case .standard:
                .size_320x50
        case .medium:
                .size_300x250
        case .leaderboard:
                .size_728x90
        default:
            nil
        }
    }
}
