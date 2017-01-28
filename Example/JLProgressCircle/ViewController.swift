//
//  ViewController.swift
//  JLProgressCircle
//
//  Created by jorge guillermo luna lugo on 10/01/17.
//  Copyright © 2017 Jorge Luna. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var vwProgressCircle: JLProgressCircle!
    
    var randomTimer:NSTimer!
    var circleProgress: Float = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        setupProgressCircle()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    private func setupProgressCircle() {
        vwProgressCircle.transitionType = .none
        
        vwProgressCircle.numberFont = UIFont(name: "Avenir Book", size: 32)
        
        vwProgressCircle.circleWidth = 40
        vwProgressCircle.circleBackgroundWidth = 10
        vwProgressCircle.circleInnerWidth = 50
        
        vwProgressCircle.circleColor = UIColor(red: 35/255, green: 240/255, blue: 5/255, alpha: 1.0)
        vwProgressCircle.circleBackgroundColor = UIColor.grayColor()
        vwProgressCircle.circleHighlightColor = UIColor.redColor()
        vwProgressCircle.circleTransitionColor = UIColor.yellowColor()

        vwProgressCircle.shouldShowAccentLine = false
        vwProgressCircle.isBackgroundVisible = true
        
        let numberFormat: JLProgressCircleLabelFormatBlock = { progress, total in
            return "\(Int(progress))%"
        }
        vwProgressCircle.labelFormatBlock = numberFormat
        
        
        let completionTimerBlock: JLProgressCircleProgressBlockCompletion = {progress, total, isAnimationCompleteForProgress in
            if progress >= total {
                self.randomTimer?.invalidate()
            }
            print("Progress: \(progress), animate: \(isAnimationCompleteForProgress)")
        }
        vwProgressCircle.progressBlock = completionTimerBlock
    }
    
    func randomIncrement() {
        self.addProgress()
    }
    
    private func addProgress() {
        let remain = vwProgressCircle.getMaxNumber() - circleProgress
        if remain > 0 {
            let iRemain = UInt32(remain)
            var random = circleProgress + Float(arc4random_uniform(iRemain)) / 3
            random = round(random)
            if circleProgress != random && random > circleProgress {
                circleProgress = random
            } else {
                circleProgress += 1
            }
            vwProgressCircle.setProgress(circleProgress)
        }
    }
    
    @IBAction func stop(sender: AnyObject) {
        stopTimer()
    }
    
    @IBAction func play(sender: AnyObject) {
        stopTimer()
        randomTimer = NSTimer.scheduledTimerWithTimeInterval(0.2, repeats: true, block: { timer in
            self.addProgress()
        })
    }
    
    private func stopTimer() {
        randomTimer?.invalidate()
        vwProgressCircle.reset()
        circleProgress = 0
    }
}

