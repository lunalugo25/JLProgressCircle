//
//  JLProgressCircle.swift
//  JLProgressCircle
//
//  Created by jorge guillermo luna lugo on 10/01/17.
//  Copyright © 2017 Jorge Luna. All rights reserved.
//

import UIKit

// MARK: - JLProgressCircleProtocol
protocol JLProgressCircleProtocol {
    func willAnimateToProgress(circle: JLProgressCircle, progress: Float) -> Void
    func didAnimateToProgress(circle: JLProgressCircle, progress: Float) -> Void
}

typealias JLProgressCircleProgressBlockCompletion = ( Float, Float, Bool) -> Void
typealias JLProgressCircleLabelFormatBlock = (Float, Float) -> String

enum JLProgressCircleColorTransitionType {
    case gradual
    case incremental
    case none
}

enum JLProgressCircleRotationDirection {
    case clockwise
    case counterClockwise
}

enum JLProgressPiece :String {
    case increaseLineWidthAnimation
    case innerToOuterMoveAnimation
    case flashStartAnimation
    case flashFadeAnimation
    case lineMoveAnimation
    case lineFadeAnimation
    case lineIsFinishedNarrowAnimation
    case lineIsFinishedRetractAnimation
    case lineQuitAnimation
}

extension CABasicAnimation {
    func setLayer(layer: CAShapeLayer, name: JLProgressPiece,current: Float) {
        self.setValue(layer, forKey:"layer")
        self.setValue(name.rawValue, forKey:"name" )
        self.setValue(NSNumber(float: current), forKey: "current")
    }
    
    func setLayer(layer: CAShapeLayer, name: JLProgressPiece) {
        self.setValue(layer, forKey:"layer")
        self.setValue(name.rawValue, forKey:"name" )
    }
}

// MARK: - CGFloat Extension
extension CGFloat {
    func degreesToRadians() -> CGFloat {
        return (self/180.0 * CGFloat(M_PI))
    }
}
// MARK - UIView Extension
extension UIView {
    func pushTransition(duration: CFTimeInterval) {
        let animation = CATransition()
        animation.removedOnCompletion = true
        animation.duration = duration
        //animation.type = kCATransitionPush
        animation.type = kCATransitionFromBottom
        //animation.subtype = kCATransitionFromTop
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        self.layer.addAnimation(animation, forKey: "changeTextTransition")
    }
}

// MARK: - UIColor Extension
extension UIColor {
    func progressHighlight() -> UIColor {
        var (red, green, blue, alpha) = (CGFloat(0), CGFloat(0), CGFloat(0), CGFloat(0))
        if self.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            red = red * 1.2
            green = green * 1.2
            blue = blue * 1.2
            alpha = alpha * 1.2
            return UIColor(red: red, green: green, blue: blue, alpha: alpha)
        } else {    // Could not extract RGBA components:
            return self
        }
    }
    
    class func transition(original: UIColor, transition: UIColor, progress: CGFloat) -> UIColor {
        var intermittent: UIColor
        if progress < 1.0 {
            let progressPercentage = progress
            let progressPercentageInversion = 1 - progressPercentage
            
            var (originRed, originGreen, originBlue, originAlpha) = (CGFloat(0),CGFloat(0),CGFloat(0),CGFloat(0))
            if original.getRed(&originRed, green: &originGreen, blue: &originBlue, alpha: &originAlpha) {
                originRed = CGFloat(originRed * 255.0) * progressPercentageInversion
                originGreen = CGFloat(originGreen * 255.0) * progressPercentageInversion
                originBlue = CGFloat(originBlue * 255.0) * progressPercentageInversion
                originAlpha = CGFloat(originAlpha * 255.0) * progressPercentageInversion
            }
            
            var (transitionRed, transitionGreen, transitionBlue, transitionAlpha) = (CGFloat(0),CGFloat(0),CGFloat(0),CGFloat(0))
            if transition.getRed(&transitionRed, green: &transitionGreen, blue: &transitionBlue, alpha: &transitionAlpha) {
                transitionRed = CGFloat(transitionRed * 255.0) * progressPercentage
                transitionGreen = CGFloat(transitionGreen * 255.0) * progressPercentage
                transitionBlue = CGFloat(transitionBlue * 255.0) * progressPercentage
                transitionAlpha = CGFloat(transitionAlpha * 255.0) * progressPercentage
            }
            
            let red = transitionRed + originRed
            let green = transitionGreen + originGreen
            let blue = transitionBlue + originBlue
            let alpha = transitionAlpha + originAlpha
            
            intermittent = UIColor(red: red/255, green: green/255, blue: blue/255, alpha: alpha/255)
        } else {
            intermittent = transition
        }
        return intermittent
    }
    
    class func progressColor() -> UIColor {
        return UIColor(colorLiteralRed:138/255, green: 43/255, blue: 226/255, alpha: 1)
    }
}

