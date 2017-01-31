//
//  HomeViewController.swift
//  AuthenticationApp
//
//  Created by Kyle Blazier on 1/31/17.
//  Copyright © 2017 Kyle Blazier. All rights reserved.
//

import UIKit
import KeychainAccess

class HomeViewController: UIViewController {
    
    @IBOutlet var displayLabel: UILabel!
    @IBOutlet var logoImageView: UIImageView!
    
    var currentUser: User?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Show nav bar
        navigationController?.setNavigationBarHidden(false, animated: false)
        
        // Remove back button & add logout button
        navigationController?.navigationItem.setHidesBackButton(true, animated: false)

        let logoutButton = UIBarButtonItem(title: "Logout", style: .plain, target: self, action: #selector(logoutButtonPressed))
        navigationController?.navigationItem.setRightBarButton(logoutButton, animated: false)
        
        
        // Update text field with user's info
        guard let currentUser = currentUser else {return}
        guard let currentText = displayLabel.text else {
            displayLabel.text = currentUser.getUserDetailsString()
            return
        }
        displayLabel.text = "\(currentText)\n\nCurrent User: \(currentUser.getUserDetailsString())"

    }
    
    @IBAction func logoutButtonPressed(_ sender: Any) {
        
        presentAlert(alertTitle: "Logout?", alertMessage: "Are you sure you'd like to logout?", cancelButtonTitle: "Cancel", cancelButtonAction: nil, okButtonTitle: "Logout", okButtonAction: { 
            
            // Remove keychain value and show login screen
            let keychain = Keychain(service: "com.KyleBlazier.AuthenticationApp")
            do {
                try keychain.remove(kLoginKey)
            } catch {
                print("error removing keychain value")
            }
            
            DispatchQueue.main.async {
                let _ = self.navigationController?.popToRootViewController(animated: true)
            }
        })
        
    }
    
}
