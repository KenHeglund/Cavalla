/*===========================================================================
 CAVHIDDevice.swift
 Cavalla
 Copyright (c) 2015-2019 Ken Heglund. All rights reserved.
===========================================================================*/

import Foundation
import IOKit.hid

/// Extends IOHIDValue to provide a String representation.
extension IOHIDValue {
    
    /// Returns a String representation of the IOHIDValue instance.
    func valueAsString() -> String {
        
        let hidElementRef = IOHIDValueGetElement(self)
        let elementCookie = IOHIDElementGetCookie(hidElementRef)
        let longValueSize = IOHIDValueGetLength(self)
        
        let cookieNumberFormat = NSLocalizedString("Cookie %u:", comment: "Cookie number format")
        var stringValue = String.localizedStringWithFormat(cookieNumberFormat, elementCookie)
        
        if longValueSize > MemoryLayout<Int32>.size {
            
            let longValueSource = IOHIDValueGetBytePtr(self)
            for index in 0 ..< longValueSize {
                stringValue += String(format: " %02X", longValueSource[index])
            }
        }
        else {
            
            let eventValue = IOHIDValueGetIntegerValue(self)
            stringValue += String(format: " 0x%08X", eventValue)
        }
        
        return stringValue
    }
}

/// A class that represents a IOHIDDevice instance.
class CAVHIDDevice: NSObject {
    
    /// The underlying IOHIDDevice instance.
    let hidDeviceRef: IOHIDDevice
    
    /// A IOHIDQueue instance to receive events from the device.
    fileprivate var hidQueueRef: IOHIDQueue?
    
    /// The user-visible name of the device.
    @objc dynamic let longProductName: String
    
    /// The VendorID value reported by the device.
    @objc dynamic let vendorIDString: String
    
    /// The ProductID value reported by the device.
    @objc dynamic let productIDString: String
    
    /// The Version value reported by the device.
    @objc dynamic let versionString: String
    
    /// The device's elements.
    @objc dynamic var elements: [CAVHIDElement] = []
    
    /// The number of elements the device has.
    @objc dynamic var elementCount: Int {
        return self.elements.count
    }
    
    /// Notification posted when the device receives a new event.
    public static let didReceiveValueNotification = Notification.Name(rawValue: "CAVHIDDeviceDidReceiveValueNotification")
    
    /// The event value as a String.
    public static let valueAsStringKey = "ValueAsStringKey"
    
    /// Key to sort devices by long name.
    public static let longProductNameKey = "longProductName"
    
    
    // MARK: - Init / Deinit
    
