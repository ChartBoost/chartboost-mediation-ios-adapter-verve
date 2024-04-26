// Copyright 2023-2024 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import Foundation
import HyBid

/// A list of externally configurable properties pertaining to the partner SDK that can be retrieved and set by publishers.
@objc public class VerveAdapterConfiguration: NSObject {

    /// The version of the partner SDK.
    @objc public static var partnerSDKVersion: String {
        HyBid.sdkVersion() ?? ""
    }

    /// The version of the adapter.
    /// It should have either 5 or 6 digits separated by periods, where the first digit is Chartboost Mediation SDK's major version, the last digit is the adapter's build version, and intermediate digits are the partner SDK's version.
    /// Format: `<Chartboost Mediation major version>.<Partner major version>.<Partner minor version>.<Partner patch version>.<Partner build version>.<Adapter build version>` where `.<Partner build version>` is optional.
    @objc public static let adapterVersion = "4.2.21.0.0"

    /// The partner's unique identifier.
    @objc public static let partnerID = "verve"

    /// The human-friendly partner name.
    @objc public static let partnerDisplayName = "Verve"

    // A mapping of HyBid log levels to an externally-visible type for publishers to use when configuring this adapter
    @objc public enum VerveLogLevel: Int {
        case none = 0
        case error
        case warning
        case info
        case debug

        var hyBidLogLevel: HyBidLogLevel {
            switch self {
            case .none:
                return HyBidLogLevelNone
            case .error:
                return HyBidLogLevelError
            case .warning:
                return HyBidLogLevelWarning
            case .info:
                return HyBidLogLevelInfo
            case .debug:
                return HyBidLogLevelDebug
            }
        }
    }
    
    /// Flag that can optionally be set to enable the partner's test mode.
    /// Disabled by default.
    @objc public static var testMode: Bool = false {
        didSet {
            HyBid.setTestMode(testMode)
        }
    }

    /// Set the log level for Verve's HyBid SDK
    @objc public static var logLevel: VerveLogLevel = .info {
        didSet {
            HyBidLogger.setLogLevel(logLevel.hyBidLogLevel)
        }
    }
}
