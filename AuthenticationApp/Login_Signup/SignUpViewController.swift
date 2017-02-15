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
            guard let password = passwordTextField.text, password.characters.count > 5, validatePassword(passwordString: password) else {return nil}
            return password
        case validateOption.email:
            // Validate email
            guard let email = emailTextField.text, validateEmail(emailString: email) else {return nil}
            return email
        case validateOption.username:
            // Validate username
            guard let username = usernameTextField.text, username.characters.count > 3, validateUsername(usernameString: username) else {return nil}
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
    
    func validateEmail(emailString: String) -> Bool {
        let test = NSPredicate(format: "SELF MATCHES %@", "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,4}")
        return test.evaluate(with: emailString)
    }
    
    func signupWithEmail(username: String, password : String, email : String) {
        
        displayActivityIndicator()
        
        ServiceManager.sharedInstance.register(registrationDict: ["username": username, "password": password, "email": email], successBlock: { (currentUser) in
            
            self.removeActivityIndicator()
            
            guard let currentUser = currentUser else {
                self.presentGenericError()
                return
            }
            
            self.authenticatedUser = currentUser
            
            // Success - present alert
            self.presentAlert(alertTitle: "Success!", alertMessage: "Your account with the username '\(username)' has been registered!", cancelButtonTitle: "Let's Get Started!", cancelButtonAction: {
                DispatchQueue.main.async {
                    self.dismissSignupVC()
                }
            })
            
        }) { (errorMessage) in
            
            self.removeActivityIndicator()
            
            guard let errorMessage = errorMessage else {
                self.presentGenericError()
                return
            }
            
            self.presentAlert(alertTitle: "Error", alertMessage: errorMessage)
        }
        
    }
    
    func presentGenericError() {
        self.presentAlert(alertTitle: "Error", alertMessage: "We encountered an error while trying to serve your request, please try again.")
    }
    
    func processSignup() {
        
        // Signup - validate text
        guard let username = validateText(option: .username) else {
            presentAlert(alertTitle: "Username Error", alertMessage: "Usernames must be at least 4 characters and contain at least 1 of each: uppercase letter, lowercase letter and number.")
            return
        }
        
        guard let email = validateText(option: .email) else {
            presentAlert(alertTitle: "Email Error", alertMessage: "You have entered an invalid email. Please try again.")
            return
        }
        
        guard let password = validateText(option: .password) else {
            presentAlert(alertTitle: "Password Error", alertMessage: "Passwords must be at least 6 characters and contain at least 1 of each: uppercase letter, lowercase letter, number and special character.")
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
