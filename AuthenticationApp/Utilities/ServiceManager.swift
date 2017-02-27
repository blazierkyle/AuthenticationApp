//
//  ServiceManager.swift
//  AuthenticationApp
//
//  Created by Kyle Blazier on 2/1/17.
//  Copyright © 2017 Kyle Blazier. All rights reserved.
//

import Foundation
import KeychainAccess

class ServiceManager {
    
    static let sharedInstance = ServiceManager()
    
    let keychain = Keychain(service: keyChainServiceName)
    
    func logMessage(message: String?, dictionary: [String:Any]? = nil) {
        print("*** Begin log statement in Service Manager ***")
        if let message = message {
            print(message)
        }
        if let dictionary = dictionary {
            print(dictionary)
        }
        print("*** End log statement in Service Manager ***")
    }
    
    func register(registrationDict: [String:Any], successBlock: @escaping (_ currentUser: User?)->Void, failure: @escaping (_ error: String?)->Void) {
        
        // Form URLRequest
        guard let url = URL(string: "\(webserviceURL)/api/v1/register") else {return}
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.cachePolicy = NSURLRequest.CachePolicy.reloadIgnoringCacheData
        
        // Add required parameters and set header value
//        let paramsDict = ["username": username, "password": password, "email": email]
        let dictData = try? JSONSerialization.data(withJSONObject: registrationDict)
        request.httpBody = dictData
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            
            if let error = error {
                failure(error.localizedDescription)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                // No decodable response
                failure(nil)
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                do {
                    
                    guard let errorDict = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] else {
                        failure(nil)
                        return
                    }
                    
                    // Parsed erroneous response into a dictionary - check for specific error messages
                    guard let error = errorDict["error"] as? Bool, error == true, let errorMessage = errorDict["message"] as? String else {
                        failure(nil)
                        return
                    }
                    
                    failure(errorMessage)
                    
                } catch {
                    failure(nil)
                }
                return
            }
            
            do {
                guard let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] else {
                    failure(nil)
                    return
                }
                
                // Check for errors
                if let error = json["error"] as? String {
                    failure(error)
                    return
                }
                
                guard let success = json["success"] as? Bool, success == true else {
                    failure(nil)
                    return
                }
                
                // Format & store authentication token in keychain
                guard let user = json["user"] as? [String:Any] else {
                    failure(nil)
                    return
                }
                
                // Convert to User model
                let authenticatedUser = try User(dictionary: user as [String:AnyObject])
                
                // Check if we have a timestamp for when the session began
                if let sessionBegan = json["sessionStart"] as? String {
                    authenticatedUser.sessionBegan = sessionBegan
                }
                
                guard let apiKey = user["api_key"] as? String, let apiSecret = user["api_secret"] as? String else {
                    failure(nil)
                    return
                }
                
                let authString = "\(apiKey):\(apiSecret)"
                
                guard let authData = authString.data(using: .utf8) else {
                    failure(nil)
                    return
                }
                
                let encodedAuthString = "Basic \(authData.base64EncodedString())"
                
                authenticatedUser.authToken = encodedAuthString
                