// MARK: -
class JLProgressCircle: UIView, CAAnimationDelegate {
    // MARK: Public Properties
    var delegate: JLProgressCircleProtocol?
    var progressBlock: JLProgressCircleProgressBlockCompletion?
    var labelFormatBlock: JLProgressCircleLabelFormatBlock?

    var shouldNumberLabelTransition = true
    var shouldShowFinishedAccentCircle = true
    var shouldShowAccentLine = true
    var shouldHighligthProgress = true
    var isBackgroundVisible = true { didSet {backgroundCircle.hidden = !isBackgroundVisible} }
    
    var animationSpeed: Float = 1.0
    var accentLineColor: UIColor = .greenColor()
    var numberLabelColor: UIColor = .greenColor()
    var numberLabelTransitionColor: UIColor = .progressColor()
    var numberFont: UIFont? { didSet {self.numberLabel.font = numberFont} }
    
    var maxNumber: CGFloat = 100
    
    var transitionType: JLProgressCircleColorTransitionType = .none

    var circleColor: UIColor = UIColor.progressColor()
    var circleBackgroundColor: UIColor = UIColor.progressColor().colorWithAlphaComponent(0.3) { didSet {self.backgroundCircle.strokeColor = circleBackgroundColor.CGColor} }
    var circleHighlightColor: UIColor = UIColor.progressColor().progressHighlight()
    var circleTransitionColor: UIColor = UIColor.progressColor() {
        didSet {
            circleHighlightTransitionColor = circleTransitionColor.progressHighlight()
        }
    }

    var circleWidth: CGFloat = 0 { didSet {self.setupLines()} }
    var circleBackgroundWidth: CGFloat = 0 { didSet {self.backgroundCircle.lineWidth = circleBackgroundWidth} }
    var circleInnerWidth: CGFloat = 0 { didSet {self.setupProgress()} }
    
    // MARK: Private Properties
    private var circleHighlightTransitionColor: UIColor = UIColor.progressColor().progressHighlight()
    
    private var progressPieceArray: [CAShapeLayer] = []
    private let kLine = "line"
    private let kLayer = "layer"
    private let kCurrent = "current"
    private let kName = "name"
    
    private var finished: Bool = false
    private var total: CGFloat = 0
    private var backgroundCircle = CAShapeLayer()
    private var backgroundCirclePath: UIBezierPath?
    private var innerBackgroundPath: UIBezierPath?
    private var outerBackgroundPath: UIBezierPath?
    private var numberViewPath: UIBezierPath?
    
    private var progressPieceView = UIView()
    private var numberLabel = UILabel()
    private var numberLabelWidth: CGFloat = 0
    
