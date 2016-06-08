/*===========================================================================
 CAVHIDDevice.swift
 Cavalla
 Copyright (c) 2015-2016 Ken Heglund. All rights reserved.
===========================================================================*/

import Foundation
import IOKit.hid

/*==========================================================================*/

extension IOHIDValueRef {
    
    func valueAsString() -> String {
        
        guard let hidElementRef = IOHIDValueGetElement( self )?.takeUnretainedValue() else { return "<value has no associated element>" }
        let elementCookie = IOHIDElementGetCookie( hidElementRef )
        let longValueSize = IOHIDValueGetLength( self )
        
        var stringValue = String( format: "Cookie %u:", elementCookie )
        
        if ( longValueSize > sizeof(Int32) ) {
            
            let longValueSource = IOHIDValueGetBytePtr( self )
            for index in 0 ..< longValueSize {
                stringValue += String( format: " %02X", longValueSource[index] )
            }
        }
        else {
            
            let eventValue = IOHIDValueGetIntegerValue( self )
            stringValue += String( format: " 0x%08X", eventValue )
        }
        
        return stringValue
    }
}

/*==========================================================================*/

let CAVHIDDeviceDidReceiveValueNotification = "CAVHIDDeviceDidReceiveValueNotification"
let CAVHIDDeviceValueAsStringKey = "ValueAsStringKey"
let CAVHIDDeviceLongProductNameKey = "longProductName"

/*==========================================================================*/

class CAVHIDDevice: NSObject {

    let hidDeviceRef: IOHIDDeviceRef
    private let hidQueueRef: IOHIDQueueRef!
    
    dynamic var longProductName = ""
    dynamic var vendorIDString = "n/a"
    dynamic var productIDString = "n/a"
    dynamic var versionString = "n/a"
    
    dynamic var elements = NSArray()
    dynamic var elementCount: Int { return self.elements.count }
    
    // MARK: - Init / Deinit
    
    /*==========================================================================*/
    init?( withHIDDeviceRef hidDeviceRef: IOHIDDeviceRef ) {
        
        self.hidDeviceRef = hidDeviceRef
        
        let queueDepth = 50
        self.hidQueueRef = IOHIDQueueCreate( kCFAllocatorDefault, hidDeviceRef, queueDepth, IOOptionBits(kIOHIDOptionsTypeNone) )?.takeUnretainedValue()
        
        super.init()
        
        guard let queue = self.hidQueueRef else { return nil }
        
        let context = UnsafeMutablePointer<Void>( Unmanaged.passUnretained( self ).toOpaque() )
        IOHIDQueueRegisterValueAvailableCallback( queue, CAVHIDDeviceValueAvailableHandler, context )
        IOHIDQueueScheduleWithRunLoop( queue, CFRunLoopGetMain(), kCFRunLoopDefaultMode )
        
        let integerPropertyFormat = "0x%04lX (%ld)"
        
        if let versionNumber = self.intPropertyFromDevice( kIOHIDVersionNumberKey ) {
            self.versionString = String( format: integerPropertyFormat, versionNumber, versionNumber )
        }
        
        if let vendorIDString = self.intPropertyFromDevice( kIOHIDVendorIDKey ) {
            self.vendorIDString = String( format: integerPropertyFormat, vendorIDString, vendorIDString )
        }
        
        if let productIDString = self.intPropertyFromDevice( kIOHIDProductIDKey ) {
            self.productIDString = String( format: integerPropertyFormat, productIDString, productIDString )
        }
        
        let productString = self.stringPropertyFromDevice( kIOHIDProductKey ) ?? "Unnamed Device"
        let manufacturerString = self.stringPropertyFromDevice( kIOHIDManufacturerKey ) ?? "Unnamed Manufacturer"
        let usagePage = self.intPropertyFromDevice( kIOHIDPrimaryUsagePageKey ) ?? 0
        let usage = self.intPropertyFromDevice( kIOHIDPrimaryUsageKey ) ?? 0
        self.longProductName = String( format: "%@ (%@) [%ld:%ld]", productString, manufacturerString, usagePage, usage )
        
        let array: CFArray? = IOHIDDeviceCopyMatchingElements( hidDeviceRef, [:], IOOptionBits(kIOHIDOptionsTypeNone) )?.takeUnretainedValue()
        if let elementArray = array {
            
            let mutableElements = NSMutableArray()
            
            let elementCount = CFArrayGetCount( elementArray )
            for index in 0 ..< elementCount {
                
                let arrayValue: UnsafePointer<Void> = CFArrayGetValueAtIndex( elementArray, index )
                let elementRef: IOHIDElement = Unmanaged<IOHIDElement>.fromOpaque( COpaquePointer( arrayValue ) ).takeUnretainedValue()
                
                mutableElements.addObject( CAVHIDElement( withHIDElementRef: elementRef, device: self ) )
            }
            
            self.elements = mutableElements
        }
    }
    
