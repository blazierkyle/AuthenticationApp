//
//  UIViewController+Extensions.swift
//  AuthenticationApp
//
//  Created by Kyle Blazier on 1/31/17.
//  Copyright © 2017 Kyle Blazier. All rights reserved.
//

import Foundation
import UIKit

extension UIViewController {
    
    func delay(delay : Double, closure: @escaping () -> ()) {
        let when = DispatchTime.now() + delay
        DispatchQueue.main.asyncAfter(deadline: when) {
            closure()
        }
    }
    
    // MARK: - Utility function to present actionable alerts and popups
    func presentAlert(alertTitle : String?, alertMessage : String, cancelButtonTitle : String = "OK", cancelButtonAction : (()->())? = nil, okButtonTitle : String? = nil, okButtonAction : (()->())? = nil, thirdButtonTitle : String? = nil, thirdButtonAction : (()->())? = nil) {
        let alert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: UIAlertControllerStyle.alert)
        if let okAction = okButtonTitle {
            alert.addAction(UIAlertAction(title: okAction, style: .default, handler: { (action) in
                okButtonAction?()
            }))
            
            if let thirdButton = thirdButtonTitle {
                alert.addAction(UIAlertAction(title: thirdButton, style: .default, handler: { (action) in
                    thirdButtonAction?()
                }))
            }
        }
        alert.addAction(UIAlertAction(title: cancelButtonTitle, style: UIAlertActionStyle.cancel, handler: { (action) in
            cancelButtonAction?()
        }))
        
        DispatchQueue.main.async {
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func showPopup(message : String) {
        let popup = UIAlertController(title: nil, message: message, preferredStyle: UIAlertControllerStyle.actionSheet)
        self.present(popup, animated: true, completion: {
            
        })
        self.perform(#selector(hidePopup), with: nil, afterDelay: 1.0)
    }
    
    func hidePopup() {
        self.dismiss(animated: true, completion: {
            
        })
    }
    
}
