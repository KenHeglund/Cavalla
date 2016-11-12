/*===========================================================================
 IsNotZeroTransformer.swift
 Cavalla
 Copyright (c) 2016 Ken Heglund. All rights reserved.
 ===========================================================================*/

import Cocoa

/*==========================================================================*/

class IsNotZeroTransformer: ValueTransformer {
    
    // MARK: - NSValueTransformer overrides
    
    /*==========================================================================*/
    override class func allowsReverseTransformation() -> Bool {
        return false
    }
    
    /*==========================================================================*/
    override func transformedValue( _ value: Any? ) -> Any? {
        guard let intValue = value as? Int else { return false }
        return intValue != 0
    }
}

/*==========================================================================*/
extension NSValueTransformerName {
    static let isNotZeroTransformer = NSValueTransformerName( rawValue: "IsNotZeroTransformer" )
}