    /*==========================================================================*/
    deinit {
        
        let hidQueueRef = self.hidQueueRef
        
        IOHIDQueueStop( hidQueueRef )
        IOHIDQueueUnscheduleFromRunLoop( hidQueueRef, CFRunLoopGetMain(), kCFRunLoopDefaultMode )
    }
    
    // MARK: - CAVHIDDevice implementation
    
    /*==========================================================================*/
    func enqueueHIDElementRef( hidElementRef: IOHIDElementRef ) {
        
        let hidQueueRef = self.hidQueueRef
        
        IOHIDQueueStop( hidQueueRef )
        IOHIDQueueAddElement( hidQueueRef, hidElementRef )
        IOHIDQueueStart( hidQueueRef )
    }

    /*==========================================================================*/
    func dequeueHIDElementRef( hidElementRef: IOHIDElementRef ) {
        
        let hidQueueRef = self.hidQueueRef
        
        IOHIDQueueStop( hidQueueRef )
        IOHIDQueueRemoveElement( hidQueueRef, hidElementRef )
        IOHIDQueueStart( hidQueueRef )
    }
    
    /*==========================================================================*/
    func dequeueAllElements() {
        
        for element in self.elements as! [CAVHIDElement] {
            element.enabled = false
        }
    }
    
    /*==========================================================================*/
    func queueContainsHIDElementRef( hidElementRef: IOHIDElementRef ) -> Bool {
        return IOHIDQueueContainsElement( self.hidQueueRef, hidElementRef )
    }
    
    
    // MARK: - CAVHIDDevice internal
    
    /*==========================================================================*/
    private func stringPropertyFromDevice( key: String ) -> String? {
        return ( IOHIDDeviceGetProperty( self.hidDeviceRef, key )?.takeUnretainedValue() as? String )
    }
    
    /*==========================================================================*/
    private func intPropertyFromDevice( key: String ) -> Int? {
        return ( IOHIDDeviceGetProperty( self.hidDeviceRef, key )?.takeUnretainedValue() as? Int )
    }
    
}

// MARK: -

/*==========================================================================*/
private func CAVHIDDeviceValueAvailableHandler( context: UnsafeMutablePointer<Void>, result: IOReturn, sender: UnsafeMutablePointer<Void> ) {
    
    let device: CAVHIDDevice = Unmanaged<CAVHIDDevice>.fromOpaque( COpaquePointer( context ) ).takeUnretainedValue()
    let hidQueueRef = device.hidQueueRef
    
    let notificationCenter = NSNotificationCenter.defaultCenter()
    
    repeat {
        
        guard let hidValueRef = IOHIDQueueCopyNextValueWithTimeout( hidQueueRef, 0.0 )?.takeUnretainedValue() else { return }
        
        let userInfo = [ CAVHIDDeviceValueAsStringKey : hidValueRef.valueAsString() ]
        
        notificationCenter.postNotificationName( CAVHIDDeviceDidReceiveValueNotification, object: device, userInfo: userInfo )
        
    } while ( true )
}
