/*===========================================================================
 CAVHIDManager.swift
 Cavalla
 Copyright (c) 2015-2016 Ken Heglund. All rights reserved.
===========================================================================*/

import Foundation

/*==========================================================================*/

private let CAVHIDManagerDevicesKey = "devices"

/*==========================================================================*/

class CAVHIDManager: NSObject {
    
    private(set) var hidManagerRef: IOHIDManagerRef? = nil
    
    dynamic var devices: NSMutableSet = NSMutableSet()
    
    // MARK: - CAVHIDManager implementation
    
    /*==========================================================================*/
    func open() -> IOReturn {
        
        // TODO: Change this function to throw instead of returning an IOReturn?
        
        let options = IOOptionBits(kIOHIDOptionsTypeNone)
        guard let hidManagerRef = IOHIDManagerCreate( kCFAllocatorDefault, options )?.takeUnretainedValue() else { return KERN_FAILURE }
        
        self.hidManagerRef = hidManagerRef
        
        let result = IOHIDManagerOpen( hidManagerRef, IOOptionBits(kIOHIDOptionsTypeNone) )
        guard result == kIOReturnSuccess else { return result }
        
        let context = UnsafeMutablePointer<Void>( Unmanaged.passUnretained( self ).toOpaque() )
        
        IOHIDManagerSetDeviceMatching( hidManagerRef, [:] )
        IOHIDManagerRegisterDeviceMatchingCallback( hidManagerRef, CAVHIDManagerDeviceAttachedHandler, context )
        IOHIDManagerScheduleWithRunLoop( hidManagerRef, CFRunLoopGetMain(), kCFRunLoopDefaultMode )
        
        return kIOReturnSuccess
    }
    
    /*==========================================================================*/
    func close() {
        
        let hidManagerRef = self.hidManagerRef
        
        IOHIDManagerClose( hidManagerRef, IOOptionBits(kIOHIDOptionsTypeNone) )
        IOHIDManagerUnscheduleFromRunLoop( hidManagerRef, CFRunLoopGetMain(), kCFRunLoopDefaultMode )
        
        self.mutableSetValueForKey( CAVHIDManagerDevicesKey ).removeAllObjects()
        
        self.hidManagerRef = nil
    }
}

let LOG_ATTACH_AND_DETACH = true

/*==========================================================================*/
private func CAVHIDManagerDeviceAttachedHandler( context: UnsafeMutablePointer<Void>, result: IOReturn, sender: UnsafeMutablePointer<Void>, hidDeviceRef: IOHIDDevice! ) {
    
    if LOG_ATTACH_AND_DETACH == true {
        let manufacturer = IOHIDDeviceGetProperty( hidDeviceRef, kIOHIDManufacturerKey )?.takeUnretainedValue() as? String ?? ""
        let product = IOHIDDeviceGetProperty( hidDeviceRef, kIOHIDProductKey )?.takeUnretainedValue() as? String ?? ""
        print( "Device attached: \(product) (\(manufacturer)) [\(result)]" )
    }
    
    IOHIDDeviceRegisterRemovalCallback( hidDeviceRef, CAVHIDManagerDeviceRemovedHandler, context )
    
    let manager: CAVHIDManager = Unmanaged<CAVHIDManager>.fromOpaque( COpaquePointer( context ) ).takeUnretainedValue()
    
    guard let device = CAVHIDDevice( withHIDDeviceRef: hidDeviceRef ) else { return }
    manager.mutableSetValueForKey( CAVHIDManagerDevicesKey ).addObject( device )
}

/*==========================================================================*/
private func CAVHIDManagerDeviceRemovedHandler( context: UnsafeMutablePointer<Void>, result: IOReturn, hidDeviceRefPointer: UnsafeMutablePointer<Void> ) {

    let hidDeviceRef: IOHIDDeviceRef = Unmanaged<IOHIDDeviceRef>.fromOpaque( COpaquePointer( hidDeviceRefPointer ) ).takeUnretainedValue()
    
    if LOG_ATTACH_AND_DETACH == true {
        let manufacturer = IOHIDDeviceGetProperty( hidDeviceRef, kIOHIDManufacturerKey )?.takeUnretainedValue() as? String ?? ""
        let product = IOHIDDeviceGetProperty( hidDeviceRef, kIOHIDProductKey )?.takeUnretainedValue() as? String ?? ""
        print( "Device removed: \(product) (\(manufacturer)) [\(result)]" )
    }

    let manager: CAVHIDManager = Unmanaged<CAVHIDManager>.fromOpaque( COpaquePointer( context ) ).takeUnretainedValue()
    
    for object in manager.devices {
        
        let device = object as! CAVHIDDevice
        if device.hidDeviceRef !== hidDeviceRef {
            continue
        }
        
        manager.mutableSetValueForKey( CAVHIDManagerDevicesKey ).removeObject( device )
        return
    }
}
