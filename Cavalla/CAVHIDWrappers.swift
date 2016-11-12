/*===========================================================================
 CAVHIDWrappers.swift
 Cavalla
 
 This file contains wrappers for HIDManager functions that seem to be improperly interpreted for Swift 3.
 
 The primary problem is that the IOKit functions should return optionals (the underlying C functions may return NULL), but the generated Swift APIs return non-optional values.  Therefore, these functions wrap the value returned from IOKit into optional values.
 
 These functions are unnecessary for Swift 2.x and will hopefully be unnecessary for Swift 3+.
 
 Copyright (c) 2016 OrderedBytes. All rights reserved.
 ===========================================================================*/

import Foundation

/*==========================================================================*/
func CAVHIDDeviceGetProperty( _ device: IOHIDDevice, _ key: CFString ) -> AnyObject? {
    return IOHIDDeviceGetProperty( device, key )
}

/*==========================================================================*/
func CAVHIDValueGetElement( _ value: IOHIDValue ) -> IOHIDElement? {
    return IOHIDValueGetElement( value )
}

/*==========================================================================*/
func CAVHIDQueueCopyNextValueWithTimeout( _ queue: IOHIDQueue, _ timeout: CFTimeInterval ) -> IOHIDValue? {
    return IOHIDQueueCopyNextValueWithTimeout( queue, timeout )
}
