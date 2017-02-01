//
//  FormTableViewCell.swift
//  AuthenticationApp
//
//  Created by Kyle Blazier on 1/31/17.
//  Copyright © 2017 Kyle Blazier. All rights reserved.
//

import UIKit

class FormTableViewCell: UITableViewCell {

    @IBOutlet var label: UILabel!
    @IBOutlet var textField: UITextField!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
