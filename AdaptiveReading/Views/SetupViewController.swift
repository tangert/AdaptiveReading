//
//  SetupViewController.swift
//  AdaptiveReading
//
//  Created by Tyler Angert on 12/3/18.
//  Copyright © 2018 Tyler Angert. All rights reserved.
//

import Foundation
import UIKit

class SetupViewController: UIViewController {
    
    @IBOutlet weak var textTypeSelector: UISegmentedControl!
    @IBOutlet weak var highlightedSelector: UISegmentedControl!
    @IBOutlet weak var participantIDField: UITextField!
    @IBOutlet weak var testTypeSelector: UISegmentedControl!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.destination is TestViewController  {
            let vc = segue.destination as? TestViewController
            vc?.participantID = participantIDField.text
            vc?.highlighted = highlightedSelector.selectedSegmentIndex == 0 ? true : false
            vc?.testType = testTypeSelector.selectedSegmentIndex == 0 ? "Pre" : "Post"
            vc?.textType = textTypeSelector.selectedSegmentIndex == 0 ? "A" : "B"
        }
    }
}
