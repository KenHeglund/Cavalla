/*===========================================================================
 CAVHIDElement.swift
 Cavalla
 Copyright (c) 2015-2016 Ken Heglund. All rights reserved.
===========================================================================*/

import Foundation
import HIDSpecification

/*==========================================================================*/

class CAVHIDElement: NSObject {
    
    private unowned let device: CAVHIDDevice
    
    let hidElementRef: IOHIDElementRef
    let cookie: IOHIDElementCookie
    let canEnable: Bool
    
    var enabled: Bool {
        
        get {
            return self.device.queueContainsHIDElementRef( self.hidElementRef )
        }
        
        set(newValue) {
            
            guard self.canEnable else { return }
            
            if newValue == self.device.queueContainsHIDElementRef( self.hidElementRef ) {
                return
            }
            
            if newValue {
                self.device.enqueueHIDElementRef( self.hidElementRef )
            }
            else {
                self.device.dequeueHIDElementRef( self.hidElementRef )
            }
        }
    }
    
    let nameString: String
    let usageString: String
    let sizeString: String
    let addressString: String
    
    /*==========================================================================*/
    init( withHIDElementRef hidElementRef: IOHIDElementRef, device: CAVHIDDevice ) {
        
        self.device = device
        self.hidElementRef = hidElementRef
        
        self.cookie = IOHIDElementGetCookie( hidElementRef )
        self.canEnable = ( IOHIDElementGetReportSize( hidElementRef ) > 0 )
        
        let usage = Int( IOHIDElementGetUsage( hidElementRef ) )
        let usagePage = Int( IOHIDElementGetUsagePage( hidElementRef ) )
        self.nameString = HIDSpecification.nameForUsagePage( usagePage, usage: usage ) ?? "Custom Control"
        self.usageString = String( format: "0x%04X:0x%04X", usagePage, usage )
        
        let size = Int( IOHIDElementGetReportSize( hidElementRef ) )
        self.sizeString = String( format: "%lu", size )
        
        let pointer = Unmanaged.passUnretained( hidElementRef ).toOpaque()
        self.addressString = String( format: "%p", pointer )
    }
}
