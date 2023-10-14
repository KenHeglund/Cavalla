/*===========================================================================
 CAVHIDManager.swift
 Cavalla
 Copyright (c) 2015-2016,2023 Ken Heglund. All rights reserved.
 ===========================================================================*/

import Foundation
import OSLog


// MARK: - CAVHIDManager

class CAVHIDManager: NSObject {
	private(set) var hidManagerRef: IOHIDManager? = nil
	
	@objc dynamic var devices: NSMutableSet = NSMutableSet()
	
	public static let devicesKey = "devices"
	
	func open() -> IOReturn {
		let options = IOOptionBits(kIOHIDOptionsTypeNone)
		let hidManager = IOHIDManagerCreate(kCFAllocatorDefault, options)
		
		self.hidManagerRef = hidManager
		
		let result = IOHIDManagerOpen(hidManager, IOOptionBits(kIOHIDOptionsTypeNone))
		guard result == kIOReturnSuccess else {
			return result
		}
		
		let context = Unmanaged.passUnretained(self).toOpaque()
		IOHIDManagerRegisterDeviceMatchingCallback(hidManager, CAVHIDManagerDeviceAttachedHandler, context)
		IOHIDManagerSetDeviceMatching(hidManager, nil)
		IOHIDManagerScheduleWithRunLoop(hidManager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
		
		return kIOReturnSuccess
	}
	
	func close() {
		guard let hidManager = self.hidManagerRef else {
			return
		}
		
		IOHIDManagerClose(hidManager, IOOptionBits(kIOHIDOptionsTypeNone))
		IOHIDManagerUnscheduleFromRunLoop(hidManager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
		
		self.mutableSetValue(forKey: CAVHIDManager.devicesKey).removeAllObjects()
		
		self.hidManagerRef = nil
	}
}


// MARK: - Private

let LOG_ATTACH_AND_DETACH = true

private func CAVHIDManagerDeviceAttachedHandler(context: UnsafeMutableRawPointer?, result: IOReturn, sender: UnsafeMutableRawPointer?, hidDeviceRef: IOHIDDevice) {
	if LOG_ATTACH_AND_DETACH {
		let manufacturer = IOHIDDeviceGetProperty(hidDeviceRef, kIOHIDManufacturerKey as CFString) as? String ?? ""
		let product = IOHIDDeviceGetProperty(hidDeviceRef, kIOHIDProductKey as CFString) as? String ?? ""
		let vendorID = IOHIDDeviceGetProperty(hidDeviceRef, kIOHIDVendorIDKey as CFString) as? Int ?? 0
		let productID = IOHIDDeviceGetProperty(hidDeviceRef, kIOHIDProductIDKey as CFString) as? Int ?? 0
		let usagePage = IOHIDDeviceGetProperty(hidDeviceRef, kIOHIDPrimaryUsagePageKey as CFString) as? Int ?? 0
		let usage = IOHIDDeviceGetProperty(hidDeviceRef, kIOHIDPrimaryUsageKey as CFString) as? Int ?? 0
		os_log(.debug, "Device attached: \(product, privacy: .public) (\(manufacturer, privacy: .public)) \(vendorID, privacy: .public):\(productID, privacy: .public) \(usagePage, privacy: .public):\(usage, privacy: .public) [\(result, privacy: .public)]")
	}
	
	guard let context = context else {
		return
	}
	
	Task(operation: {
		guard let device = CAVHIDDevice(withHIDDeviceRef: hidDeviceRef) else {
			return
		}
		
		let manager = Unmanaged<CAVHIDManager>.fromOpaque(context).takeUnretainedValue()
		
		await MainActor.run {
			IOHIDDeviceRegisterRemovalCallback(hidDeviceRef, CAVHIDManagerDeviceRemovedHandler, context)
			manager.mutableSetValue(forKey: CAVHIDManager.devicesKey).add(device)
		}
	})
}

private func CAVHIDManagerDeviceRemovedHandler(context: UnsafeMutableRawPointer?, result: IOReturn, hidDeviceRefPointer: UnsafeMutableRawPointer?) {
	guard let hidDevicePointer = hidDeviceRefPointer else {
		return
	}
	let hidDevice = Unmanaged<IOHIDDevice>.fromOpaque(hidDevicePointer).takeUnretainedValue()
	
	if LOG_ATTACH_AND_DETACH == true {
		let manufacturer = IOHIDDeviceGetProperty(hidDevice, kIOHIDManufacturerKey as CFString) as? String ?? ""
		let product = IOHIDDeviceGetProperty(hidDevice, kIOHIDProductKey as CFString) as? String ?? ""
		os_log(.debug, "Device removed: \(product, privacy: .public) (\(manufacturer, privacy: .public)) [\(result, privacy: .public)]")
	}
	
	guard let context = context else { 
		return
	}
	
	let manager = Unmanaged<CAVHIDManager>.fromOpaque(context).takeUnretainedValue()
	
	for object in manager.devices {
		guard let device = object as? CAVHIDDevice else {
			continue
		}
		if device.hidDeviceRef !== hidDevice {
			continue
		}
		
		manager.mutableSetValue(forKey: CAVHIDManager.devicesKey).remove(device)
		return
	}
}