    // MARK: - JLProgressCircle Initializers
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setupInit()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupInit()
    }
    
    // MARK: - JLProgressCircle Public Methods
    func setProgress(progress: Float) {
        notifyAnimateToProgress(progress, animationComplete: false)
        let floatProgress = CGFloat(progress)
        if total >= maxNumber || floatProgress == total || floatProgress > maxNumber {
            return
        }
        
        if floatProgress < total {
            let newProgress = (floatProgress / maxNumber) + 0.0005
            for pastProgressPiece in progressPieceArray {
                let strokeEnd = pastProgressPiece.strokeEnd
                if newProgress < strokeEnd {
                    removeLayer(pastProgressPiece)
                }
            }
            
            if let last = progressPieceArray.last {
                total = (last.strokeEnd - 0.0005) * maxNumber
                
                if transitionType == .gradual {
                    colorPieces(progressPieceArray, color: UIColor.transition(circleColor, transition: circleTransitionColor, progress: CGFloat(floatProgress)/maxNumber).CGColor)
                }
            } else {
                total = 0
            }
        }
        
        addProgress(floatProgress)
    }
    
    func reset() {
        for piece in progressPieceArray {
            piece.removeFromSuperlayer()
        }
        total = 0
        setText(0)
        finished = false
    }
    
    func getMaxNumber() -> Float {
        return Float(maxNumber)
    }
    
    // MARK: - JLProgressCircle Private Methods
    private func setupInit() {
        var newFrame = frame
        let maxSize = min(newFrame.height,newFrame.width)
        newFrame.size.height = maxSize
        newFrame.size.width = maxSize
        self.frame = newFrame
        
        total = 0
        animationSpeed = 1.0
        
        circleColor = .progressColor()
        accentLineColor = .progressColor()
        circleHighlightColor = UIColor.lightGrayColor().progressHighlight()
        
        circleWidth = CGFloat(self.frame.width/12)
        circleBackgroundWidth = circleWidth
        circleInnerWidth = CGFloat(self.frame.height * 0.07)
        
        numberLabelWidth = self.frame.width - (2*circleWidth)
        self.setupProgress()
    }
    
    private func setupProgress() {
        setupLines()
        setupViews()
    }
    
    private func setupLines() {
        let centerPoint = CGPoint(x: self.center.x - self.frame.origin.x, y: self.center.y - self.frame.origin.y)
        let radius = (self.frame.height*0.5) - circleWidth/2
        backgroundCirclePath = UIBezierPath(arcCenter: centerPoint, radius: radius, startAngle: CGFloat(270.0).degreesToRadians(), endAngle: CGFloat(269.99).degreesToRadians(), clockwise: true)

        backgroundCircle = CAShapeLayer()
        backgroundCircle.path = backgroundCirclePath?.CGPath
        backgroundCircle.lineCap = kCALineCapRound
        backgroundCircle.fillColor = UIColor.clearColor().CGColor
        backgroundCircle.lineWidth = circleBackgroundWidth
        backgroundCircle.strokeColor = circleBackgroundColor.CGColor
        backgroundCircle.strokeEnd = 1.0
        backgroundCircle.zPosition = -1
        
        let radiusInner = (self.frame.height*0.5)
        innerBackgroundPath = UIBezierPath(arcCenter: centerPoint, radius: radiusInner, startAngle: CGFloat(270.0).degreesToRadians(), endAngle: CGFloat(269.99).degreesToRadians(), clockwise: true)
        
        let radiusOuter = (self.frame.height*0.5) + circleWidth
        outerBackgroundPath = UIBezierPath(arcCenter: centerPoint, radius: radiusOuter, startAngle: CGFloat(270.0).degreesToRadians(), endAngle: CGFloat(269.99).degreesToRadians(), clockwise: true)
        
        let centerNumberView = CGPoint(x: self.center.x - self.frame.origin.x, y: self.center.y - self.frame.origin.y)
        numberViewPath = UIBezierPath(arcCenter: centerNumberView, radius: circleInnerWidth, startAngle: CGFloat(270.0).degreesToRadians(), endAngle: CGFloat(269.99).degreesToRadians(), clockwise: true)
        
        self.layer.sublayers?.removeAll()
        
        //1369 Remover el color
        /*
        let circleInner = CAShapeLayer()
        circleInner.path = innerBackgroundPath?.CGPath
        circleInner.fillColor = UIColor.clearColor().CGColor
        circleInner.strokeColor = UIColor.blueColor().CGColor
        self.layer.addSublayer(circleInner)
        self.layer.borderWidth = 1
        
        let circleOuter = CAShapeLayer()
        circleOuter.path = outerBackgroundPath?.CGPath
        circleOuter.fillColor = UIColor.clearColor().CGColor
        circleOuter.strokeColor = UIColor.orangeColor().CGColor
        self.layer.addSublayer(circleOuter)
        self.layer.borderWidth = 1
        
        let circleNumber = CAShapeLayer()
        circleNumber.path = numberViewPath?.CGPath
        circleNumber.fillColor = UIColor.clearColor().CGColor
        circleNumber.strokeColor = UIColor.purpleColor().CGColor
        self.layer.addSublayer(circleNumber)
        self.layer.borderWidth = 1
        */
        self.layer.addSublayer(backgroundCircle)
    }

    private func setupViews() {
        progressPieceView = UIView(frame: CGRect(x: 0, y: 0, width: numberLabelWidth, height: numberLabelWidth))
        self.addSubview(progressPieceView)
        
        numberLabel.translatesAutoresizingMaskIntoConstraints = false
        numberLabel.font = UIFont(name: "Avenir Book", size: 33)
        setText(0)
        numberLabel.textAlignment = .Center

        self.addSubview(numberLabel)
        
        let horizontalConstraint = numberLabel.centerXAnchor.constraintEqualToAnchor(self.centerXAnchor)
        let verticalConstraint = numberLabel.centerYAnchor.constraintEqualToAnchor(self.centerYAnchor)
        NSLayoutConstraint.activateConstraints([horizontalConstraint, verticalConstraint])
    }
    
    private func addProgress(current: CGFloat) {
        
        let progressPiece = getProgressPiece(current)
        let progressPieceLine = getProgressPieceLine(current)
        
        progressPieceView.layer.addSublayer(progressPiece)
        
        if current >= maxNumber {
            total = maxNumber
            if !finished && shouldShowFinishedAccentCircle {
                progressPieceLine.strokeStart = 0.0
                progressPieceLine.strokeEnd = maxNumber + 0.001
                finished = true
            }
        } else {
            total = current
        }
        
        progressPiece.setValue(progressPieceLine, forKey: kLine)
        
        let innerToOuterMoveAnimation = getInnerToOuterMoveAnimation(progressPiece)
        let increaseLineWidthAnimation = getIncreaseLineWidthAnimation(progressPiece)
        let flashStartAnimation = getFlashStartAnimation(progressPiece, progress: current)
        
        let flashFadeAnimation = getFlashFadeAnimation(progressPiece, progress: total)
        
        
        dispatch_async(dispatch_get_main_queue()) {
            progressPiece.addAnimation(innerToOuterMoveAnimation, forKey: "path")
            progressPiece.addAnimation(increaseLineWidthAnimation, forKey: "lineWidth")
            progressPiece.addAnimation(flashStartAnimation, forKey: "strokeColor")
            
            if self.shouldHighligthProgress {
                progressPiece.addAnimation(flashFadeAnimation, forKey: "strokeColorFade")
            }
        }
    }
    
    private func addProgress(pieceLine: CAShapeLayer ,current: CGFloat) {
        let progressCircleIsComplete = current == maxNumber
        
        var lineMoveAnimation = CABasicAnimation()
        var lineFadeAnimation = CABasicAnimation()
        
        if shouldShowAccentLine {
            lineMoveAnimation = getLineMoveAnimation(pieceLine, progress: current)
            lineFadeAnimation = getLineFadeAnimation(pieceLine, progress: current)
        }
        
        var lineIsFinishedNarrowAnimation = CABasicAnimation()
        var lineIsFinishedRetractAnimation = CABasicAnimation()
        
        if progressCircleIsComplete && shouldShowFinishedAccentCircle {
            lineMoveAnimation = getLineMoveAnimation(pieceLine, progress: current)
            lineMoveAnimation.timingFunction = CAMediaTimingFunction(controlPoints: 0.33, 0.88, 0.33, 0.88)
            lineIsFinishedNarrowAnimation = getLineIsFinishedNarrowAnimation(pieceLine)
            lineIsFinishedRetractAnimation = getLineIsFinishedRetractAnimation(pieceLine, progress: current)
        }
        
        progressPieceView.layer.addSublayer(pieceLine)
        dispatch_async(dispatch_get_main_queue()) {
            if progressCircleIsComplete && self.shouldShowFinishedAccentCircle {
                pieceLine.addAnimation(lineMoveAnimation, forKey: "path")
                pieceLine.addAnimation(lineIsFinishedNarrowAnimation, forKey: "lineWidth")
                pieceLine.addAnimation(lineIsFinishedRetractAnimation, forKey: "pathRetract")
            } else if self.shouldShowAccentLine {
                pieceLine.addAnimation(lineMoveAnimation, forKey: "path")
                pieceLine.addAnimation(lineFadeAnimation, forKey: "opacity")
            }
        }
    }
    
    private func removeLayer(pieceLine: CAShapeLayer) {
        
        self.progressPieceArray.removeAtIndex(self.progressPieceArray.indexOf(pieceLine)!)
        
        let outerToInnerMoveAnimation = getInnerToOuterMoveAnimation(pieceLine, isAdding: false)
        let decreaseLineWidthAnimation = getIncreaseLineWidthAnimation(pieceLine, isAdding: false)
        
        dispatch_async(dispatch_get_main_queue()) {
            pieceLine.addAnimation(outerToInnerMoveAnimation, forKey: "path")
            pieceLine.addAnimation(decreaseLineWidthAnimation, forKey: "lineWidth")
        }
    }
    
    private func colorPieces(pieces:[CAShapeLayer], color: CGColor) {
        for piece in pieces {
            piece.strokeColor = color
        }
    }
    
    private func setText(current: Float){
        if labelFormatBlock != nil {
            numberLabel.text = labelFormatBlock?(current, Float(maxNumber))
        } else {
            let percent = (CGFloat(current) / maxNumber) * 100
            numberLabel.text = "\(Int(percent))%"
        }
    }
    
    // MARK: - CAShapeLayer Components Initializers
    private func getProgressPiece(progress: CGFloat) -> CAShapeLayer {
        let progressPiece = CAShapeLayer()
        progressPiece.path = numberViewPath?.CGPath
        progressPiece.strokeStart = total/maxNumber
        progressPiece.strokeEnd = (progress / maxNumber) + 0.0005
        progressPiece.lineWidth = CGFloat(self.frame.width/maxNumber)
        
        if transitionType == .gradual || transitionType == .incremental {
            progressPiece.strokeColor = UIColor.transition(circleColor, transition: circleTransitionColor, progress: progress/maxNumber).CGColor
        } else {
            progressPiece.strokeColor = circleColor.CGColor
        }
        
        progressPiece.backgroundColor = UIColor.grayColor().CGColor
        progressPiece.fillColor = UIColor.clearColor().CGColor
        
        return progressPiece
    }
    
    private func getProgressPieceLine(progress: CGFloat) -> CAShapeLayer {
        let progressPieceLine = CAShapeLayer()
        progressPieceLine.path = innerBackgroundPath?.CGPath
        progressPieceLine.strokeStart = total/maxNumber
        progressPieceLine.strokeEnd = (progress / maxNumber) + 0.001
        progressPieceLine.lineWidth = CGFloat(self.frame.width/maxNumber)
        
        if transitionType == .gradual || transitionType == .incremental {
            progressPieceLine.strokeColor = UIColor.transition(circleColor, transition: circleTransitionColor, progress: progress/maxNumber).CGColor
        } else {
            progressPieceLine.strokeColor = circleColor.CGColor
        }
        progressPieceLine.fillColor = UIColor.clearColor().CGColor
        
        return progressPieceLine
    }
    
    // MARK: - CABasicAnimation Components Initializers
    private func getIncreaseLineWidthAnimation(layer: CAShapeLayer, isAdding:Bool = true) -> CABasicAnimation {
        let increaseLineWidthAnimation = CABasicAnimation(keyPath: "lineWidth")
        increaseLineWidthAnimation.delegate = self
        increaseLineWidthAnimation.duration = 0.1
        increaseLineWidthAnimation.speed = animationSpeed
        increaseLineWidthAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        if isAdding {
            increaseLineWidthAnimation.beginTime = 0.0
            increaseLineWidthAnimation.fromValue = NSNumber(integer: Int(self.frame.width / maxNumber))
            increaseLineWidthAnimation.toValue = circleWidth
            increaseLineWidthAnimation.setLayer(layer, name: .increaseLineWidthAnimation, current: Float(total))
        } else {
            increaseLineWidthAnimation.beginTime = 0.5
            increaseLineWidthAnimation.fromValue = circleWidth
            increaseLineWidthAnimation.toValue = NSNumber(integer: Int(self.frame.width / maxNumber))
            increaseLineWidthAnimation.setLayer(layer, name: .increaseLineWidthAnimation, current: Float(total))
        }
        return increaseLineWidthAnimation
    }
    
    private func getInnerToOuterMoveAnimation(layer: CAShapeLayer, isAdding:Bool = true) -> CABasicAnimation {
        let innerToOuterMoveAnimation = CABasicAnimation(keyPath: "path")
        innerToOuterMoveAnimation.delegate = self
        innerToOuterMoveAnimation.duration = 0.5
        innerToOuterMoveAnimation.speed = animationSpeed
        innerToOuterMoveAnimation.timingFunction = CAMediaTimingFunction(controlPoints: 0.1, 0.25, 0.88, 0.0)
        if isAdding {
            innerToOuterMoveAnimation.beginTime = CACurrentMediaTime() + Double(0.4) / Double(animationSpeed)
            innerToOuterMoveAnimation.fromValue = numberViewPath?.CGPath
            innerToOuterMoveAnimation.toValue = backgroundCirclePath?.CGPath
            innerToOuterMoveAnimation.setLayer(layer, name: .innerToOuterMoveAnimation, current: Float(total))
        } else {
            innerToOuterMoveAnimation.beginTime = 0
            innerToOuterMoveAnimation.fromValue = backgroundCirclePath?.CGPath
            innerToOuterMoveAnimation.toValue = numberViewPath?.CGPath
            innerToOuterMoveAnimation.setLayer(layer, name: .lineQuitAnimation, current: Float(total))
        }

        return innerToOuterMoveAnimation
    }
    
    private func getFlashStartAnimation(layer: CAShapeLayer, progress: CGFloat) -> CABasicAnimation {
        let flashStartAnimation = CABasicAnimation(keyPath: "strokeColor")
        flashStartAnimation.delegate = self
        flashStartAnimation.beginTime = CACurrentMediaTime() + Double(0.9) / Double(animationSpeed)
        flashStartAnimation.speed = animationSpeed
        flashStartAnimation.duration = 0.1
        flashStartAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
        flashStartAnimation.fromValue = circleColor
        
        if shouldHighligthProgress {
            flashStartAnimation.toValue = circleHighlightColor
        } else if transitionType == .gradual || transitionType == .incremental {
            flashStartAnimation.toValue = UIColor.transition(circleColor, transition: circleTransitionColor, progress: progress/maxNumber)
        } else {
            flashStartAnimation.toValue = circleColor
        }
        flashStartAnimation.setLayer(layer, name: .flashStartAnimation, current: Float(total))
        return flashStartAnimation
    }
    
    private func getFlashFadeAnimation(layer: CAShapeLayer, progress: CGFloat) -> CABasicAnimation {
        let flashFadeAnimation = CABasicAnimation(keyPath: "strokeColorFade")
        flashFadeAnimation.delegate = self
        flashFadeAnimation.beginTime = CACurrentMediaTime() + Double(1.2) / Double(animationSpeed)
        flashFadeAnimation.speed = animationSpeed
        flashFadeAnimation.duration = 0.5
        flashFadeAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
        
        flashFadeAnimation.fromValue = circleColor
        flashFadeAnimation.toValue = circleColor
        
        if shouldHighligthProgress {
            flashFadeAnimation.fromValue = circleHighlightColor
        }
        flashFadeAnimation.setLayer(layer, name: .flashFadeAnimation, current: Float(progress))
        return flashFadeAnimation
    }
    
    private func getLineMoveAnimation(layer: CAShapeLayer, progress: CGFloat) -> CABasicAnimation {
        let lineMoveAnimation = CABasicAnimation(keyPath: "path")
        lineMoveAnimation.delegate = self
        lineMoveAnimation.beginTime = 0.0
        lineMoveAnimation.duration = 0.8
        lineMoveAnimation.speed = animationSpeed
        lineMoveAnimation.timingFunction = CAMediaTimingFunction(controlPoints: 0.1, 0.33, 0.33, 0.33)
        lineMoveAnimation.fromValue = innerBackgroundPath?.CGPath
        lineMoveAnimation.toValue = outerBackgroundPath?.CGPath
        lineMoveAnimation.setLayer(layer, name: .lineMoveAnimation, current: Float(progress))
        return lineMoveAnimation
    }
    
    private func getLineFadeAnimation(layer: CAShapeLayer, progress: CGFloat) -> CABasicAnimation {
        let lineFadeAnimation = CABasicAnimation(keyPath: "opacity")
        lineFadeAnimation.delegate = self
        lineFadeAnimation.beginTime = CACurrentMediaTime() + Double(0.3) / Double(animationSpeed)
        lineFadeAnimation.duration = 0.8
        lineFadeAnimation.speed = animationSpeed
        lineFadeAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        lineFadeAnimation.fromValue = NSNumber(float: 1.0)
        lineFadeAnimation.toValue = NSNumber(float: 0.1)
        lineFadeAnimation.setLayer(layer, name: .lineFadeAnimation, current: Float(progress))
        return lineFadeAnimation
    }
    
    private func getLineIsFinishedNarrowAnimation(layer: CAShapeLayer) -> CABasicAnimation {
        let lineIsFinishedNarrowAnimation = CABasicAnimation(keyPath: "lineWidth")
        lineIsFinishedNarrowAnimation.delegate = self
        lineIsFinishedNarrowAnimation.beginTime = CACurrentMediaTime() + Double(0.3) / Double(animationSpeed)
        lineIsFinishedNarrowAnimation.duration = 0.7
        lineIsFinishedNarrowAnimation.speed = animationSpeed
        lineIsFinishedNarrowAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        lineIsFinishedNarrowAnimation.fromValue = NSNumber(integer: Int(layer.lineWidth))
        lineIsFinishedNarrowAnimation.toValue = NSNumber(integer: Int(layer.lineWidth / 4))
        lineIsFinishedNarrowAnimation.setLayer(layer, name: .lineFadeAnimation)
        return lineIsFinishedNarrowAnimation
    }
    
    private func getLineIsFinishedRetractAnimation(layer: CAShapeLayer, progress: CGFloat) -> CABasicAnimation {
        let lineIsFinishedRetractAnimation = CABasicAnimation(keyPath: "path")
        lineIsFinishedRetractAnimation.delegate = self
        lineIsFinishedRetractAnimation.beginTime = CACurrentMediaTime() + Double(0.7) / Double(animationSpeed)
        lineIsFinishedRetractAnimation.duration = 0.3
        lineIsFinishedRetractAnimation.speed = animationSpeed
        lineIsFinishedRetractAnimation.timingFunction = CAMediaTimingFunction(controlPoints: 0.77, 0.33, 0.77, 0.33)
        lineIsFinishedRetractAnimation.fromValue = outerBackgroundPath?.CGPath
        lineIsFinishedRetractAnimation.toValue = innerBackgroundPath?.CGPath
        lineIsFinishedRetractAnimation.setLayer(layer, name: .lineIsFinishedRetractAnimation, current: Float(progress))
        return lineIsFinishedRetractAnimation
    }
    
    // MARK: - CAAnimationDelegate Methods
    func animationDidStart(anim: CAAnimation) {
        guard let name = anim.valueForKey(kName) as? String, let progressLayer = anim.valueForKey(kLayer) as? CAShapeLayer else {
            return
        }
        if let animationName = JLProgressPiece(rawValue: name) {
            switch animationName {
            case .innerToOuterMoveAnimation:
                progressLayer.path = backgroundCirclePath?.CGPath
            case .increaseLineWidthAnimation:
                progressLayer.lineWidth = circleWidth
            case .flashStartAnimation:
                guard let current = anim.valueForKey(kCurrent) as? NSNumber, let progressPieceLine = progressLayer.valueForKey(kLine) as? CAShapeLayer else {
                    return
                }
                
                numberLabel.textColor = numberLabelColor
                if transitionType == .gradual || transitionType == .incremental {
                    if transitionType == .gradual {
                        colorPieces(progressPieceArray, color: progressLayer.strokeColor!)
                    }
                    
                    if shouldNumberLabelTransition {
                        numberLabel.textColor = UIColor.transition(numberLabelColor, transition: numberLabelTransitionColor, progress: CGFloat(current)/maxNumber)
                    }
                }
                
                progressPieceArray.append(progressLayer)
                
                if shouldShowAccentLine || (shouldShowFinishedAccentCircle && CGFloat(current) == maxNumber) {
                    addProgress(progressPieceLine, current: CGFloat(current))
                }
                
                if transitionType == .gradual && self.shouldHighligthProgress {
                    progressLayer.strokeColor = UIColor.transition(circleHighlightColor, transition: circleHighlightTransitionColor, progress: CGFloat(current)/maxNumber).CGColor
                } else {
                    progressLayer.strokeColor = shouldHighligthProgress ?circleHighlightColor.CGColor : progressLayer.strokeColor
                }
                
                numberLabel.pushTransition(0.75)
                setText(Float(current))
            case .flashFadeAnimation:
                guard let current = anim.valueForKey(kCurrent) as? NSNumber else {
                    return
                }
                progressLayer.strokeColor = circleColor.CGColor
                if transitionType == .gradual || transitionType == .incremental {
                    if transitionType == .gradual {
                        colorPieces(progressPieceArray, color: UIColor.transition(circleColor, transition: circleTransitionColor, progress: CGFloat(current)/maxNumber).CGColor)
                    }
                    progressLayer.strokeColor = UIColor.transition(circleColor, transition: circleTransitionColor, progress: CGFloat(current)/maxNumber).CGColor
                }
            case .lineMoveAnimation:
                progressLayer.path = outerBackgroundPath?.CGPath
            case .lineFadeAnimation:
                progressLayer.opacity = 0
            case .lineIsFinishedNarrowAnimation:
                progressLayer.lineWidth = progressLayer.lineWidth / 4
            case .lineIsFinishedRetractAnimation:
                progressLayer.path = innerBackgroundPath?.CGPath
            case .lineQuitAnimation:
                progressLayer.path = numberViewPath?.CGPath
            }
        }
    }
    
    func animationDidStop(anim: CAAnimation, finished flag: Bool) {
        guard let name = anim.valueForKey(kName) as? String, let progressLayer = anim.valueForKey(kLayer) as? CAShapeLayer, let current = anim.valueForKey(kCurrent) as? NSNumber else {
            return
        }
        
        if let animationName = JLProgressPiece(rawValue: name) {
            switch animationName {
            case .lineIsFinishedRetractAnimation:
                progressLayer.removeFromSuperlayer()
                notifyAnimateToProgress(current.floatValue, animationComplete: true)
            case .innerToOuterMoveAnimation:
                if !shouldHighligthProgress && !shouldShowAccentLine {
                    notifyAnimateToProgress(current.floatValue, animationComplete: true)
                }
            case .flashFadeAnimation:
                if !shouldShowAccentLine {
                    notifyAnimateToProgress(current.floatValue, animationComplete: true)
                }
            case .lineFadeAnimation:
                notifyAnimateToProgress(current.floatValue, animationComplete: true)
            case .lineQuitAnimation:
                progressLayer.removeFromSuperlayer()
            default: ()
            }
        }
    }
    
    private func notifyAnimateToProgress(currentValue: Float, animationComplete: Bool) {
        if progressBlock != nil {
            progressBlock?(currentValue, Float(maxNumber), animationComplete)
        } else if delegate != nil {
            delegate?.didAnimateToProgress(self, progress: currentValue)
        }
    }
}
