//
//  BuckleViewController.swift
//  Pear Insurance
//
//  Created by Nithin Reddy Gaddam on 1/17/18.
//  Copyright © 2018 Pear Insurance. All rights reserved.
//

import UIKit

class BuckleViewController: UIViewController {

    @IBOutlet weak var buckleImage: UIImageView!
    @IBOutlet weak var buckleText: UILabel!

    var timer = Timer()
    var flag = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()

        runTimer()

        // Do any additional setup after loading the view.
    }

    func runTimer() {
        timer = Timer.scheduledTimer(timeInterval: 5, target: self,   selector: (#selector(BuckleViewController.changeBuckle)), userInfo: nil, repeats: true)
    }

    @objc func changeBuckle() {
        if flag == 5{
            timer.invalidate()
            self.dismiss(animated: true, completion: {

            })
        } else {
            flag += 1
            if (flag % 2 != 0){
                buckleImage.image = #imageLiteral(resourceName: "UnBuckle")
                buckleText.text = "UnBuckle"
            } else {
                buckleImage.image = #imageLiteral(resourceName: "Buckle_up")
                buckleText.text = "Buckle It"
            }

        }
    }
}
