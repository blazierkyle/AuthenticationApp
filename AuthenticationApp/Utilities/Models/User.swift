//
//  User.swift
//  AuthenticationApp
//
//  Created by Kyle Blazier on 1/30/17.
//  Copyright © 2017 Kyle Blazier. All rights reserved.
//

import Foundation

class User: ExpressibleByJSONDictionary {
    var id: Int
    var username: String
    var email: String
    var name: String?
    var deviceToken: String?
    var authToken: String?
    
    required public init(dictionary: [String: AnyObject]) throws {
        self.id = try dictionary.decode("id")
        self.username = try dictionary.decode("username")
        self.email = try dictionary.decode("email")
        self.name = try dictionary.decode("name")
        self.deviceToken = try dictionary.decode("deviceToken")
    }
    
    func getUserDetailsString() -> String {
        return "User Details: ID= \(id), Username= \(username), Email= \(email), Name= \(name ?? "No Name"), Device Token= \(deviceToken ?? "No device token")"
    }
}

/// Extensions that provide bulk decoding and initing
public extension ExpressibleByJSONDictionary {
    
    /// Creates an instance of `Self` where `data` contains a valid JSON representation of `Self`
    public static func make(data: Data) throws -> Self {
        guard let object = try JSONSerialization.jsonObject(with: data, options: []) as? JSONDictionary else {
            throw JSONParseError.expectedJSONDictionary
        }
        
        return try Self.init(dictionary: object)
    }
    
    /// Creates instances of `Self` where `data` contains a valid JSON representation of an array of `Self`
    public static func make(data: Data) throws -> [Self] {
        guard let object = try JSONSerialization.jsonObject(with: data, options: []) as? [JSONDictionary] else {
            throw JSONParseError.expectedJSONArray
        }
        
        return try make(array: object)
    }
    
    /// Creates instances of `Self` where `array` contains valid JSON representations of `Self`
    public static func make(array: [[String:AnyObject]]) throws -> [Self] {
        return try array.map { try Self.init(dictionary: $0) }
    }
}

/// Provides methods to decode values from a JSON dictionary that throw JSONParseError based on type
public extension Dictionary where Key: ExpressibleByStringLiteral, Value: AnyObject {
    
    /// decode the value for `key` where `T` is not optional
    func decode<T>(_ key: Key) throws -> T {
        return try decodeNonOptionalValue(for: key)
    }
    
    /// decode the value for `key` where `T` can be optional. Being absent or NSNull is allowed
    func decode<T: ExpressibleByNilLiteral>(_ key: Key) throws -> T {
        let value = self[key]
        
        if value == nil {
            return nil
        } else {
            return try decodeNonOptionalValue(for: key)
        }
    }
    
    /// performs the work of decoding the value for `key` where `T` is not optional
    func decodeNonOptionalValue<T>(for key: Key) throws -> T {
        switch self[key] {
        case let value as T:
            return value
            
        case nil:
            throw JSONParseError.missingKey(String(describing: key))
            
        case .some:
            throw JSONParseError.valueTypeMismatch(String(describing: key))
        }
    }
}

// Handy typealias for working with JSON
typealias JSON = AnyObject
typealias JSONArray = [JSON]
typealias JSONDictionary = [String: JSON]

public enum JSONParseError: Error {
    /// Missing a required key while decoding
    case missingKey(String)
    
    /// Type mismatch on a value while decoding
    case valueTypeMismatch(String)
    
    /// Expecting a JSONDictionary but got something else (probably JSONArray or JSON)
    case expectedJSONDictionary
    
    /// Expecting a JSONArray but got something else (probably JSONDictionary or JSON)
    case expectedJSONArray
}

/// Conforming to this protocol enables gives access to convenient JSON parsing extensions
public protocol ExpressibleByJSONDictionary {
    
    /// Init with JSONDictionary, throwing an error (likely JSONParseError) if the contents are invalid
    init(dictionary: [String:AnyObject]) throws
}
