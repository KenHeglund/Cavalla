/*===========================================================================
 CAVHIDDevice.swift
 Cavalla
 Copyright (c) 2015-2016 Ken Heglund. All rights reserved.
===========================================================================*/

import Foundation
import IOKit.hid

/*==========================================================================*/

extension IOHIDValue {
    
    func valueAsString() -> String {
        
        let hidElementRef = IOHIDValueGetElement(self)
        let elementCookie = IOHIDElementGetCookie( hidElementRef )
        let longValueSize = IOHIDValueGetLength( self )
        
        var stringValue = String( format: "Cookie %u:", elementCookie )
        
        if ( longValueSize > MemoryLayout<Int32>.size ) {
            
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

class CAVHIDDevice: NSObject {

    let hidDeviceRef: IOHIDDevice
    fileprivate var hidQueueRef: IOHIDQueue?
    
    @objc dynamic var longProductName = ""
    @objc dynamic var vendorIDString = "n/a"
    @objc dynamic var productIDString = "n/a"
    @objc dynamic var versionString = "n/a"
    
    @objc dynamic var elements: [CAVHIDElement] = []
    @objc dynamic var elementCount: Int { return self.elements.count }
    
    public static let didReceiveValueNotification: Notification.Name = Notification.Name( rawValue: "CAVHIDDeviceDidReceiveValueNotification" )
    public static let valueAsStringKey = "ValueAsStringKey"
    public static let longProductNameKey = "longProductName"
    
    // MARK: - Init / Deinit
    
    /*==========================================================================*/
    init?( withHIDDeviceRef hidDeviceRef: IOHIDDevice ) {
        
        self.hidDeviceRef = hidDeviceRef
        
        let queueDepth = 50
        let options = IOOptionBits(kIOHIDOptionsTypeNone)
        guard let queue = IOHIDQueueCreate( kCFAllocatorDefault, hidDeviceRef, queueDepth, options ) else { return nil }
        
        self.hidQueueRef = queue
        
        super.init()
        
        let context = Unmanaged.passUnretained( self ).toOpaque()
        IOHIDQueueRegisterValueAvailableCallback( queue, CAVHIDDeviceValueAvailableHandler, context )
        IOHIDQueueScheduleWithRunLoop( queue, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue )
        
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
        
        guard let array = IOHIDDeviceCopyMatchingElements( hidDeviceRef, nil, options ) else { return }
        guard let elementRefArray = array as? [IOHIDElement] else { return }
        
        var elements: [CAVHIDElement] = []
        
        for element in elementRefArray {
            elements.append( CAVHIDElement( withHIDElementRef: element, device: self ) )
        }
        
        self.elements = elements
    }
    
    /*==========================================================================*/
    deinit {
        
        if let queue = self.hidQueueRef {
            
            IOHIDQueueStop( queue )
            IOHIDQueueUnscheduleFromRunLoop( queue, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue )
            
            // A IOHIDQueue apparently holds a reference to its device to allow it to remove itself from the device when the queue is deallocated.  If the device is deallocated first, it looks like that reference becomes a dangling pointer which will cause a bad access exception when the queue is deallocated.  To force the deallocations to occur in the correct sequence, the reference to the queue is nil'd here before the ivars are destroyed.
            self.hidQueueRef = nil
        }
    }
    
    // MARK: - CAVHIDDevice implementation
    
    /*==========================================================================*/
    func enqueueHIDElementRef( _ hidElementRef: IOHIDElement ) {
        
        guard let queue = self.hidQueueRef else { return }
        
        IOHIDQueueStop( queue )
        IOHIDQueueAddElement( queue, hidElementRef )
        IOHIDQueueStart( queue )
    }

    /*==========================================================================*/
    func dequeueHIDElementRef( _ hidElementRef: IOHIDElement ) {
        
        guard let queue = self.hidQueueRef else { return }
        
        IOHIDQueueStop( queue )
        IOHIDQueueRemoveElement( queue, hidElementRef )
        IOHIDQueueStart( queue )
    }
    
    /*==========================================================================*/
    func dequeueAllElements() {
        
        for element in self.elements {
            element.enabled = false
        }
    }
    
    /*==========================================================================*/
    func queueContainsHIDElementRef( _ hidElementRef: IOHIDElement ) -> Bool {
        guard let queue = self.hidQueueRef else { return false }
        return IOHIDQueueContainsElement( queue, hidElementRef )
    }
    
    
    // MARK: - CAVHIDDevice internal
    
    /*==========================================================================*/
    private func stringPropertyFromDevice( _ key: String ) -> String? {
        return ( IOHIDDeviceGetProperty( self.hidDeviceRef, key as CFString ) as? String )
    }
    
    /*==========================================================================*/
    private func intPropertyFromDevice( _ key: String ) -> Int? {
        return ( IOHIDDeviceGetProperty( self.hidDeviceRef, key as CFString ) as? Int )
    }
    
}

// MARK: -

/*==========================================================================*/
private func CAVHIDDeviceValueAvailableHandler( context: UnsafeMutableRawPointer?, result: IOReturn, sender: UnsafeMutableRawPointer? ) {
    
    guard let context = context else { return }
    let device = Unmanaged<CAVHIDDevice>.fromOpaque( context ).takeUnretainedValue()
    guard let queue = device.hidQueueRef else { return }
    
    let notificationCenter = NotificationCenter.default
    
    repeat {
        
        guard let hidValueRef = IOHIDQueueCopyNextValueWithTimeout( queue, 0.0 ) else { return }
        
        let userInfo = [ CAVHIDDevice.valueAsStringKey : hidValueRef.valueAsString() ]
        
        notificationCenter.post( name: CAVHIDDevice.didReceiveValueNotification, object: device, userInfo: userInfo )
        
    } while ( true )
}
