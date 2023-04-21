//  Banana Detector
//
//  Created by Li Cheuk Yin on 16/4/2023.
//  Copyright © 2023 Li Cheuk Yin. All rights reserved.
//

import UIKit
import DropDown

class BadQualityViewController: UIViewController {

    @IBOutlet weak var myDropDownView: UIView!

    @IBOutlet weak var dropdownButton: UIButton!
    
    @IBOutlet weak var percentLabel: UILabel!
    static var percentDecrease = ""
    let myDropDown = DropDown()
    let percentValueArray = ["10%", "15%", "20%", "25%", "30%", "35%", "40%", "45%", "50%", "55%", "60%", "65%", "70%" , "75%", "80%", "85%", "90%", "95%"]
    
    @IBAction func isTappeddropdownButton(_ sender: Any) {
        myDropDown.show()
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        myDropDown.anchorView = myDropDownView
        myDropDown.dataSource = percentValueArray
        
        myDropDown.selectionAction = { (index: Int, item: String) in
            self.percentLabel.text = self.percentValueArray[index]
            self.percentLabel.textColor = .black
            BadQualityViewController.percentDecrease = self.percentLabel.text ?? ""
        }
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
