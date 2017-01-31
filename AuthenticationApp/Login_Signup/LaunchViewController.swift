//
//  ViewController.swift
//  AuthenticationApp
//
//  Created by Kyle Blazier on 1/30/17.
//  Copyright © 2017 Kyle Blazier. All rights reserved.
//

import UIKit
import KeychainAccess

let kLoginKey = "LoginKey" // Customizeable - Key to save the authentication token in the Keychain (String)
let keyChainServiceName = "com.KyleBlazier.AuthenticationApp" // Customizeable - Name of Keychain we are using (String)
let webserviceURL = "http://0.0.0.0:8080" // Customizeable - URL of the Webservice we are hitting
let useTouchID = true // Customizeable - Whether or not you want to use 2-factor authentication

class LaunchViewController: UIViewController {
    
    var firstLoad = true
    
    var authenticatedUser: User?
    
    let keychain = Keychain(service: keyChainServiceName)

    override func viewDidLoad() {
        super.viewDidLoad()
        
        checkForExistingLogin()
        
        // Hide nav bar
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        // This will happen if we've logged in, signed up or logged out
        if !firstLoad {
            checkForExistingLogin()
            
            navigationController?.setNavigationBarHidden(true, animated: false)
        }
        
        firstLoad = false
    }
    
    
    // MARK: - Checking existing login using stored token
    
    func checkForExistingLogin() {
        
        // Try to fetch a previously saved auth token from keychain
        if useTouchID {
            // Try get the protected value with Touch ID / device password authentication required to access it
            DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                do {
                    guard let authToken = try self.keychain.authenticationPrompt("Authenticate to login to your account").get(kLoginKey) else {
                        self.authenticationErrorOccurred(errorMessage: "Not authenticated - No protected token exists")
                        return
                    }
                    print("Retrieved protected auth token from Keychain: \(authToken)")
                    self.getUserDetails(withToken: authToken)
                } catch {
                    self.authenticationErrorOccurred(errorMessage: "Not authenticated - No protected token exists")
                }
            }
        } else {
            // Just get the value regularly in the keychain
            do {
                guard let authToken = try keychain.getString(kLoginKey) else {
                    self.authenticationErrorOccurred(errorMessage: "Not authenticated - No non-protected token exists")
                    return
                }
                print("Retrieved non-protected auth token from Keychain: \(authToken)")
                getUserDetails(withToken: authToken)
            } catch {
                self.authenticationErrorOccurred(errorMessage: "Not authenticated - No non-protected token exists")
            }
        }
        
    }
    
    func getUserDetails(withToken authString: String) {
        
        // Form URLRequest
        guard let url = URL(string: "\(webserviceURL)/api/v1/me") else {return}
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = NSURLRequest.CachePolicy.reloadIgnoringCacheData
        
        // Add required parameters and set header value
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(authString, forHTTPHeaderField: "Authorization") // use encodedAuthString instead of authString if we just have API key and API secret
        
        displayActivityIndicator()
        
        let getUserDetailsTask = URLSession.shared.dataTask(with: request) { (data, response, error) in
            
            self.removeActivityIndicator()
            
            // Make sure we did not get an error
            if let error = error {
                self.authenticationErrorOccurred(errorMessage: error.localizedDescription)
                return
            }
            
            // Make sure we got an HTTP Response
            guard let httpResponse = response as? HTTPURLResponse else {
                // No decodable response
                self.authenticationErrorOccurred()
                return
            }
            
            // Make sure we got data back
            guard let data = data else {
                // No data to decode
                self.authenticationErrorOccurred()
                return
            }
            
            // Make sure the HTTP response is 200
            guard httpResponse.statusCode == 200 else {
                do {
                    // Convert the response to a dictionary
                    guard let errorDict = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] else {
                        self.authenticationErrorOccurred()
                        return
                    }
                    
                    print("*** Error - HTTP Response code = \(httpResponse.statusCode) ***\n\(errorDict)")
                    
                    // Parsed erroneous response into a dictionary - check for specific error messages
                    guard let error = errorDict["error"] as? Bool, error == true, let errorMessage = errorDict["message"] as? String else {
                        self.authenticationErrorOccurred()
                        return
                    }
                    
                    self.authenticationErrorOccurred(errorMessage: errorMessage)
                    
                } catch {
                    // Couldn't convert the response to a dictionary - display generic error
                    self.authenticationErrorOccurred()
                }
                return
            }
            
            // We did not recieve an error, have an HTTP Response, recieved data back and have a 200 response code
            do {
                // Convert into dictionary
                guard let userDetails = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] else {
                    self.authenticationErrorOccurred()
                    return
                }
                
                print(userDetails)
                
                // Convert to User model
                self.authenticatedUser = try User(dictionary: userDetails as [String:AnyObject])
                
                // User is authenticated - Segue to the home screen
                DispatchQueue.main.async {
                    self.performSegue(withIdentifier: "authenticated", sender: self)
                }
                
                
            } catch {
                // Couldn't convert the response to a dictionary, or the dictionary to a model - display generic error
                self.authenticationErrorOccurred()
                return
            }
        }
        
        getUserDetailsTask.resume()
    }
    
    
    // MARK: - Utility functions
    
    func displayActivityIndicator() {
        // TODO: Some UI Effect while we load their user details
    }
    
    func removeActivityIndicator() {
        // TODO: Remove/Stop UI effect
    }
    
    func authenticationErrorOccurred(errorMessage: String? = nil) {
        // For logging purposes, just print out the error since this is the result of our generated actions (no user action can effect this)
        print("Error authenticating user with stored authentication token with error message: \(errorMessage)")
        
        // Segue to login screen
        DispatchQueue.main.async {
            self.performSegue(withIdentifier: "showLogin", sender: self)
        }
    }
    
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "authenticated" {
            guard let homeVC = segue.destination as? HomeViewController else {return}
            homeVC.currentUser = authenticatedUser
        }
    }

}
