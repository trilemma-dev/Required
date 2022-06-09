//
//  SecurityCommon.swift
//  Required
//
//  Created by Josh Kaplan on 2022-05-20
//

import Foundation

func cfTypeRefAsSwiftType(_ ref: AnyObject) -> AnyHashable? {
    switch CFGetTypeID(ref as CFTypeRef) {
        case CFNullGetTypeID():
            return nil
        case CFBooleanGetTypeID():
            return ref as! Bool
        case CFStringGetTypeID():
            return ref as! String
        case CFNumberGetTypeID():
            let number = ref as! NSNumber
            switch CFNumberGetType(number) {
                case .sInt8Type:        return number.int8Value
                case .sInt16Type:       return number.int16Value
                case .sInt32Type:       return number.int32Value
                case .sInt64Type:       return number.int64Value
                case .float32Type:      return number.floatValue
                case .float64Type:      return number.doubleValue
                case .charType:         return number.int8Value
                case .shortType:        return number.int16Value
                case .intType:          return number.intValue
                case .longType:         return number.int32Value
                case .longLongType:     return number.int64Value
                case .floatType:        return number.floatValue
                case .doubleType:       return number.doubleValue
                case .cfIndexType:      return number.intValue // CFIndex is a type alias for Int
                case .nsIntegerType:    return number.intValue
                case .cgFloatType:      return number.floatValue
                @unknown default:       return number // Failed to convert, leave as as NSNumber
            }
        case CFDateGetTypeID():
            return ref as! Date
        case CFDataGetTypeID():
            return ref as! Data
        case CFArrayGetTypeID():
            return (ref as! NSArray).map { cfTypeRefAsSwiftType($0 as AnyObject) }
        case CFDictionaryGetTypeID():
            return Dictionary(uniqueKeysWithValues: (ref as! NSDictionary).map { (key, value) in
                ( cfTypeRefAsSwiftType(key as AnyObject), cfTypeRefAsSwiftType(value as AnyObject))
            })
        case CFSetGetTypeID():
            return Set<AnyHashable?>((ref as! NSSet).map { cfTypeRefAsSwiftType($0 as AnyObject) })
        
        // Failed to convert, leave as-is
        default:
            return ref as? AnyHashable
    }
}