    /// Initialize with an IOHIDDevice instance.
    init?(withHIDDeviceRef hidDeviceRef: IOHIDDevice) {
        
        self.hidDeviceRef = hidDeviceRef
        
        let queueDepth = 50
        let options = IOOptionBits(kIOHIDOptionsTypeNone)
        guard let queue = IOHIDQueueCreate(kCFAllocatorDefault, hidDeviceRef, queueDepth, options) else {
            print("Failed to create event queue.  Skipping device...")
            return nil
        }
        
        self.hidQueueRef = queue
        
        let integerPropertyFormat = NSLocalizedString("0x%04lX (%ld)", comment: "Integer property format")
        
        if let vendorIDString = CAVHIDDevice.intPropertyFromDevice(hidDeviceRef, withKey: kIOHIDVendorIDKey) {
            self.vendorIDString = String.localizedStringWithFormat(integerPropertyFormat, vendorIDString, vendorIDString)
        }
        else {
            self.vendorIDString = CAVHIDDevice.notAvailableAbbreviation
        }
        
        if let productIDString = CAVHIDDevice.intPropertyFromDevice(hidDeviceRef, withKey: kIOHIDProductIDKey) {
            self.productIDString = String.localizedStringWithFormat(integerPropertyFormat, productIDString, productIDString)
        }
        else {
            self.productIDString = CAVHIDDevice.notAvailableAbbreviation
        }
        
        if let versionNumber = CAVHIDDevice.intPropertyFromDevice(hidDeviceRef, withKey: kIOHIDVersionNumberKey) {
            self.versionString = String.localizedStringWithFormat(integerPropertyFormat, versionNumber, versionNumber)
        }
        else {
            self.versionString = CAVHIDDevice.notAvailableAbbreviation
        }
        
        let productString = CAVHIDDevice.stringPropertyFromDevice(hidDeviceRef, withKey: kIOHIDProductKey) ?? NSLocalizedString("Unnamed Device", comment: "Default name for a device without a specific name")
        let manufacturerString = CAVHIDDevice.stringPropertyFromDevice(hidDeviceRef, withKey: kIOHIDManufacturerKey) ?? NSLocalizedString("Unnamed Manufacturer", comment: "Default name for a manufacturer without a specific name")
        let usagePage = CAVHIDDevice.intPropertyFromDevice(hidDeviceRef, withKey: kIOHIDPrimaryUsagePageKey) ?? 0
        let usage = CAVHIDDevice.intPropertyFromDevice(hidDeviceRef, withKey: kIOHIDPrimaryUsageKey) ?? 0
        
        let longProductNameFormat = NSLocalizedString("%@ (%@) [%ld:%ld]", comment: "Format for the long name of a device is the form 'Product (Manufacturer) [HIDUsagePage:HIDUsage]'")
        self.longProductName = String.localizedStringWithFormat(longProductNameFormat, productString, manufacturerString, usagePage, usage)
        
        super.init()
        
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDQueueRegisterValueAvailableCallback(queue, CAVHIDDeviceValueAvailableHandler, context)
        IOHIDQueueScheduleWithRunLoop(queue, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        
        guard let array = IOHIDDeviceCopyMatchingElements(hidDeviceRef, nil, options) else {
            assertionFailure()
            return
        }
        guard let elementRefArray = array as? [IOHIDElement] else {
            assertionFailure()
            return
        }
        
        self.elements = elementRefArray.map({ CAVHIDElement(withHIDElementRef: $0, device: self) })
    }
    
    /// Deinitialize.
    deinit {
        
        if let queue = self.hidQueueRef {
            
            IOHIDQueueStop(queue)
            IOHIDQueueUnscheduleFromRunLoop(queue, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            
            // A IOHIDQueue apparently holds a reference to its device to allow it to remove itself from the device when the queue is deallocated.  If the device is deallocated first, it looks like that reference becomes a dangling pointer which will cause a bad access exception when the queue is deallocated.  To force the deallocations to occur in the correct sequence, the reference to the queue is nil'd here before the ivars are destroyed.
            self.hidQueueRef = nil
        }
    }
    
    
    // MARK: - CAVHIDDevice implementation
    
    /// Add the given element to the device's event queue.
    func enqueueHIDElementRef(_ hidElementRef: IOHIDElement) {
        
        guard let queue = self.hidQueueRef else {
            assertionFailure()
            return
        }
        
        IOHIDQueueStop(queue)
        IOHIDQueueAddElement(queue, hidElementRef)
        IOHIDQueueStart(queue)
    }
    
    /// Remove the given element from the device's event queue.
    func dequeueHIDElementRef(_ hidElementRef: IOHIDElement) {
        
        guard let queue = self.hidQueueRef else {
            assertionFailure()
            return
        }
        
        IOHIDQueueStop(queue)
        IOHIDQueueRemoveElement(queue, hidElementRef)
        IOHIDQueueStart(queue)
    }
    
    /// Remove all elements from the device's event queue.
    func dequeueAllElements() {
        self.elements.forEach({ $0.isEnabled = false })
    }
    
    /// Returns `true` if the device's event queue contains the given element.
    func queueContainsHIDElementRef(_ hidElementRef: IOHIDElement) -> Bool {
        
        guard let queue = self.hidQueueRef else {
            assertionFailure()
            return false
        }
        
        return IOHIDQueueContainsElement(queue, hidElementRef)
    }
    
    
    // MARK: - CAVHIDDevice internal
    
    /// A string that is shown when a value is not available.
    private static let notAvailableAbbreviation = NSLocalizedString("n/a", comment: "Short form of 'Not Available'")
    
    /// Returns the property value of the device as a String.
    /// - parameter hidDeviceRef: The IOHIDDevice owning the property.
    /// - parameter key: The key of the desired property.
    /// - returns: The property value (if any) as a String.
    private static func stringPropertyFromDevice(_ hidDeviceRef: IOHIDDevice, withKey key: String) -> String? {
        return IOHIDDeviceGetProperty(hidDeviceRef, key as CFString) as? String
    }
    
    /// Returns the property value of the device as an Int.
    /// - parameter hidDeviceRef: The IOHIDDevice owning the property.
    /// - parameter key: The key of the desired property.
    /// - returns: The property value (if any) as an Int.
    private static func intPropertyFromDevice(_ hidDeviceRef: IOHIDDevice, withKey key: String) -> Int? {
        return IOHIDDeviceGetProperty(hidDeviceRef, key as CFString) as? Int
    }
}


// MARK: -

/// Callback that is called when new events are available from the device.
private func CAVHIDDeviceValueAvailableHandler(context: UnsafeMutableRawPointer?, result: IOReturn, sender: UnsafeMutableRawPointer?) {
    
    guard let context = context else {
        assertionFailure()
        return
    }
    
    let device = Unmanaged<CAVHIDDevice>.fromOpaque(context).takeUnretainedValue()
    
    guard let queue = device.hidQueueRef else {
        assertionFailure()
        return
    }
    
    let notificationCenter = NotificationCenter.default
    
    while true {
        
        guard let hidValueRef = IOHIDQueueCopyNextValueWithTimeout(queue, 0.0) else {
            return
        }
        
        let userInfo = [
            CAVHIDDevice.valueAsStringKey : hidValueRef.valueAsString(),
        ]
        
        notificationCenter.post(name: CAVHIDDevice.didReceiveValueNotification, object: device, userInfo: userInfo)
    }
}
