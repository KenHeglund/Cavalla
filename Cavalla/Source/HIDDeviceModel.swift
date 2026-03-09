// Created on 2026-03-01
// Copyright © 2026 OrderedBytes.  All rights reserved.

import Foundation
import IOKit.hid
import Observation
import OSLog
import SwiftUI


// MARK: - HIDDeviceModel

/// A model representing a HID device.
@Observable
internal class HIDDeviceModel {
	/// Constructs an instance from a HID device reference, and a binding to a
	/// string to modify when a HID event is received by the device.
	///
	/// - Parameters:
	///   - hidDevice: A HID device reference.
	///   - eventText: A binding to a string to modify with HID event values.
	internal init?(
		device hidDevice: IOHIDDevice,
		eventText: Binding<String>
	) {
		self.hidDevice = hidDevice
		self.serviceObject = IOHIDDeviceGetService(hidDevice)
		
		self._eventText = eventText
		
		var globalID: UInt64 = 0
		let result = IORegistryEntryGetRegistryEntryID(self.serviceObject, &globalID)
		if result != kIOReturnSuccess {
			Logger.ioKit.error("IORegistryEntryGetRegistryEntryID: \(UInt32(bitPattern: result), format: .hex(includePrefix: true), privacy: .public)")
		}
		
		let queueDepth = 50
		guard let queue = IOHIDQueueCreate(kCFAllocatorDefault, hidDevice, queueDepth, IOOptionBits.none) else {
			return nil
		}
		self.hidQueue = queue
		
		let intPropertyFormat = "0x%04lX (%ld)"
		
		if let versionNumber = HIDDeviceModel.intProperty(of: hidDevice, for: kIOHIDVersionNumberKey) {
			self.versionString = String(format: intPropertyFormat, versionNumber, versionNumber)
		} else {
			self.versionString = "—"
		}
		
		if let vendorIDString = HIDDeviceModel.intProperty(of: hidDevice, for: kIOHIDVendorIDKey) {
			self.vendorIDString = String(format: intPropertyFormat, vendorIDString, vendorIDString)
		} else {
			self.vendorIDString = "—"
		}
		
		if let productIDString = HIDDeviceModel.intProperty(of: hidDevice, for: kIOHIDProductIDKey) {
			self.productIDString = String(format: intPropertyFormat, productIDString, productIDString)
		} else {
			self.productIDString = "—"
		}
		
		let productString = HIDDeviceModel.stringProperty(of: hidDevice, for: kIOHIDProductKey) ?? "Unnamed Device"
		let manufacturerString = HIDDeviceModel.stringProperty(of: hidDevice, for: kIOHIDManufacturerKey) ?? "Unnamed Manufacturer"
		let usagePage = HIDDeviceModel.intProperty(of: hidDevice, for: kIOHIDPrimaryUsagePageKey) ?? 0
		let usage = HIDDeviceModel.intProperty(of: hidDevice, for: kIOHIDPrimaryUsageKey) ?? 0
		self.longProductName = String(format: "%@ (%@) [%ld:%ld] 0x%llx", productString, manufacturerString, usagePage, usage, globalID)
		
		guard let array = IOHIDDeviceCopyMatchingElements(hidDevice, nil, IOOptionBits.none) else {
			self.elements = []
			return
		}
		guard let elementRefArray = array as? [IOHIDElement] else {
			self.elements = []
			return
		}
		
		self.elements = elementRefArray.map({ HIDElementModel(element: $0, hidQueue: queue) }).sorted(by: { $0.cookie < $1.cookie })
		
		let context = Unmanaged.passUnretained(self).toOpaque()
		IOHIDQueueRegisterValueAvailableCallback(queue, HIDDeviceModelValueAvailableHandler, context)
		IOHIDQueueScheduleWithRunLoop(queue, IOHIDManager.runLoop, IOHIDManager.runLoopMode.rawValue)
	}
	
	deinit {
		if let queue = self.hidQueue {
			IOHIDQueueStop(queue)
			IOHIDQueueUnscheduleFromRunLoop(queue, IOHIDManager.runLoop, IOHIDManager.runLoopMode.rawValue)
			self.hidQueue = nil
		}
	}
	
	
	// MARK: - HIDDeviceModel
	
	/// Remove all elements from the HID queue.
	internal func dequeueAllElements() {
		for element in self.elements {
			element.enabled = false
		}
	}
	
	/// A reference to the represented HID device.
	internal let hidDevice: IOHIDDevice
	
	/// The service object associated with the HID device.
	internal let serviceObject: io_service_t
	
	/// A queue that receives HID events.
	internal var hidQueue: IOHIDQueue?
	
	/// The version of the HID device as a formatted string.
	internal let versionString: String
	
	/// The vendor ID of the HID device as a formatted string.
	internal let vendorIDString: String
	
	/// The product ID of the HID device as a formatted string.
	internal let productIDString: String
	
	/// A string containing an extended name of the HID device containing
	/// properties of the device.
	internal let longProductName: String
	
	/// Models representing the device’s HID elements.
	internal let elements: [HIDElementModel]
	
	
	// MARK: - Private
	
	/// A binding to a string to modify with HID event values.
	@ObservationIgnored
	@Binding fileprivate var eventText: String
	
	/// Returns the property of the given device identified by the given key,
	/// coerced to a `String`.
	///
	/// - Parameters:
	///   - hidDevice: A reference to the HID device to obtain a property of.
	///   - key: The key of the property to obtain.
	///
	/// - Returns: The property of `hidDevice` associated with `key` coerced to a
	///   `String` value.
	private static func stringProperty(of hidDevice: IOHIDDevice, for key: String) -> String? {
		return IOHIDDeviceGetProperty(hidDevice, key as CFString) as? String
	}
	
	/// Returns the property of the given device identified by the given key,
	/// coerced to a `Int`.
	///
	/// - Parameters:
	///   - hidDevice: A reference to the HID device to obtain a property of.
	///   - key: The key of the property to obtain.
	///
	/// - Returns: The property of `hidDevice` associated with `key` coerced to a
	///   `Int` value.
	private static func intProperty(of hidDevice: IOHIDDevice, for key: String) -> Int? {
		return IOHIDDeviceGetProperty(hidDevice, key as CFString) as? Int
	}
}


// MARK: - Equatable

extension HIDDeviceModel: Equatable {
	internal static func == (lhs: HIDDeviceModel, rhs: HIDDeviceModel) -> Bool {
		lhs.serviceObject == rhs.serviceObject
	}
}


// MARK: - HIDDeviceModelValueAvailableHandler

/// A callback function that receives notice that values are available for a
/// HID event queue.
///
/// - Parameters:
///   - context: The `context` value provided when the callback function was
///     registered.
///   - result: “Completion result of desired operation.” 🤷
///   - sender: “Interface instance sending the completion routine.”  Probably
///     the HID queue with values available.
private func HIDDeviceModelValueAvailableHandler(
	context: UnsafeMutableRawPointer?,
	result: IOReturn,
	sender: UnsafeMutableRawPointer?
) {
	guard let context else {
		return
	}
	let deviceModel = Unmanaged<HIDDeviceModel>.fromOpaque(context).takeUnretainedValue()
	
	guard let queue = deviceModel.hidQueue else {
		return
	}
	
	repeat {
		guard let hidValue = IOHIDQueueCopyNextValueWithTimeout(queue, 0.0) else {
			return
		}
		
		let valueLine = hidValue.valueAsString() + "\n"
		deviceModel.eventText.append(valueLine)
		
	} while (true)
}
