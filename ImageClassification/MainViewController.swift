//
//  MainViewController.swift
//  BananaDetector
//
//  Created by Ying Nam Lee on 19/4/2023.
//  Copyright © 2023 Y Media Labs. All rights reserved.
//

import UIKit

class MainViewController: UIViewController {

    @IBOutlet weak var yellowView: UITextView!
    @IBOutlet weak var bkgrd: UIImageView!
    override func viewDidLoad() {
        super.viewDidLoad()
        yellowView.layer.cornerRadius = 10
        // Do any additional setup after loading the view.
    }
    
    
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
