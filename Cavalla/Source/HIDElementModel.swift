// Created on 2026-03-01
// Copyright © 2026 OrderedBytes.  All rights reserved.

import IOKit.hid
import Observation

import HIDSpecification


// MARK: - HIDElementModel

// A model representing a HID element.
@Observable
internal class HIDElementModel {
	/// Constructs an instance from a HID element reference, and a reference to
	/// the event queue that the element should be added to when it is enabled.
	///
	/// - Parameters:
	///   - hidElement: A HID element reference.
	///   - hidQueue: A HID queue reference.
	internal init(element hidElement: IOHIDElement, hidQueue: IOHIDQueue) {
		self.hidElement = hidElement
		self.hidQueue = hidQueue
		
		self.cookie = IOHIDElementGetCookie(hidElement)
		self.canEnable = (IOHIDElementGetReportSize(hidElement) > 0)
		
		let usage = Int(IOHIDElementGetUsage(hidElement) & 0x0000FFFF)
		let usagePage = Int(IOHIDElementGetUsagePage(hidElement) & 0x0000FFFF)
		self.nameString = HIDSpecification.nameForUsagePage(usagePage, usage: usage) ?? "Custom Control"
		self.usageString = String(format: "0x%04X:0x%04X", usagePage, usage)
		
		let size = Int(IOHIDElementGetReportSize(hidElement ))
		self.sizeString = size > 0 ? "\(size)" : ""
	}
	
	/// A reference to the represented HID element.
	internal let hidElement: IOHIDElement
	
	/// A reference to the associated HID event queue.
	internal let hidQueue: IOHIDQueue
	
	/// A value that is used as a unique identifier for an element on a given
	/// device.
	internal let cookie: IOHIDElementCookie
	
	/// A formatted string containing the name of the element.
	internal let nameString: String
	
	/// A formatted string containing the HID usage of the element.
	internal let usageString: String
	
	/// A formatted string containing the size of the element’s data.
	internal let sizeString: String
	
	/// Indicates whether the element can be enabled.
	internal let canEnable: Bool
	
	/// Indicates whether the element is currently enabled
	internal var enabled: Bool = false {
		willSet {
			guard self.canEnable else {
				return
			}
			
			let hidElement = self.hidElement
			let isEnqueued = self.hidQueue.containsHIDElementRef(hidElement)
			
			if newValue, !isEnqueued {
				self.hidQueue.enqueueHIDElementRef(hidElement)
			} else if !newValue, isEnqueued {
				self.hidQueue.dequeueHIDElementRef(hidElement)
			}
		}
		didSet {
			if self.enabled, !self.canEnable {
				self.enabled = false
			}
		}
	}
}


// MARK: - Identifiable

extension HIDElementModel: Identifiable {
	internal var id: IOHIDElement {
		self.hidElement
	}
}


// MARK: - Equatable

extension HIDElementModel: Equatable {
	static func == (lhs: HIDElementModel, rhs: HIDElementModel) -> Bool {
		lhs.hidElement === rhs.hidElement
	}
}
