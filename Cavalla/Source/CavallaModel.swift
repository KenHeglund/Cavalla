// Created on 2026-02-26
// Copyright © 2026 OrderedBytes.  All rights reserved.

import Algorithms
import IOKit.hid
import Observation
import OSLog
import SwiftUI


// MARK: - CavallaModel

/// The model of the Cavalla application main window’s content.
@Observable
internal final class CavallaModel {
	/// The currently active HID manager.
	internal var hidManager: IOHIDManager? {
		willSet {
			if newValue == nil {
				self.hidManager?.close()
				self.deviceModels = []
			}
		}
		didSet {
			self.hidManager?.configureAndOpen(with: self)
		}
	}
	
	/// Models representing the currently available HID devices.
	internal var deviceModels: [HIDDeviceModel] = []
	
	/// The currently selected HID device model.
	internal var selectedDeviceModel: HIDDeviceModel?
	
	/// Aggregate text describing recorded HID event values.
	internal var eventText = ""
}


// MARK: - HIDDeviceAvailabilityHandling

extension CavallaModel: HIDDeviceAvailabilityHandling {
	func deviceMatched(_ hidDevice: IOHIDDevice) {
		@Bindable var model = self
		
		guard let device = HIDDeviceModel(device: hidDevice, eventText: $model.eventText) else {
			return
		}
		
		let devices = chain(self.deviceModels, CollectionOfOne(device))
		self.deviceModels = devices.sorted(by: {
			$0.longProductName.localizedStandardCompare($1.longProductName) == .orderedAscending
		})
	}
	
	func deviceRemoved(_ hidDevice: IOHIDDevice) {
		self.deviceModels.removeAll(where: { $0.hidDevice === hidDevice })
	}
}
