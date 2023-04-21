//  Banana Detector
//
//  Created by Li Cheuk Yin on 16/4/2023.
//  Copyright © 2023 Li Cheuk Yin. All rights reserved.
//
import UIKit

class GoodQualityViewController: UIViewController {

    @IBOutlet weak var BestBeforeLabel: UILabel!
    @IBOutlet weak var ClassLabel: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        if InferenceViewController.getResult == "Underripe"{
            ClassLabel.text = "Underripe"
            BestBeforeLabel.text = "7"
        }else if InferenceViewController.getResult == "Barely ripe" {
            ClassLabel.text = "Barely ripe"
            BestBeforeLabel.text = "5"
        }else{
            ClassLabel.text = "Ripe"
            BestBeforeLabel.text = "3"
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
