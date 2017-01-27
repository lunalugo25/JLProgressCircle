//
//  ViewController.swift
//  JLProgressCircle
//
//  Created by jorge guillermo luna lugo on 10/01/17.
//  Copyright © 2017 Jorge Luna. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var vwCircle: UIView!
    var vwProgressCircle: JLProgressCircle!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let maxNumber = 100.0
        
        vwProgressCircle = JLProgressCircle.init(frame: CGRect(x: 0, y: 0, width: vwCircle.frame.width, height: vwCircle.frame.height))
        vwProgressCircle.transitionType = .gradual
        vwProgressCircle.circleWidth = 40
        
        vwProgressCircle.circleBackgroundWidth = 10
        vwProgressCircle.circleInnerWidth = 50
        
        vwProgressCircle.circleColor = UIColor(red: 35/255, green: 240/255, blue: 5/255, alpha: 0.9)
        vwProgressCircle.circleBackgroundColor = UIColor.grayColor()
        vwProgressCircle.circleHighlightColor = UIColor.redColor()
        vwProgressCircle.circleTransitionColor = UIColor.yellowColor()
        vwProgressCircle.shouldShowAccentLine = false
        
        vwProgressCircle.isBackgroundVisible = true
        
        let numberFormat: JLProgressCircleLabelFormatBlock = { progress in
            return "\(progress) %"
        }
        vwProgressCircle.labelFormatBlock = numberFormat
        
        vwCircle.addSubview(vwProgressCircle)
        vwProgressCircle.maxTotal = CGFloat(maxNumber)

        let completionTimerBlock: JLProgressCircleProgressBlockCompletion = {progress, isAnimationCompleteForProgress in
            if isAnimationCompleteForProgress {
                if ( progress >= Float(90) ){
                    NSLog("Bloque: \(progress)")
                    self.vwProgressCircle.setProgress(25.0)
                } else {
                    self.vwProgressCircle.setProgress(progress + 10.0)
                }
            }
        }
        
        self.vwProgressCircle.progressBlock = completionTimerBlock
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        vwProgressCircle.setProgress(10)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

