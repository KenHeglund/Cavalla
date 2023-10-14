/*===========================================================================
 CAVHIDDevice.swift
 Cavalla
 Copyright (c) 2015-2016,2023 Ken Heglund. All rights reserved.
 ===========================================================================*/

import Foundation
import IOKit.hid


extension IOHIDValue {
	func valueAsString() -> String {
		let hidElementRef = IOHIDValueGetElement(self)
		let elementCookie = IOHIDElementGetCookie(hidElementRef)
		let longValueSize = IOHIDValueGetLength(self)
		
		let valueAsString: String
		if (longValueSize > MemoryLayout<CFIndex>.size) {
			let longValueSource = IOHIDValueGetBytePtr(self)
			valueAsString = (0..<longValueSize).map({ String(format: "%02X", longValueSource[$0]) }).joined(separator: " ")
		} else {
			let eventValue = IOHIDValueGetIntegerValue(self)
			valueAsString = String(format: "0x%08X", eventValue)
		}
		
		return String.localizedStringWithFormat("Cookie %u: %@", elementCookie, valueAsString)
	}
}


// MARK: -

class CAVHIDDevice: NSObject {
	let hidDeviceRef: IOHIDDevice
	fileprivate var hidQueueRef: IOHIDQueue?
	
	@objc dynamic var longProductName = ""
	@objc dynamic var vendorIDString = "n/a"
	@objc dynamic var productIDString = "n/a"
	@objc dynamic var versionString = "n/a"
	
	@objc dynamic var elements: [CAVHIDElement] = []
	@objc dynamic var elementCount: Int {
		self.elements.count
	}
	
	public static let didReceiveValueNotification: Notification.Name = Notification.Name(rawValue: "CAVHIDDeviceDidReceiveValueNotification")
	public static let valueAsStringKey = "ValueAsStringKey"
	public static let longProductNameKey = "longProductName"
	
	
	// MARK: -
	
	init?(withHIDDeviceRef hidDeviceRef: IOHIDDevice) {
		self.hidDeviceRef = hidDeviceRef
		
		let queueDepth = 50
		let options = IOOptionBits(kIOHIDOptionsTypeNone)
		guard let queue = IOHIDQueueCreate(kCFAllocatorDefault, hidDeviceRef, queueDepth, options) else { 
			return nil
		}
		
		self.hidQueueRef = queue
		
		super.init()
		
		let context = Unmanaged.passUnretained(self).toOpaque()
		IOHIDQueueRegisterValueAvailableCallback(queue, CAVHIDDeviceValueAvailableHandler, context)
		IOHIDQueueScheduleWithRunLoop(queue, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
		
		let integerPropertyFormat = "0x%04lX (%ld)"
		
		if let versionNumber = self.intPropertyFromDevice(kIOHIDVersionNumberKey) {
			self.versionString = String(format: integerPropertyFormat, versionNumber, versionNumber)
		}
		
		if let vendorIDString = self.intPropertyFromDevice(kIOHIDVendorIDKey) {
			self.vendorIDString = String(format: integerPropertyFormat, vendorIDString, vendorIDString)
		}
		
		if let productIDString = self.intPropertyFromDevice(kIOHIDProductIDKey) {
			self.productIDString = String(format: integerPropertyFormat, productIDString, productIDString)
		}
		
		let productString = self.stringPropertyFromDevice(kIOHIDProductKey) ?? "Unnamed Device"
		let manufacturerString = self.stringPropertyFromDevice(kIOHIDManufacturerKey) ?? "Unnamed Manufacturer"
		let usagePage = self.intPropertyFromDevice(kIOHIDPrimaryUsagePageKey) ?? 0
		let usage = self.intPropertyFromDevice(kIOHIDPrimaryUsageKey) ?? 0
		self.longProductName = String(format: "%@ (%@) [%ld:%ld]", productString, manufacturerString, usagePage, usage)
		
		guard let array = IOHIDDeviceCopyMatchingElements(hidDeviceRef, nil, options) else { 
			return
		}
		guard let elementRefArray = array as? [IOHIDElement] else { 
			return
		}
		
		self.elements = elementRefArray.map({ CAVHIDElement(withHIDElementRef: $0, device: self) })
	}
	
	deinit {
		if let queue = self.hidQueueRef {
			IOHIDQueueStop(queue)
			IOHIDQueueUnscheduleFromRunLoop(queue, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
			self.hidQueueRef = nil
		}
	}
	
	
	// MARK: - CAVHIDDevice
	
	func enqueueHIDElementRef(_ hidElementRef: IOHIDElement) {
		guard let queue = self.hidQueueRef else {
			return
		}
		
		IOHIDQueueStop(queue)
		IOHIDQueueAddElement(queue, hidElementRef)
		IOHIDQueueStart(queue)
	}
	
	func dequeueHIDElementRef(_ hidElementRef: IOHIDElement) {
		guard let queue = self.hidQueueRef else {
			return
		}
		
		IOHIDQueueStop(queue)
		IOHIDQueueRemoveElement(queue, hidElementRef)
		IOHIDQueueStart(queue)
	}
	
	func dequeueAllElements() {
		for element in self.elements {
			element.enabled = false
		}
	}
	
	func queueContainsHIDElementRef(_ hidElementRef: IOHIDElement) -> Bool {
		guard let queue = self.hidQueueRef else {
			return false
		}
		return IOHIDQueueContainsElement(queue, hidElementRef)
	}
	
	
	// MARK: - Private
	
	private func stringPropertyFromDevice(_ key: String) -> String? {
		return IOHIDDeviceGetProperty(self.hidDeviceRef, key as CFString) as? String
	}
	
	private func intPropertyFromDevice(_ key: String) -> Int? {
		return IOHIDDeviceGetProperty(self.hidDeviceRef, key as CFString) as? Int
	}
}


// MARK: -

private func CAVHIDDeviceValueAvailableHandler(context: UnsafeMutableRawPointer?, result: IOReturn, sender: UnsafeMutableRawPointer?) {
	guard let context = context else {
		return
	}
	let device = Unmanaged<CAVHIDDevice>.fromOpaque(context).takeUnretainedValue()
	
	guard let queue = device.hidQueueRef else { 
		return
	}
	
	let notificationCenter = NotificationCenter.default
	
	repeat {
		guard let hidValueRef = IOHIDQueueCopyNextValueWithTimeout(queue, 0.0) else {
			return
		}
		
		let userInfo = [CAVHIDDevice.valueAsStringKey : hidValueRef.valueAsString()]
		notificationCenter.post(name: CAVHIDDevice.didReceiveValueNotification, object: device, userInfo: userInfo)
		
	} while (true)
}
