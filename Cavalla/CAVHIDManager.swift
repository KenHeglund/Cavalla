/*===========================================================================
 CAVHIDManager.swift
 Cavalla
 Copyright (c) 2015-2016 Ken Heglund. All rights reserved.
===========================================================================*/

import Foundation

/*==========================================================================*/

class CAVHIDManager: NSObject {
    
    fileprivate(set) var hidManagerRef: IOHIDManager? = nil
    
    dynamic var devices: NSMutableSet = NSMutableSet()
    
    public static let devicesKey = "devices"
    
    // MARK: - CAVHIDManager implementation
    
    /*==========================================================================*/
    func open() -> IOReturn {
        
        let options = IOOptionBits(kIOHIDOptionsTypeNone)
        let hidManager = IOHIDManagerCreate( kCFAllocatorDefault, options )
        
        self.hidManagerRef = hidManager
        
        let result = IOHIDManagerOpen( hidManager, IOOptionBits(kIOHIDOptionsTypeNone) )
        guard result == kIOReturnSuccess else { return result }
        
        let context = Unmanaged.passUnretained( self ).toOpaque()
        
        IOHIDManagerSetDeviceMatching( hidManager, nil )
        IOHIDManagerRegisterDeviceMatchingCallback( hidManager, CAVHIDManagerDeviceAttachedHandler, context )
        IOHIDManagerScheduleWithRunLoop( hidManager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue )
        
        return kIOReturnSuccess
    }
    
    /*==========================================================================*/
    func close() {
        
        let hidManagerRef = self.hidManagerRef
        
        IOHIDManagerClose( hidManagerRef!, IOOptionBits(kIOHIDOptionsTypeNone) )
        IOHIDManagerUnscheduleFromRunLoop( hidManagerRef!, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue )
        
        self.mutableSetValue( forKey: CAVHIDManager.devicesKey ).removeAllObjects()
        
        self.hidManagerRef = nil
    }
}

let LOG_ATTACH_AND_DETACH = true

/*==========================================================================*/
private func CAVHIDManagerDeviceAttachedHandler( context: UnsafeMutableRawPointer?, result: IOReturn, sender: UnsafeMutableRawPointer?, hidDeviceRef: IOHIDDevice ) {
    
    if LOG_ATTACH_AND_DETACH == true {
        let manufacturer = CAVHIDDeviceGetProperty( hidDeviceRef, kIOHIDManufacturerKey as CFString ) as? String ?? ""
        let product = CAVHIDDeviceGetProperty( hidDeviceRef, kIOHIDProductKey as CFString ) as? String ?? ""
        let vendorID = CAVHIDDeviceGetProperty( hidDeviceRef, kIOHIDVendorIDKey as CFString ) as? Int ?? 0
        let productID = CAVHIDDeviceGetProperty( hidDeviceRef, kIOHIDProductIDKey as CFString ) as? Int ?? 0
        let usagePage = CAVHIDDeviceGetProperty( hidDeviceRef, kIOHIDPrimaryUsagePageKey as CFString ) as? Int ?? 0
        let usage = CAVHIDDeviceGetProperty( hidDeviceRef, kIOHIDPrimaryUsageKey as CFString ) as? Int ?? 0
        print( "Device attached: \(product) (\(manufacturer)) \(vendorID):\(productID) \(usagePage):\(usage) [\(result)]" )
    }
    
    DispatchQueue.global( priority: DispatchQueue.GlobalQueuePriority.default ).async {
        
        guard let device = CAVHIDDevice( withHIDDeviceRef: hidDeviceRef ) else { return }
        
        guard let context = context else { return }
        let manager = Unmanaged<CAVHIDManager>.fromOpaque( context ).takeUnretainedValue()
        
        DispatchQueue.main.async {
            
            IOHIDDeviceRegisterRemovalCallback( hidDeviceRef, CAVHIDManagerDeviceRemovedHandler, context )
            
            manager.mutableSetValue( forKey: CAVHIDManager.devicesKey ).add( device )
        }
    }
}

/*==========================================================================*/
private func CAVHIDManagerDeviceRemovedHandler( context: UnsafeMutableRawPointer?, result: IOReturn, hidDeviceRefPointer: UnsafeMutableRawPointer? ) {
    
    guard let hidDevicePointer = hidDeviceRefPointer else { return }
    let hidDevice = Unmanaged<IOHIDDevice>.fromOpaque( hidDevicePointer ).takeUnretainedValue()
    
    if LOG_ATTACH_AND_DETACH == true {
        let manufacturer = CAVHIDDeviceGetProperty( hidDevice, kIOHIDManufacturerKey as CFString ) as? String ?? ""
        let product = CAVHIDDeviceGetProperty( hidDevice, kIOHIDProductKey as CFString ) as? String ?? ""
        print( "Device removed: \(product) (\(manufacturer)) [\(result)]" )
    }
    
    guard let context = context else { return }
    let manager = Unmanaged<CAVHIDManager>.fromOpaque( context ).takeUnretainedValue()
    
    for object in manager.devices {
        
        let device = object as! CAVHIDDevice
        if device.hidDeviceRef !== hidDevice {
            continue
        }
        
        manager.mutableSetValue( forKey: CAVHIDManager.devicesKey ).remove( device )
        return
    }
}
