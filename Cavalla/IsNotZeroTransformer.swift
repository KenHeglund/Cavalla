/*===========================================================================
 IsNotZeroTransformer.swift
 Cavalla
 Copyright (c) 2016-2019 Ken Heglund. All rights reserved.
 ===========================================================================*/

import Cocoa

/// Transformer class that converts a non-zero Integer value into a Bool true, and an Integer zero into a Bool false.
class IsNotZeroTransformer: ValueTransformer {
    
    public static let name = NSValueTransformerName(rawValue: "IsNotZeroTransformer")
    
    
    // MARK: - NSValueTransformer overrides
    
    /// Cannot perform reverse transformations.
    override class func allowsReverseTransformation() -> Bool {
        return false
    }
    
    /// Transforms the given Integer into a Bool.
    override func transformedValue(_ value: Any?) -> Any? {
        
        guard let intValue = value as? Int else {
            return false
        }
        
        return intValue != 0
    }
}
