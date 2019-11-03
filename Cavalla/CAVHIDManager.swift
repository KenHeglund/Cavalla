/*===========================================================================
 CAVHIDManager.swift
 Cavalla
 Copyright (c) 2015-2019 Ken Heglund. All rights reserved.
===========================================================================*/

import Foundation

/// A class that represents a HIDManager instance.
class CAVHIDManager: NSObject {
    
    private(set) var hidManagerRef: IOHIDManager? = nil
    
    @objc dynamic var devices = NSMutableSet()
    
    public static let devicesKey = "devices"
    
    
    // MARK: - CAVHIDManager implementation
    
    /// Opens the HIDManager.
    /// - returns: `kIOReturnSuccess` if the HIDManager is successfully opened, another status code if not.
    func open() -> IOReturn {
        
        let options = IOOptionBits(kIOHIDOptionsTypeNone)
        let hidManager = IOHIDManagerCreate(kCFAllocatorDefault, options)
        
        self.hidManagerRef = hidManager
        
        let result = IOHIDManagerOpen(hidManager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            return result
        }
        
        let context = Unmanaged.passUnretained(self).toOpaque()
        
        IOHIDManagerSetDeviceMatching(hidManager, nil)
        IOHIDManagerRegisterDeviceMatchingCallback(hidManager, CAVHIDManagerDeviceAttachedHandler, context)
        IOHIDManagerScheduleWithRunLoop(hidManager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        
        return kIOReturnSuccess
    }
    
    /// Closes the HIDManager.
    func close() {
        
        if let hidManagerRef = self.hidManagerRef {
            IOHIDManagerClose(hidManagerRef, IOOptionBits(kIOHIDOptionsTypeNone))
            IOHIDManagerUnscheduleFromRunLoop(hidManagerRef, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        }
        
        self.mutableSetValue(forKey: CAVHIDManager.devicesKey).removeAllObjects()
        
        self.hidManagerRef = nil
    }
}

let LOG_ATTACH_AND_DETACH = true // swiftlint:disable:this identifier_name

/// Callback called when a HID device is attached.
private func CAVHIDManagerDeviceAttachedHandler(context: UnsafeMutableRawPointer?, result: IOReturn, sender: UnsafeMutableRawPointer?, hidDeviceRef: IOHIDDevice) {
    
    if LOG_ATTACH_AND_DETACH == true {
        let manufacturer = IOHIDDeviceGetProperty(hidDeviceRef, kIOHIDManufacturerKey as CFString) as? String ?? ""
        let product = IOHIDDeviceGetProperty(hidDeviceRef, kIOHIDProductKey as CFString) as? String ?? ""
        let vendorID = IOHIDDeviceGetProperty(hidDeviceRef, kIOHIDVendorIDKey as CFString) as? Int ?? 0
        let productID = IOHIDDeviceGetProperty(hidDeviceRef, kIOHIDProductIDKey as CFString) as? Int ?? 0
        let usagePage = IOHIDDeviceGetProperty(hidDeviceRef, kIOHIDPrimaryUsagePageKey as CFString) as? Int ?? 0
        let usage = IOHIDDeviceGetProperty(hidDeviceRef, kIOHIDPrimaryUsageKey as CFString) as? Int ?? 0
        print(String(format: "%@ (%@) %d:%d %d:%d [0x08X]", product, manufacturer, vendorID, productID, usagePage, usage, result))
    }
    
    DispatchQueue.global(priority: DispatchQueue.GlobalQueuePriority.default).async {
        
        guard let device = CAVHIDDevice(withHIDDeviceRef: hidDeviceRef) else {
            return
        }
        guard let context = context else {
            return
        }
        
        let manager = Unmanaged<CAVHIDManager>.fromOpaque(context).takeUnretainedValue()
        
        DispatchQueue.main.async {
            
            IOHIDDeviceRegisterRemovalCallback(hidDeviceRef, CAVHIDManagerDeviceRemovedHandler, context)
            
            manager.mutableSetValue(forKey: CAVHIDManager.devicesKey).add(device)
        }
    }
}

/// Callback called when a device is detached.
private func CAVHIDManagerDeviceRemovedHandler(context: UnsafeMutableRawPointer?, result: IOReturn, hidDeviceRefPointer: UnsafeMutableRawPointer?) {
    
    guard let hidDevicePointer = hidDeviceRefPointer else {
        return
    }
    
    let hidDevice = Unmanaged<IOHIDDevice>.fromOpaque(hidDevicePointer).takeUnretainedValue()
    
    if LOG_ATTACH_AND_DETACH == true {
        let manufacturer = IOHIDDeviceGetProperty(hidDevice, kIOHIDManufacturerKey as CFString) as? String ?? ""
        let product = IOHIDDeviceGetProperty(hidDevice, kIOHIDProductKey as CFString) as? String ?? ""
        print( "Device removed: \(product) (\(manufacturer)) [\(result)]")
    }
    
    guard let context = context else {
        return
    }
    
    let manager = Unmanaged<CAVHIDManager>.fromOpaque(context).takeUnretainedValue()
    
    for object in manager.devices {
        
        guard let device = object as? CAVHIDDevice else {
            assertionFailure()
            continue
        }
        
        if device.hidDeviceRef !== hidDevice {
            continue
        }
        
        manager.mutableSetValue(forKey: CAVHIDManager.devicesKey).remove(device)
        return
    }
}
