/*===========================================================================
 CAVHIDElement.swift
 Cavalla
 Copyright (c) 2015-2019 Ken Heglund. All rights reserved.
===========================================================================*/

import Foundation
import HIDSpecification

/// A class that represents a HIDElement instance.
class CAVHIDElement: NSObject {
    
    /// Initializer.
    init(withHIDElementRef hidElementRef: IOHIDElement, device: CAVHIDDevice) {
        
        self.device = device
        self.hidElementRef = hidElementRef
        
        self.cookie = IOHIDElementGetCookie(hidElementRef)
        self.canEnable = (IOHIDElementGetReportSize(hidElementRef) > 0)
        
        let usage = Int(IOHIDElementGetUsage(hidElementRef) & 0x0000FFFF)
        let usagePage = Int(IOHIDElementGetUsagePage(hidElementRef) & 0x0000FFFF)
        self.nameString = HIDSpecification.nameForUsagePage(usagePage, usage: usage) ?? NSLocalizedString("Custom Control", comment: "Default name of a non-standard element.")
        self.usageString = String(format: "0x%04X:0x%04X", usagePage, usage)
        
        let size = Int(IOHIDElementGetReportSize(hidElementRef))
        self.sizeString = String(format: "%lu", size)
    }
    
    /// The element's assigned cookie.
    @objc dynamic let cookie: IOHIDElementCookie
    
    /// Indicates whether the element can be enabled.
    @objc dynamic let canEnable: Bool
    
    /// Indicates whether the element is currently enabled.
    @objc dynamic var isEnabled: Bool {
        
        get {
            return self.device.queueContainsHIDElementRef(self.hidElementRef)
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
            }
            else {
                self.device.dequeueHIDElementRef(self.hidElementRef)
            }
        }
    }
    
    /// The user-visible name of the element.
    @objc dynamic var nameString: String
    
    /// The element's HID usage properties.
    @objc dynamic var usageString: String
    
    /// The size of the element's reported value.
    @objc dynamic var sizeString: String
    
    
    // MARK: - Private interface
    
    /// The element's device.
    private unowned let device: CAVHIDDevice
    
    /// The underlying IOHIDElement instance.
    private let hidElementRef: IOHIDElement
}
