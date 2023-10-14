/*===========================================================================
 IsNotZeroTransformer.swift
 Cavalla
 Copyright (c) 2016,2023 Ken Heglund. All rights reserved.
 ===========================================================================*/

import AppKit


// MARK: - IsNotZeroTransformer

class IsNotZeroTransformer: ValueTransformer {
	public static let name = NSValueTransformerName(rawValue: "IsNotZeroTransformer")
	
	
	// MARK: - NSValueTransformer
	
	override class func allowsReverseTransformation() -> Bool {
		false
	}
	
	override func transformedValue(_ value: Any?) -> Any? {
		if let intValue = value as? Int {
			return intValue != 0
		} else {
			return false
		}
	}
}
