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
        
        displayActivityIndicator()
        
        ServiceManager.sharedInstance.getUserDetails(authToken: authString, successBlock: { (currentUser) in
            
            self.removeActivityIndicator()
            
            guard let currentUser = currentUser else {
                self.authenticationErrorOccurred(errorMessage: nil)
                return
            }
            self.authenticatedUser = currentUser
            
            // User is authenticated - Segue to the home screen
            DispatchQueue.main.async {
                self.performSegue(withIdentifier: "authenticated", sender: self)
            }

        }) { (errorMessage) in
            
            self.removeActivityIndicator()
            
            self.authenticationErrorOccurred(errorMessage: errorMessage)
        }
        
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
