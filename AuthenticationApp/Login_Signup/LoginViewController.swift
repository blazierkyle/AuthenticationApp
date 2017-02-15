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
    
    let keychain = Keychain(service: keyChainServiceName)
    
    var authenticatedUser: User?
    
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
            guard let username = usernameTextField.text, username.characters.count > 3, validateUsername(usernameString: username) else {return nil}
            return username
        } else if option == validateOption.password {
            // Validate password
            guard let password = passwordTextField.text, password.characters.count > 5, validatePassword(passwordString: password) else {return nil}
            return password
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
    
    func validateUsername(usernameString: String) -> Bool {
        // 4 characters. One uppercase. One Lowercase. One number.
        let test = NSPredicate(format: "SELF MATCHES %@", "^(?=.*?[A-Z])(?=.*?[0-9])(?=.*?[a-z]).{4,}$")
        return test.evaluate(with: usernameString)
    }
    
    func validatePassword(passwordString: String) -> Bool {
        // 6 characters. One uppercase. One Lowercase. One number. One Special.
        let test = NSPredicate(format: "SELF MATCHES %@", "^(?=.*?[A-Z])(?=.*?[0-9])(?=.*?[a-z])(?=.*?[-_\\.:;!@#\\$%\\^&\\*\\?<>]).{6,}$")
        return test.evaluate(with: passwordString)
    }
    
    func processLogin() {
        if !signupActive {
            // Login - validate text
            guard let username = validateText(option: validateOption.username) else {
                presentAlert(alertTitle: "Username Error", alertMessage: "Usernames must be at least 4 characters and contain at least 1 of each: uppercase letter, lowercase letter and number.")
                return
            }
            guard let password = validateText(option: validateOption.password) else {
                presentAlert(alertTitle: "Password Error", alertMessage: "Passwords must be at least 6 characters and contain at least 1 of each: uppercase letter, lowercase letter, number and special character.")
                return
            }
            // Username and password validated - try to log the user in
            loginWithUsername(username: username, password: password)
        }
    }
    
    func loginWithUsername(username : String, password : String) {
        
        displayActivityIndicator()
        
        ServiceManager.sharedInstance.login(registrationDict: ["username": username, "password": password], successBlock: { (currentUser) in
            
            self.removeActivityIndicator()
            
            guard let currentUser = currentUser else {
                self.presentGenericError()
                return
            }
            
            self.authenticatedUser = currentUser
            
            self.dismissLoginVC()
            
        }) { (errorMessage) in
            
            self.removeActivityIndicator()
            
            guard let errorMessage = errorMessage else {
                self.presentGenericError()
                return
            }
            
            self.presentAlert(alertTitle: "Error", alertMessage: errorMessage)
        }
        
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
            self.performSegue(withIdentifier: "successfulLogin", sender: self)
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
    
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "successfulLogin" {
            guard let homeVC = segue.destination as? HomeViewController else {return}
            homeVC.currentUser = authenticatedUser
        }
    }

}
