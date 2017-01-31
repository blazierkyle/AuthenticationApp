//
//  CustomSignUpViewController.swift
//  ReSpy
//
//  Created by Kyle Blazier on 1/16/16.
//  Copyright © 2016 Kyle Blazier. All rights reserved.
//

import UIKit
import KeychainAccess

class SignUpViewController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet var logoImageView: UIImageView!
    @IBOutlet var usernameTextField: UITextField!
    @IBOutlet var emailTextField: UITextField!
    @IBOutlet var passwordTextField: UITextField!
    @IBOutlet var confirmPasswordTextField: UITextField!
    @IBOutlet var createAccountButton: UIButton!
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    
    var signupActive = false
    var pointsPushedUp : CGFloat = 0
    
    var userEmail: String?
    
    let keychain = Keychain(service: keyChainServiceName)
    
    var authenticatedUser: User?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup navigation bar
        navigationController?.setNavigationBarHidden(true, animated: false)
        
        activityIndicator.hidesWhenStopped = true

        // Setup textfield delegates
        usernameTextField.delegate = self
        emailTextField.delegate = self
        passwordTextField.delegate = self
        confirmPasswordTextField.delegate = self
        
        // Setup UI of textfields
//        usernameTextField.layer.cornerRadius = 15
//        emailTextField.layer.cornerRadius = 15
//        passwordTextField.layer.cornerRadius = 15
//        confirmPasswordTextField.layer.cornerRadius = 15
        
        // Add keyboard observers
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: .UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: .UIKeyboardWillHide, object: nil)
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapRecognized))
        self.view.addGestureRecognizer(tapRecognizer)

    }
    
    
    // MARK: - UITapGestureRecognizer function
    
    func tapRecognized() {
        // If one of the text fields are being edited, resign the keyboard
        view.endEditing(true)
    }
    
    // MARK: - UIKeyboard Notification Observer functions
    
    func keyboardWillShow(notification: Notification) {
        // Move the hint 50 points above the keyboard
        var info = notification.userInfo!
        let keyboardFrame : CGRect = (info[UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        if pointsPushedUp == 0 {
            let amountHidden = createAccountButton.frame.maxY - keyboardFrame.minY
            // If the go button is hidden, push up the view
            if amountHidden >= 0 {
                pointsPushedUp = amountHidden
                UIView.animate(withDuration: 0.1) { () -> Void in
                    //self.hint.frame = CGRectMake(0, keyboardFrame.origin.y - 50, UIScreen.mainScreen().bounds.width, 30)
                    self.view.frame = CGRect(x: 0, y: self.view.frame.minY - amountHidden, width: self.view.bounds.width, height: self.view.bounds.height)
                }
            }
        }
    }
    
    func keyboardWillHide(notification: NSNotification) {
        // If there is a saved location of the hint before it was moved,
        //  reset it's y value to that value
        if pointsPushedUp != 0 {
            UIView.animate(withDuration: 0.1, animations: { () -> Void in
                //self.hint.frame = CGRectMake(0, self.hintYBeforeKeyboardShow, self.hint.bounds.width, self.hint.bounds.height)
                self.view.frame = CGRect(x:0, y:self.view.frame.minY + (self.pointsPushedUp), width: self.view.bounds.width, height: self.view.bounds.height)
                self.pointsPushedUp = 0
            })
        }
    }
        
    // MARK: - UITextFieldDelegate Functions
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField.tag {
        case 0:
            emailTextField.becomeFirstResponder()
        case 1:
            passwordTextField.becomeFirstResponder()
        case 2:
            confirmPasswordTextField.becomeFirstResponder()
        case 3:
            confirmPasswordTextField.resignFirstResponder()
            processSignup()
        default:
            return true
        }
        return true
    }
    
    func validateText(option : validateOption) -> String? {
        switch option {
        case validateOption.password:
            // Validate password
            guard let password = passwordTextField.text else {return nil}
            guard password.characters.count > 5 else {return nil}
            
            if containsSpecialChars(testString: password) {
                return password
            } else {
                return nil
            }
        case validateOption.email:
            // Validate email
            guard let email = emailTextField.text else {return nil}
            guard email.characters.count > 4 else {return nil}
            return email
        case validateOption.username:
            guard let username = usernameTextField.text else {return nil}
            guard username.characters.count >= 3 else {return nil}
            return username
        }
    }
    
    func containsSpecialChars(testString : String) -> Bool {
        do {
            let regex = try NSRegularExpression(pattern: ".*[^a-z0-9].*", options: .caseInsensitive)
            if regex.firstMatch(in: testString, options: .anchored, range: NSMakeRange(0, testString.characters.count)) != nil {
                return false
            }
            return true
        } catch {
            return false
        }
    }
    
    func signupWithEmail(username: String, password : String, email : String) {
        
        displayActivityIndicator()
        
        // Form URLRequest
        guard let url = URL(string: "\(webserviceURL)/api/v1/register") else {return}
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.cachePolicy = NSURLRequest.CachePolicy.reloadIgnoringCacheData
        
        // Add required parameters and set header value
        let paramsDict = ["username": username, "password": password, "email": email]
        let dictData = try? JSONSerialization.data(withJSONObject: paramsDict)
        request.httpBody = dictData
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            
            DispatchQueue.main.async {
                self.removeActivityIndicator()
            }
            
            if let error = error {
                self.presentAlert(alertTitle: "Error", alertMessage: error.localizedDescription)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                // No decodable response
                self.presentGenericError()
                return
            }
            
            guard let data = data else {
                // No data to decode
                self.presentGenericError()
                return
            }
            
            guard httpResponse.statusCode == 200 else {
                do {
                    guard let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] else {
                        self.presentGenericError()
                        return
                    }
                    
                    // Parsed erroneous response into a dictionary - check for errors
                    guard let error = json["error"] as? Bool else {
                        self.presentGenericError()
                        return
                    }
                    guard error else {
                        self.presentGenericError()
                        return
                    }
                    guard let errorMessage = json["message"] as? String else {
                        self.presentGenericError()
                        return
                    }
                    self.presentAlert(alertTitle: "Error", alertMessage: errorMessage)
                    
                } catch {
                    self.presentGenericError()
                }
                return
            }
            
            do {
                guard let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] else {
                    self.presentGenericError()
                    return
                }
                
                // Check for errors
                if let error = json["error"] {
                    self.presentAlert(alertTitle: "Error", alertMessage: "\(error)")
                    return
                }
                
                guard let success = json["success"] as? Bool, success == true else {
                    self.presentGenericError()
                    return
                }
                
                // Format & store authentication token in keychain
                guard let user = json["user"] as? [String:Any] else {
                    self.presentGenericError()
                    print("Couldnt get the user")
                    return
                }
                
                // Convert to User model
                self.authenticatedUser = try User(dictionary: user as [String:AnyObject])
                
                guard let apiKey = user["api_key"] as? String, let apiSecret = user["api_secret"] as? String else {
                    print("Couldnt get the auth values")
                    self.presentGenericError()
                    return
                }
                
                let authString = "\(apiKey):\(apiSecret)"
                
                guard let authData = authString.data(using: .utf8) else {
                    print("Couldnt convert auth string to data")
                    self.presentGenericError()
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
                            print("Auth token saved to keychain for use with Touch ID / password")
                        } catch {
                            print("Could not setup the app to use Touch ID with this keychain value - fallback to standard authentication")
                            // Just store the value regularly in th keychain
                            do {
                                try self.keychain.set(encodedAuthString, key: kLoginKey)
                                print("Auth token saved to keychain")
                            } catch let error {
                                print("Couldn't save to Keychain: \(error.localizedDescription)")
                            }
                        }
                    }
                } else {
                    // Just store the value regularly in th keychain
                    do {
                        try self.keychain.set(encodedAuthString, key: kLoginKey)
                        print("Auth token saved to keychain")
                    } catch let error {
                        print("Couldn't save to Keychain: \(error.localizedDescription)")
                    }
                }
                
                // Success - present alert
                self.presentAlert(alertTitle: "Success!", alertMessage: "Your account with the username '\(username)' has been registered!", cancelButtonTitle: "Let's Get Started!", cancelButtonAction: {
                    self.dismissSignupVC()
                })
                
            } catch {
                self.presentGenericError()
            }
        }
        
        task.resume()
        
    }
    
    func presentGenericError() {
        self.presentAlert(alertTitle: "Error", alertMessage: "We encountered an error while trying to serve your request, please try again.")
    }
    
    func processSignup() {
        // Signup - validate text
        
        guard let username = validateText(option: .username) else {
            presentAlert(alertTitle: "Username Error", alertMessage: "You have entered an invalid username. Please try again.")
            return
        }
        
        guard let email = validateText(option: .email) else {
            presentAlert(alertTitle: "Email Error", alertMessage: "You have entered an invalid email. Please try again.")
            return
        }
        
        guard let password = validateText(option: .password) else {
            presentAlert(alertTitle: "Password Error", alertMessage: "There was an error with your entered password. Passwords must be at least 6 characters and contain only letters and numbers.")
            return
        }
        
        guard let confirmPassword = confirmPasswordTextField.text, password == confirmPassword else {
            presentAlert(alertTitle: "Password Error", alertMessage: "Your passwords do not match. Please try again")
            return
        }
        
        signupWithEmail(username: username, password: password, email: email)
       
    }
    
    // MARK: - Utility Functions
    
    func displayActivityIndicator() {
        activityIndicator.startAnimating()
        UIApplication.shared.beginIgnoringInteractionEvents()
    }
    
    func removeActivityIndicator() {
        activityIndicator.stopAnimating()
        UIApplication.shared.endIgnoringInteractionEvents()
    }

    
    func dismissSignupVC() {
        DispatchQueue.main.async {
            self.performSegue(withIdentifier: "successfulSignup", sender: self)
        }
    }

    // MARK: - IBAction Functions
    
    @IBAction func createAccountButtonPressed(_ sender: Any) {
        processSignup()
    }
    
    @IBAction func toggleLoginSignupButton(_ sender: Any) {
        let _ = self.navigationController?.popViewController(animated: true)
    }
    
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "successfulSignup" {
            guard let homeVC = segue.destination as? HomeViewController else {return}
            homeVC.currentUser = authenticatedUser
        }
    }
}
