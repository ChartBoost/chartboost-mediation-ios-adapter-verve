// Copyright 2022-2023 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import Foundation
import HyBid

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

/// A list of externally configurable properties pertaining to the partner SDK that can be retrieved and set by publishers.
@objc public class VerveAdapterConfiguration: NSObject {
    
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
