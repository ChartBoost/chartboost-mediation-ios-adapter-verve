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
        // Return a default value if no size is specified.
        guard let requestedSize else {
            return (BannerSize.standard.size, .size_320x50)
        }
        // If we can find a size that fits, return that.
        if let size = BannerSize.largestStandardFixedSizeThatFits(in: requestedSize) {
            switch size {
            case .standard:
                return (BannerSize.standard.size, .size_320x50)
            case .medium:
                return (BannerSize.medium.size, .size_300x250)
            case .leaderboard:
                return (BannerSize.leaderboard.size, .size_728x90)
            default:
                // largestStandardFixedSizeThatFits currently only returns .standard, .medium, or .leaderboard,
                // but if that changes then just default to .standard until this code gets updated.
                return (BannerSize.standard.size, .size_320x50)
            }
        } else {
            // largestStandardFixedSizeThatFits has returned nil to indicate it couldn't find a fit.
            return nil
        }
    }
}
