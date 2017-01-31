//
//  CustomLoginViewController.swift
//  ReSpy
//
//  Created by Kyle Blazier on 1/15/16.
//  Copyright © 2016 Kyle Blazier. All rights reserved.
//

import UIKit
import Security
import KeychainAccess

enum validateOption {
    case username
    case password
    case email
}

class LoginViewController: UIViewController, UITextFieldDelegate {
    
    @IBOutlet var logoImageView: UIImageView!
    @IBOutlet var usernameTextField: UITextField!
    @IBOutlet var passwordTextField: UITextField!
    @IBOutlet var toggleLoginSignupButton: UIButton!
    @IBOutlet var goButton: UIButton!
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    
    var signupActive = false
    var pointsPushedUp : CGFloat = 0
    
    var userEmail: String?
    
    let keychain = Keychain(service: "com.KyleBlazier.AuthenticationApp")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.setNavigationBarHidden(true, animated: false)
        
        // Setup textfield delegates
        usernameTextField.delegate = self
        passwordTextField.delegate = self
        
        // Setup UI of textfields
//        usernameTextField.layer.cornerRadius = 15
//        passwordTextField.layer.cornerRadius = 15
        
        
        // Add keyboard observers
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: .UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: .UIKeyboardWillHide, object: nil)
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapRecognized))
        self.view.addGestureRecognizer(tapRecognizer)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        if activityIndicator.isAnimating {
            removeActivityIndicator()
        }
    }
    
    
    // MARK: - UITapGestureRecognizer function
    
    func tapRecognized() {
        if usernameTextField.isEditing {
            // If the username is being edited, resign the keyboard
            usernameTextField.resignFirstResponder()
        } else if passwordTextField.isEditing {
            // If the password is being edited, resign the keyboard
            passwordTextField.resignFirstResponder()
        }
    }
    
    
    // MARK: - UIKeyboard Notification Observer functions
    
    func keyboardWillShow(notification: NSNotification) {
        // Move the textfield 50 points above the keyboard
        guard let info = notification.userInfo else {return}
        
        guard let keyboardFrame : CGRect = (info[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else {return}
        
        if pointsPushedUp == 0 {
            let amountHidden = goButton.frame.maxY - keyboardFrame.minY
            // If the go button is hidden, push up the view
            if amountHidden >= 0 {
                pointsPushedUp = amountHidden
                UIView.animate(withDuration: 0.1) { () -> Void in
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
                self.view.frame = CGRect(x: 0, y: self.view.frame.minY + (self.pointsPushedUp), width: self.view.bounds.width, height: self.view.bounds.height)
                self.pointsPushedUp = 0
            })
        }
    }
    
    
    // MARK: - UITextFieldDelegate Functions
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField.tag == 0 {
            passwordTextField.becomeFirstResponder()
        } else {
            passwordTextField.resignFirstResponder()
            processLogin()
        }
        return true
    }
    
    func validateText(option : validateOption) -> String? {
        if option == validateOption.username {
            // Validate username
            guard let username = usernameTextField.text else {return nil}
            guard username.characters.count >= 3 else {return nil}
            return username
        } else if option == validateOption.password {
            // Validate password
            guard let password = passwordTextField.text else {return nil}
            guard password.characters.count > 5 else {return nil}
            
            if containsSpecialChars(testString: password) {
                return password
            } else {
                return nil
            }
        } else {
            return nil
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
    
    func processLogin() {
        if !signupActive {
            // Login - validate text
            if let username = validateText(option: validateOption.username) {
                if let password = validateText(option: validateOption.password) {
                    // Username and password validated - try to log the user in
                    loginWithUsername(username: username, password: password)
                } else {
                    presentAlert(alertTitle: "Password Error", alertMessage: "There was an error with your entered password. Passwords must be at least 6 characters and contain only letters and numbers.")
                }
            }  else {
                presentAlert(alertTitle: "Username Error", alertMessage: "There was an error with your entered username. Usernames must be at least 4 characters and contain only letters and numbers.")
            }
        }
    }
    
    func loginWithUsername(username : String, password : String) {
        displayActivityIndicator()
        
        // Form URLRequest
        guard let url = URL(string: "\(webserviceURL)/api/v1/login") else {return}
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.cachePolicy = NSURLRequest.CachePolicy.reloadIgnoringCacheData
        
        // Add required parameters and set header value
        let paramsDict = ["username": username, "password": password]
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
                    print("Couldnt get the user after successfully logging in")
                    self.presentGenericError()
                    return
                }
                
                guard let apiKey = user["api_key"] as? String, let apiSecret = user["api_secret"] as? String else {
                    print("Couldnt get the auth values after successfully logging in")
                    self.presentGenericError()
                    return
                }
                
                let authString = "\(apiKey):\(apiSecret)"
                
                guard let authData = authString.data(using: .utf8) else {
                    print("Couldnt convert auth string to data after successfully logging in")
                    self.presentGenericError()
                    return
                }
                
                let encodedAuthString = "Basic \(authData.base64EncodedString())"
                
                do {
                    try self.keychain.set(encodedAuthString, key: kLoginKey)
                    print("Auth token saved to keychain")
                } catch let error {
                    print("Couldn't save to Keychain: \(error.localizedDescription)")
                }
                
                // Success - dismiss view controller
                self.dismissLoginVC()
                
            } catch {
                self.presentGenericError()
            }
        }
        
        task.resume()

    }
    
    
    // MARK: - Button actions
    
    @IBAction func goButtonPressed(_ sender: Any) {
        processLogin()
    }

    @IBAction func toggleLoginSignupButtonPressed(_ sender: Any) {
        self.performSegue(withIdentifier: "showSignup", sender: self)
    }
    
    
    @IBAction func resetPasswordButtonPressed(_ sender: Any) {
        
        presentAlert(alertTitle: "Password Reset", alertMessage: "Are you sure you want to reset your password?", cancelButtonTitle: "Cancel", cancelButtonAction: nil, okButtonTitle: "Reset", okButtonAction: {
            // Reset password
            let getPasswordAlert = UIAlertController(title: "Reset Password", message: "Enter the email associated with your account to reset your password.", preferredStyle: UIAlertControllerStyle.alert)
            getPasswordAlert.addTextField(configurationHandler: { (textField) -> Void in
                textField.placeholder = "Email Address"
                textField.autocorrectionType = UITextAutocorrectionType.no
                textField.autocapitalizationType = UITextAutocapitalizationType.none
                textField.tag = -1
            })
            getPasswordAlert.addAction(UIAlertAction(title: "Reset", style: UIAlertActionStyle.destructive, handler: { (action) -> Void in
                // Try to retrieve email
                guard let text = getPasswordAlert.textFields?.first?.text else {return}
                // If there was an account name entered
                if text != "" {
                    // TODO: Send password reset email
                    print("TODO: Send password reset email")
                }
            }))
            getPasswordAlert.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: nil))
            self.present(getPasswordAlert, animated: true, completion: nil)
            
        })
    }
    
    func presentGenericError() {
        self.presentAlert(alertTitle: "Error", alertMessage: "We encountered an error while trying to serve your request, please try again.")
    }
    
    
    // MARK: - Utility Functions
    
    func dismissLoginVC() {
        DispatchQueue.main.async {
            let _ = self.navigationController?.popToRootViewController(animated: true)
        }
    }
    
    func displayActivityIndicator() {
        activityIndicator.center = self.view.center
        activityIndicator.hidesWhenStopped = true
        activityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.whiteLarge
        activityIndicator.startAnimating()
        UIApplication.shared.beginIgnoringInteractionEvents()
    }
    
    func removeActivityIndicator() {
        activityIndicator.stopAnimating()
        UIApplication.shared.endIgnoringInteractionEvents()
    }

}