// Created on 2026-02-25
// Copyright © 2026 OrderedBytes.  All rights reserved.

import OSLog


// MARK: - Logger

extension Logger {
	/// A `Logger` that reports error values from `IOKit`.
	internal static let ioKit = Logger(subsystem: "com.orderedbytes.cavalla", category: "IOKit")
}
