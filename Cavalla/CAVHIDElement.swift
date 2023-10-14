/*===========================================================================
 CAVHIDElement.swift
 Cavalla
 Copyright (c) 2015-2016,2023 Ken Heglund. All rights reserved.
 ===========================================================================*/

import Foundation
import HIDSpecification


class CAVHIDElement: NSObject {
	private unowned let device: CAVHIDDevice
	
	let hidElementRef: IOHIDElement
	@objc dynamic var cookie: IOHIDElementCookie
	@objc dynamic let canEnable: Bool
	
	@objc dynamic var enabled: Bool {
		get {
			self.device.queueContainsHIDElementRef(self.hidElementRef)
		}
		set {
			guard self.canEnable else {
				return
			}
			
			if newValue == self.device.queueContainsHIDElementRef(self.hidElementRef) {
				return
			}
			
			if newValue {
				self.device.enqueueHIDElementRef(self.hidElementRef)
			} else {
				self.device.dequeueHIDElementRef(self.hidElementRef)
			}
		}
	}
	
	@objc dynamic var nameString: String
	@objc dynamic var usageString: String
	@objc dynamic var sizeString: String
	
	init(withHIDElementRef hidElementRef: IOHIDElement, device: CAVHIDDevice) {
		self.device = device
		self.hidElementRef = hidElementRef
		
		self.cookie = IOHIDElementGetCookie(hidElementRef)
		self.canEnable = (IOHIDElementGetReportSize(hidElementRef) > 0)
		
		let usage = Int(IOHIDElementGetUsage(hidElementRef) & 0x0000FFFF)
		let usagePage = Int(IOHIDElementGetUsagePage(hidElementRef) & 0x0000FFFF)
		self.nameString = HIDSpecification.nameForUsagePage(usagePage, usage: usage) ?? "Custom Control"
		self.usageString = String(format: "0x%04X:0x%04X", usagePage, usage)
		
		let size = Int(IOHIDElementGetReportSize(hidElementRef ))
		self.sizeString = "\(size)"
	}
}
