// Created on 2026-02-26
// Copyright © 2026 OrderedBytes.  All rights reserved.

import IOKit.hid
import OSLog


// MARK: - IOHIDManager

extension IOHIDManager {
	/// Creates an `IOHIDManager` using the default allocator and no options.
	///
	/// - Returns: A newly created `IOHIDManager`.
	internal static func create() -> IOHIDManager {
		IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits.none)
	}
	
	/// Configures an `IOHIDManager` to match all HID devices, and to call the
	/// given callback handlers when a device is matched or removed.
	///
	/// - Parameter availabilityHandlers: A instance of a type containing device
	///   matched and removed handlers.
	internal func configureAndOpen<T: HIDDeviceAvailabilityHandling>(with availabilityHandlers: T) {
		let matchingCallback: IOHIDDeviceCallback = { context, _, _, hidDevice in
			guard let context else {
				Logger.ioKit.debug("Device matching callback called without context")
				assertionFailure()
				return
			}
			
			guard let handler = Unmanaged<AnyObject>.fromOpaque(context).takeUnretainedValue() as? HIDDeviceAvailabilityHandling else {
				Logger.ioKit.debug("Device matching callback called with unexpected context type")
				assertionFailure()
				return
			}
			
			handler.deviceMatched(hidDevice)
		}
		
		let removalCallback: IOHIDDeviceCallback = { context, _, _, hidDevice in
			guard let context else {
				Logger.ioKit.debug("Device removal callback called without context")
				assertionFailure()
				return
			}
			
			guard let handler = Unmanaged<AnyObject>.fromOpaque(context).takeUnretainedValue() as? HIDDeviceAvailabilityHandling else {
				Logger.ioKit.debug("Device matching callback called with unexpected context type")
				assertionFailure()
				return
			}
			
			handler.deviceRemoved(hidDevice)
		}
		
		let context = Unmanaged<T>.passUnretained(availabilityHandlers).toOpaque()
		
		IOHIDManagerRegisterDeviceMatchingCallback(self, matchingCallback, context)
		IOHIDManagerRegisterDeviceRemovalCallback(self, removalCallback, context)
		IOHIDManagerScheduleWithRunLoop(self, IOHIDManager.runLoop, IOHIDManager.runLoopMode.rawValue)
		IOHIDManagerSetDeviceMatching(self, nil)
		
		let result = IOHIDManagerOpen(self, IOOptionBits.none)
		guard result == kIOReturnSuccess else {
			Logger.ioKit.error("IOHIDManagerOpen: \(UInt32(bitPattern: result), format: .hex(includePrefix: true), privacy: .public)")
			return
		}
	}
	
	/// Closes the receiver and unschedules it from the run loop.
	internal func close() {
		let result = IOHIDManagerClose(self, IOOptionBits.none)
		if result != kIOReturnSuccess {
			Logger.ioKit.error("IOHIDManagerClose: \(UInt32(bitPattern: result), format: .hex(includePrefix: true), privacy: .public)")
		}
		
		IOHIDManagerUnscheduleFromRunLoop(self, IOHIDManager.runLoop, IOHIDManager.runLoopMode.rawValue)
	}
	
	/// The run loop that is used to schedule asynchronous activity.
	internal static var runLoop: CFRunLoop { CFRunLoopGetMain() }
	
	/// The run loop mode that is used to schedule asynchronous activity.
	internal static var runLoopMode: CFRunLoopMode { .defaultMode }
}


// MARK: - HIDDeviceAvailabilityHandling

/// A protocol defining methods to be called when the availability of an
/// `IOHIDDevice` changes.
internal protocol HIDDeviceAvailabilityHandling: AnyObject {
	/// An `IOHIDDevice` has become available.
	///
	/// - Parameter device: The matched `IOHIDDevice`.
	func deviceMatched(_ device: IOHIDDevice)
	
	/// An `IOHIDDevice` is no longer available.
	///
	/// - Parameter device: The removed `IOHIDDevice`.
	func deviceRemoved(_ device: IOHIDDevice)
}


// MARK: - IOHIDQueue

extension IOHIDQueue {
	/// Add the given element to the receiver.
	///
	/// - Parameter element: The `IOHIDElement` to add.
	internal func enqueueHIDElementRef(_ element: IOHIDElement) {
		IOHIDQueueStop(self)
		IOHIDQueueAddElement(self, element)
		IOHIDQueueStart(self)
	}
	
	/// Remove the given element from the receiver.
	///
	/// - Parameter element: The `IOHIDElement` to remove.
	internal func dequeueHIDElementRef(_ element: IOHIDElement) {
		IOHIDQueueStop(self)
		IOHIDQueueRemoveElement(self, element)
		IOHIDQueueStart(self)
	}
	
	/// Indicates whether the given element has been added to the receiver.
	///
	/// - Parameter element: An `IOHIDElement` to test.
	internal func containsHIDElementRef(_ element: IOHIDElement) -> Bool {
		IOHIDQueueContainsElement(self, element)
	}
}


// MARK: - IOHIDValue

extension IOHIDValue {
	/// Returns a String containing the receiver in a format that is suitable for
	/// display to the user.
	internal func valueAsString() -> String {
		let hidElement = IOHIDValueGetElement(self)
		let elementCookie = IOHIDElementGetCookie(hidElement)
		let longValueSize = IOHIDValueGetLength(self)
		
		let valueAsString: String
		if longValueSize > MemoryLayout<CFIndex>.size {
			let longValueSource = IOHIDValueGetBytePtr(self)
			valueAsString = (0..<longValueSize).map({ String(format: "%02X", longValueSource[$0]) }).joined(separator: " ")
		} else {
			let eventValue = IOHIDValueGetIntegerValue(self)
			valueAsString = String(format: "0x%08X", eventValue)
		}
		
		return String.localizedStringWithFormat("Cookie %u: %@", elementCookie, valueAsString)
	}
}


// MARK: - IOOptionBits

extension IOOptionBits {
	/// An instance with a value of `kIOHIDOptionsTypeNone`.
	internal static let none = IOOptionBits(kIOHIDOptionsTypeNone)
}