                if useTouchID {
                    // Try to store the value as a protected value with Touch ID / device password authentication required to access it
                    DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                        do {
                            try self.keychain
                                .accessibility(.whenPasscodeSetThisDeviceOnly, authenticationPolicy: .userPresence)
                                .authenticationPrompt("Authenticate to allow the app to use Touch ID to log you in.")
                                .set(encodedAuthString, key: kLoginKey)
                            self.logMessage(message: "Auth token saved to keychain for use with Touch ID / password")
                        } catch {
                            self.logMessage(message: "Could not setup the app to use Touch ID with this keychain value - fallback to standard authentication")
                            // Just store the value regularly in th keychain
                            do {
                                try self.keychain.set(encodedAuthString, key: kLoginKey)
                                self.logMessage(message: "Auth token saved to keychain")
                            } catch let error {
                                self.logMessage(message: "Couldn't save to Keychain: \(error.localizedDescription)")
                            }
                        }
                    }
                } else {
                    // Just store the value regularly in th keychain
                    do {
                        try self.keychain.set(encodedAuthString, key: kLoginKey)
                        self.logMessage(message: "Auth token saved to keychain")
                    } catch let error {
                        self.logMessage(message: "Couldn't save to Keychain: \(error.localizedDescription)")
                    }
                }
                
                // Success - return User in completion block
                successBlock(authenticatedUser)
                
            } catch {
                failure(nil)
            }
        }
        
        task.resume()
        
    }
    
    func login(registrationDict: [String:Any], successBlock: @escaping (_ currentUser: User?)->Void, failure: @escaping (_ error: String?)->Void) {
        
        // Form URLRequest
        guard let url = URL(string: "\(webserviceURL)/api/v1/login") else {return}
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.cachePolicy = NSURLRequest.CachePolicy.reloadIgnoringCacheData
        
        // Add required parameters and set header value
        let dictData = try? JSONSerialization.data(withJSONObject: registrationDict)
        request.httpBody = dictData
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            
            if let error = error {
                failure(error.localizedDescription)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                // No decodable response
                failure(nil)
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                do {
                    guard let errorDict = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] else {
                        failure(nil)
                        return
                    }
                    
                    // Parsed erroneous response into a dictionary - check for specific error messages
                    guard let error = errorDict["error"] as? Bool, error == true, let errorMessage = errorDict["message"] as? String else {
                        failure(nil)
                        return
                    }
                    
                    failure(errorMessage)
                    
                } catch {
                    failure(nil)
                }
                return
            }
            
            do {
                guard let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] else {
                    failure(nil)
                    return
                }
                
                // Check for errors
                if let error = json["error"] as? String {
                    failure(error)
                    return
                }
                
                guard let success = json["success"] as? Bool, success == true else {
                    failure(nil)
                    return
                }
                
                // Format & store authentication token in keychain
                guard let user = json["user"] as? [String:Any] else {
                    failure(nil)
                    return
                }
                
                guard let apiKey = user["api_key"] as? String, let apiSecret = user["api_secret"] as? String else {
                    failure(nil)
                    return
                }
                
                let authString = "\(apiKey):\(apiSecret)"
                
                guard let authData = authString.data(using: .utf8) else {
                    failure(nil)
                    return
                }
                
                let encodedAuthString = "Basic \(authData.base64EncodedString())"
                
                if useTouchID {
                    // Try to store the value as a protected value with Touch ID / device password authentication required to access it
                    DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                        do {
                            try self.keychain
                                .accessibility(.whenPasscodeSetThisDeviceOnly, authenticationPolicy: .userPresence)
                                .authenticationPrompt("Authenticate to allow the app to use Touch ID to log you in.")
                                .set(encodedAuthString, key: kLoginKey)
                            self.logMessage(message: "Auth token saved to keychain for use with Touch ID / password")
                        } catch {
                            self.logMessage(message: "Could not setup the app to use Touch ID with this keychain value - fallback to standard authentication")
                            // Just store the value regularly in th keychain
                            do {
                                try self.keychain.set(encodedAuthString, key: kLoginKey)
                                self.logMessage(message: "Auth token saved to keychain")
                            } catch let error {
                                self.logMessage(message: "Couldn't save to Keychain: \(error.localizedDescription)")
                            }
                        }
                    }
                } else {
                    // Just store the value regularly in th keychain
                    do {
                        try self.keychain.set(encodedAuthString, key: kLoginKey)
                        self.logMessage(message: "Auth token saved to keychain")
                    } catch let error {
                        self.logMessage(message: "Couldn't save to Keychain: \(error.localizedDescription)")
                    }
                }
                
                self.logMessage(message: "Successfully logged in the user", dictionary: user)
                
                // Convert to User model
                let authenticatedUser = try User(dictionary: user as [String:AnyObject])
                authenticatedUser.authToken = encodedAuthString
                
                // Check if we have a timestamp for when the session began
                if let sessionBegan = json["sessionStart"] as? String {
                    authenticatedUser.sessionBegan = sessionBegan
                }
                
                // Success - return user in completion block
                successBlock(authenticatedUser)
                
            } catch {
                failure(nil)
            }
        }
        
        task.resume()
        
    }
    
    func getUserDetails(authToken: String, successBlock: @escaping (_ currentDetails: User?)->Void, failure: @escaping (_ error: String?)->Void) {
        
        // Form URLRequest
        guard let url = URL(string: "\(webserviceURL)/api/v1/me") else {return}
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = NSURLRequest.CachePolicy.reloadIgnoringCacheData
        
        // Add required parameters and set header value
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(authToken, forHTTPHeaderField: "Authorization")
        
        let getUserDetailsTask = URLSession.shared.dataTask(with: request) { (data, response, error) in
            
            // Make sure we did not get an error
            if let error = error {
                failure(error.localizedDescription)
                return
            }
            
            // Make sure we got an HTTP Response
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                // No decodable response
                failure(nil)
                return
            }
            
            // Make sure the HTTP response is 200
            guard httpResponse.statusCode == 200 else {
                do {
                    // Convert the response to a dictionary
                    guard let errorDict = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] else {
                        failure(nil)
                        return
                    }
                    
                    // Parsed erroneous response into a dictionary - check for specific error messages
                    guard let error = errorDict["error"] as? Bool, error == true, let errorMessage = errorDict["message"] as? String else {
                        failure(nil)
                        return
                    }
                    
                    failure(errorMessage)
                    
                } catch {
                    // Couldn't convert the response to a dictionary - display generic error
                    failure(nil)
                }
                return
            }
            
            // We did not recieve an error, have an HTTP Response, recieved data back and have a 200 response code
            do {
                // Convert into dictionary
                guard let responseDict = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] else {
                    failure(nil)
                    return
                }
                
                guard let success = responseDict["success"] as? Bool, success == true, let userDetails = responseDict["user"] as? [String:Any] else {
                    failure(nil)
                    return
                }
                
                self.logMessage(message: "Successfully retrieved the user details", dictionary: userDetails)
                
                // Convert to User model
                let authenticatedUser = try User(dictionary: userDetails as [String:AnyObject])
                authenticatedUser.authToken = authToken
                
                // Check if we have a timestamp for when the session began
                if let sessionBegan = responseDict["sessionStart"] as? String {
                    authenticatedUser.sessionBegan = sessionBegan
                }
                
                // User is authenticated - return user in completion block
                successBlock(authenticatedUser)
                
            } catch {
                // Couldn't convert the response to a dictionary, or the dictionary to a model - display generic error
                failure(nil)
                return
            }
        }
        
        getUserDetailsTask.resume()
        
    }
    
    func updateUserDetails(valuesToUpdate: [String:Any], authToken: String, successBlock: @escaping (_ currentUser: User?)->Void, failure: @escaping (_ error: String?)->Void) {
        
        // Form URLRequest
        guard let url = URL(string: "\(webserviceURL)/api/v1/update") else {return}
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.cachePolicy = NSURLRequest.CachePolicy.reloadIgnoringCacheData
        
        // Add required parameters and set header value
        let dictData = try? JSONSerialization.data(withJSONObject: valuesToUpdate)
        request.httpBody = dictData
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(authToken, forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            
            if let error = error {
                failure(error.localizedDescription)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, let data = data else {
                // No decodable response
                failure(nil)
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                do {
                    guard let errorDict = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] else {
                        failure(nil)
                        return
                    }
                    
                    // Parsed erroneous response into a dictionary - check for specific error messages
                    guard let error = errorDict["error"] as? Bool, error == true, let errorMessage = errorDict["message"] as? String else {
                        failure(nil)
                        return
                    }
                    
                    failure(errorMessage)
                    
                } catch {
                    failure(nil)
                }
                return
            }
            
            do {
                guard let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] else {
                    failure(nil)
                    return
                }
                
                // Check for errors
                if let error = json["error"] as? String {
                    failure(error)
                    return
                }
                
                guard let success = json["success"] as? Bool, success == true else {
                    failure(nil)
                    return
                }
                
                // Format & store authentication token in keychain
                guard let userDetails = json["user"] as? [String:Any] else {
                    failure(nil)
                    return
                }
                
                self.logMessage(message: "Successfully updated user details", dictionary: userDetails)
                
                // Convert to User model
                let currentUser = try User(dictionary: userDetails as [String:AnyObject])
                currentUser.authToken = authToken
                
                // Check if we have a timestamp for when the session began
                if let sessionBegan = json["sessionStart"] as? String {
                    currentUser.sessionBegan = sessionBegan
                }
                
                // Success - return user in completion block
                successBlock(currentUser)
                
            } catch {
                failure(nil)
            }
        }
        
        task.resume()
        
    }
    
    func logout(authToken: String) {
        // Form URLRequest
        guard let url = URL(string: "\(webserviceURL)/api/v1/logout") else {return}
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.cachePolicy = NSURLRequest.CachePolicy.reloadIgnoringCacheData
        
        // Add required parameters and set header value
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(authToken, forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: request)
        task.resume()
    }
    
    
}
