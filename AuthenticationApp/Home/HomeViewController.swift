//
//  HomeViewController.swift
//  AuthenticationApp
//
//  Created by Kyle Blazier on 1/31/17.
//  Copyright © 2017 Kyle Blazier. All rights reserved.
//

import UIKit
import KeychainAccess
import LocalAuthentication

class HomeViewController: UIViewController {
    
    @IBOutlet var logoImageView: UIImageView!
    @IBOutlet var userDetailsTableView: UITableView!
    
    var currentUser: User?
    
    var changedValues = [String:String]()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Show nav bar
        navigationController?.setNavigationBarHidden(false, animated: false)
        
        // Remove back button & add logout button
        navigationController?.navigationItem.setHidesBackButton(true, animated: false)

        let logoutButton = UIBarButtonItem(title: "Logout", style: .plain, target: self, action: #selector(logoutButtonPressed))
        navigationController?.navigationItem.setRightBarButton(logoutButton, animated: false)
        
        userDetailsTableView.dataSource = self

    }
    
    override func viewWillAppear(_ animated: Bool) {
         NotificationCenter.default.addObserver(self, selector: #selector(textFieldTextDidChange(notif:)), name: .UITextFieldTextDidChange, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
         NotificationCenter.default.removeObserver(self, name: .UITextFieldTextDidChange, object: nil)
    }
    
    func textFieldTextDidChange(notif: NSNotification) {
        
        guard let sender = notif.object as? UITextField else {return}
        
        guard let changedText = sender.text, changedText != "" else {return}
        
        switch sender.tag {
        case 2:
            // Email
            changedValues["email"] = changedText
        case 3:
            // Name
            changedValues["name"] = changedText
        default:
            return
        }
        
    }
    
    func presentGenericError() {
        self.presentAlert(alertTitle: "Error", alertMessage: "We encountered an error while trying to serve your request, please try again.")
    }
    
    @IBAction func logoutButtonPressed(_ sender: Any) {
        
        presentAlert(alertTitle: "Logout?", alertMessage: "Are you sure you'd like to logout?", cancelButtonTitle: "Cancel", cancelButtonAction: nil, okButtonTitle: "Logout", okButtonAction: { 
            
            // Remove keychain value and show login screen
            let keychain = Keychain(service: keyChainServiceName)
            do {
                try keychain.remove(kLoginKey)
            } catch {
                print("error removing keychain value")
            }
            
            // Service call to logout of session on server
            // Fetch authentication token from User model
            guard let authToken = self.currentUser?.authToken else {
                print("Don't have an auth token for this user")
                self.presentGenericError()
                return
            }
            
            ServiceManager.sharedInstance.logout(authToken: authToken)
            
            DispatchQueue.main.async {
                let _ = self.navigationController?.popToRootViewController(animated: true)
            }
        })
        
    }
    
    @IBAction func doneButtonPressed(_ sender: Any) {
        
        view.endEditing(true)
        
        if changedValues.count > 0 {
        
            presentAlert(alertTitle: "Save Changes?", alertMessage: "Would you like to save your changes?", cancelButtonTitle: "Cancel", cancelButtonAction: nil, okButtonTitle: "Save", okButtonAction: {
                
                // Step-up authentication using Touch ID to verify the user
                /* 
                   ** NOTE ** In a Production app you would have a fallback here for users
                    who do not have Touch ID compatible devices or have Touch ID setup.
                    Since this is an app to demonstrate secure practices, like step-up authentication,
                    we will not create a fallback way of re-verifying the user.
                */
                let authenticationContext = LAContext()
                
                // Make sure the device is Touch ID compatible
                guard authenticationContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
                    self.presentAlert(alertTitle: "Incompatible Device", alertMessage: "We are unable to use Touch ID to verify your identity.")
                    return
                }
                
                // Ask for Touch ID validation
                authenticationContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Re-Authenticate to update your user details.", reply: { (success, error) in
                    // Check if there were any errors
                    if let error = error {
                        print(error.localizedDescription)
                        self.presentAlert(alertTitle: "Authentication Error", alertMessage: "Failure re-authenticating with Touch ID. Your user details will not be updated.")
                        return
                    } else if success {
                        // Success - update user info
                        self.updateUserInfo()
                    }
                    
                })
                
            })
            
        } else {
            presentAlert(alertTitle: "No Changes", alertMessage: "You haven't made any changes to your user details that need to be saved!")
        }
        
    }
    
    func updateUserInfo() {
        
        // Fetch authentication token from User model
        guard let authToken = currentUser?.authToken else {
            ServiceManager.sharedInstance.logMessage(message: "Don't have an auth token for this user")
            self.presentGenericError()
            return
        }
        
        ServiceManager.sharedInstance.updateUserDetails(valuesToUpdate: changedValues, authToken: authToken, successBlock: { (currentUser) in
            
            guard let currentUser = currentUser else {
                self.presentGenericError()
                return
            }
            
            // Update current user with the newly modified user
            self.currentUser = currentUser
            
            // Remove all changed values
            self.changedValues.removeAll()
            
            // Success - present alert
            self.presentAlert(alertTitle: "Success!", alertMessage: "Your user details have been updated!")
            
        }) { (errorMessage) in
            
            guard let errorMessage = errorMessage else {
                self.presentGenericError()
                return
            }
            
            self.presentAlert(alertTitle: "Error", alertMessage: errorMessage)
            
        }
        
    }
    
}

extension HomeViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 4
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard let currentUser = currentUser else {return UITableViewCell()}
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "formCell") as? FormTableViewCell else {return UITableViewCell()}
        
        switch indexPath.row {
        case 0:
            cell.label.text = "ID"
            cell.textField.text = "\(currentUser.id)"
            cell.textField.isEnabled = false
        case 1:
            cell.label.text = "Username"
            cell.textField.text = currentUser.username
            cell.textField.isEnabled = false
        case 2:
            cell.label.text = "Email"
            cell.textField.text = currentUser.email
            cell.textField.isEnabled = true
        case 3:
            cell.label.text = "Name"
            cell.textField.text = currentUser.name
            cell.textField.isEnabled = true
        default:
            return UITableViewCell()
        }
        
        cell.textField.tag = indexPath.row
        cell.textField.delegate = self
        cell.selectionStyle = .none
        
        return cell
        
    }
    
}

extension HomeViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return true
    }
}
