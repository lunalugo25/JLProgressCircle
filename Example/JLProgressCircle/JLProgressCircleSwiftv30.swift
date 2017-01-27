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

typealias JLProgressCircleProgressBlockCompletion = ( Float, Bool) -> Void
typealias JLProgressCircleLabelFormatBlock = (Float) -> String
typealias JLProgressCircleLabelAttributedFormatBlock = (Float) -> NSAttributedString

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
}

extension CABasicAnimation {
    func setLayer(layer: CAShapeLayer,name: JLProgressPiece,current: Float) {
        self.setValue(layer, forKey:"layer")
        self.setValue(name.rawValue, forKey:"name" )
        self.setValue(NSNumber(value: current), forKey:"current")
    }
    
    func setLayer(layer: CAShapeLayer,name: JLProgressPiece) {
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

// MARK: - UILabel Extension
/*
extension UILabel {
    private currentValue
    
    func currentValue() -> CGFloat {
        if progress >= totalTime {
            return destinationValue
        }
        let percent = progress / totalTime
        let updateVal = counter
    }
    func count(initValue:Float ,endValue: Float) {
        
    }
    
    func countFromCurrentValueTo(endValue: Float) {
        
    }
}
 */
// MARK: -
class JLProgressCircle: UIView, CAAnimationDelegate {
    // MARK: Public Properties
    var delegate: JLProgressCircleProtocol?
    var progressBlock: JLProgressCircleProgressBlockCompletion?

    var shouldNumberLabelTransition = true
    var shouldShowFinishedAccentCircle = true
    var shouldShowAccentLine = true
    var shouldHighligthProgress = true
    var isBackgroundVisible = true { didSet {self.setupProgress()} }
    
    var animationSpeed: Float = 1.0
    var accentLineColor: UIColor = .green
    var numberLabelColor: UIColor = .green
    var numberLabelTransitionColor: UIColor = .progressColor()
    
    var maxTotal: CGFloat = 100
    
    var transitionType: JLProgressCircleColorTransitionType = .none

    var circleColor: UIColor = UIColor.progressColor()
    var circleBackgroundColor: UIColor = UIColor.progressColor().withAlphaComponent(0.3) { didSet {self.backgroundCircle.strokeColor = circleBackgroundColor.cgColor} }
    var circleHighlightColor: UIColor = UIColor.progressColor().progressHighlight()
    var circleTransitionColor: UIColor = UIColor.progressColor() {
        didSet {
            circleHighlightTransitionColor = circleTransitionColor.progressHighlight()
        }
    }

    var circleWidth: CGFloat = 0 { didSet {self.setupProgress()} }
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
    private var numberView = UIView()
    private var numberLabel = UILabel()
    
    // MARK: - JLProgressCircle Initializers
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setupDefaults()
        self.setupProgress()
    }
    
    override init(frame: CGRect) {
        var newFrame = frame
        let maxSize = min(newFrame.height,newFrame.width)
        newFrame.size.height = maxSize
        newFrame.size.width = maxSize
        super.init(frame: newFrame)
        self.setupDefaults()
        self.setupProgress()
    }
    
    // MARK: - JLProgressCircle Public Methods
    func setProgress(progress: Float) {
        let floatProgress = CGFloat(progress)
        if total >= maxTotal || floatProgress == total || floatProgress > maxTotal {
            return
        }
        
        if floatProgress < total {
            let newProgress = (floatProgress / maxTotal) + 0.0005
            for pastProgressPiece in progressPieceArray {
                let strokeEnd = pastProgressPiece.strokeEnd
                if newProgress < strokeEnd {
                    removeLayer(layer: pastProgressPiece, array: progressPieceArray)
                    progressPieceArray.remove(at: progressPieceArray.index(of: pastProgressPiece)!)
                }
            }
        }
        
        let progressPiece = getProgressPiece(progress: floatProgress)
        let progressPieceLine = getProgressPieceLine(progress: floatProgress)
        
        progressPieceView.layer.addSublayer(progressPiece)
        
        if floatProgress >= maxTotal {
            total = maxTotal
            if !finished && shouldShowFinishedAccentCircle {
                progressPieceLine.strokeStart = 0.0
                progressPieceLine.strokeEnd = maxTotal + 0.001
                finished = true
            }
        } else {
            total = floatProgress
        }
        
        progressPiece.setValue(progressPieceLine, forKey: kLine)
        
        let innerToOuterMoveAnimation = getInnerToOuterMoveAnimation(layer: progressPiece)
        let increaseLineWidthAnimation = getIncreaseLineWidthAnimation(layer: progressPiece)
        let flashStartAnimation = getFlashStartAnimation(layer: progressPiece, progress: floatProgress)
        
        let flashFadeAnimation = getFlashFadeAnimation(layer: progressPiece, progress: total)
        
        DispatchQueue.main.async { 
            progressPiece.add(innerToOuterMoveAnimation , forKey: "path")
            progressPiece.add(increaseLineWidthAnimation , forKey: "lineWidth")
            progressPiece.add(flashStartAnimation , forKey: "strokeColor")
            
            if self.shouldHighligthProgress {
                progressPiece.add(flashFadeAnimation, forKey: "strokeColorFade")
            }
        }
    }
    
    // MARK: - JLProgressCircle Private Methods
    private func setupProgress() {
        setupLines()
        setupViews()
    }
    
    private func setupDefaults() {
        total = 0
        animationSpeed = 1.0
        
        circleColor = .progressColor()
        accentLineColor = .progressColor()
        circleHighlightColor = UIColor.lightGray.progressHighlight()
        
        circleWidth = CGFloat(self.frame.width/12)
        circleBackgroundWidth = circleWidth
        circleInnerWidth = CGFloat(self.frame.height * 0.07)
    }
    
    private func setupLines() {
        let centerPoint = CGPoint(x: self.center.x - self.frame.origin.x, y: self.center.y - self.frame.origin.y)
        let radius = (self.frame.height*0.5) - circleWidth/2
        backgroundCirclePath = UIBezierPath(arcCenter: centerPoint, radius: radius, startAngle: CGFloat(270.0).degreesToRadians(), endAngle: CGFloat(269.99).degreesToRadians(), clockwise: true)

        backgroundCircle = CAShapeLayer()
        backgroundCircle.path = backgroundCirclePath?.cgPath
        backgroundCircle.lineCap = kCALineCapRound
        backgroundCircle.fillColor = UIColor.clear.cgColor
        backgroundCircle.lineWidth = circleBackgroundWidth
        backgroundCircle.strokeColor = circleBackgroundColor.cgColor
        backgroundCircle.strokeEnd = 1.0
        backgroundCircle.zPosition = -1
        
        let radiusInner = (self.frame.height*0.5) //- circleWidth
        innerBackgroundPath = UIBezierPath(arcCenter: centerPoint, radius: radiusInner, startAngle: CGFloat(270.0).degreesToRadians(), endAngle: CGFloat(269.99).degreesToRadians(), clockwise: true)
        
        let radiusOuter = (self.frame.height*0.5) + circleWidth
        outerBackgroundPath = UIBezierPath(arcCenter: centerPoint, radius: radiusOuter, startAngle: CGFloat(270.0).degreesToRadians(), endAngle: CGFloat(269.99).degreesToRadians(), clockwise: true)
        
        let centerNumberView = CGPoint(x: self.center.x - self.frame.origin.x, y: self.center.y - self.frame.origin.y)
        numberViewPath = UIBezierPath(arcCenter: centerNumberView, radius: circleInnerWidth, startAngle: CGFloat(270.0).degreesToRadians(), endAngle: CGFloat(269.99).degreesToRadians(), clockwise: true)
        
        self.layer.sublayers?.removeAll()
        
        //1369 Remover el color
        /*
        let circleInner = CAShapeLayer()
        circleInner.path = innerBackgroundPath?.cgPath
        circleInner.fillColor = UIColor.clear.cgColor
        circleInner.strokeColor = UIColor.blue.cgColor
        self.layer.addSublayer(circleInner)
        self.layer.borderWidth = 1
        
        let circleOuter = CAShapeLayer()
        circleOuter.path = outerBackgroundPath?.cgPath
        circleOuter.fillColor = UIColor.clear.cgColor
        circleOuter.strokeColor = UIColor.orange.cgColor
        self.layer.addSublayer(circleOuter)
        self.layer.borderWidth = 1
        
        let circleNumber = CAShapeLayer()
        circleNumber.path = numberViewPath?.cgPath
        circleNumber.fillColor = UIColor.clear.cgColor
        circleNumber.strokeColor = UIColor.purple.cgColor
        self.layer.addSublayer(circleNumber)
        self.layer.borderWidth = 1
        */
        if isBackgroundVisible {
            self.layer.addSublayer(backgroundCircle)
        }
    }

    private func setupViews() {
        progressPieceView = UIView(frame: CGRect(x: 0, y: 0, width: self.frame.width - backgroundCircle.lineWidth * 2, height: self.frame.height))
        self.addSubview(progressPieceView)
        
        numberView = UIView(frame: CGRect(x: 0, y: 0, width: self.frame.width * 0.7, height: self.frame.height * 0.7))
        numberView.layer.cornerRadius = numberView.frame.width / 2
        numberView.center = self.center
        let blurEffect = UIBlurEffect(style: UIBlurEffectStyle.dark)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurEffectView.frame = numberView.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        numberView.addSubview(blurEffectView)
        
        numberLabel = UILabel(frame: CGRect(x: 0, y: 0, width: numberView.frame.width, height: numberView.frame.height))
        
        numberView.addSubview(numberLabel)
    }
    
    private func addProgress(pieceLine: CAShapeLayer ,current: CGFloat) {
        let progressCircleIsComplete = current == maxTotal
        
        var lineMoveAnimation = CABasicAnimation()
        var lineFadeAnimation = CABasicAnimation()
        
        if shouldShowAccentLine {
            lineMoveAnimation = getLineMoveAnimation(layer: pieceLine, progress: current)
            lineFadeAnimation = getLineFadeAnimation(layer: pieceLine, progress: current)
        }
        
        var lineIsFinishedNarrowAnimation = CABasicAnimation()
        var lineIsFinishedRetractAnimation = CABasicAnimation()
        
        if progressCircleIsComplete && shouldShowFinishedAccentCircle {
            lineMoveAnimation = getLineMoveAnimation(layer: pieceLine, progress: current)
            lineMoveAnimation.timingFunction = CAMediaTimingFunction(controlPoints: 0.33, 0.88, 0.33, 0.88)
            lineIsFinishedNarrowAnimation = getLineIsFinishedNarrowAnimation(layer: pieceLine)
            lineIsFinishedRetractAnimation = getLineIsFinishedRetractAnimation(layer: pieceLine, progress: current)
        }
        
        progressPieceView.layer.addSublayer(pieceLine)
        //1369 Valor por Layer
        //pieceLine.setValue(current, forKey: kCurrent)
        
        DispatchQueue.main.async {
            if progressCircleIsComplete && self.shouldShowFinishedAccentCircle {
                pieceLine.add(lineMoveAnimation, forKey: "path")
                pieceLine.add(lineIsFinishedNarrowAnimation, forKey: "lineWidth")
                pieceLine.add(lineIsFinishedRetractAnimation, forKey: "pathRetract")
            } else if self.shouldShowAccentLine {
                pieceLine.add(lineMoveAnimation, forKey: "path")
                pieceLine.add(lineFadeAnimation, forKey: "opacity")
            }
        }
    }
    
    private func removeLayer(layer: CAShapeLayer, array:[CAShapeLayer]) {
        layer.removeFromSuperlayer()
    }
    
    // MARK: - CAShapeLayer Components Initializers
    private func getProgressPiece(progress: CGFloat) -> CAShapeLayer {
        let progressPiece = CAShapeLayer()
        progressPiece.path = numberViewPath?.cgPath
        progressPiece.strokeStart = total/maxTotal
        progressPiece.strokeEnd = (progress / maxTotal) + 0.0005
        progressPiece.lineWidth = CGFloat(self.frame.width/maxTotal)
        
        if transitionType == .gradual || transitionType == .incremental {
            progressPiece.strokeColor = UIColor.transition(original: circleColor, transition: circleTransitionColor, progress: progress/maxTotal).cgColor
        } else {
            progressPiece.strokeColor = circleColor.cgColor
        }
        
        progressPiece.backgroundColor = UIColor.gray.cgColor
        progressPiece.fillColor = UIColor.clear.cgColor
        
        return progressPiece
    }
    
    private func getProgressPieceLine(progress: CGFloat) -> CAShapeLayer {
        let progressPieceLine = CAShapeLayer()
        progressPieceLine.path = innerBackgroundPath?.cgPath
        progressPieceLine.strokeStart = total/maxTotal
        progressPieceLine.strokeEnd = (progress / maxTotal) + 0.001
        progressPieceLine.lineWidth = CGFloat(self.frame.width/maxTotal)
        
        if transitionType == .gradual || transitionType == .incremental {
            progressPieceLine.strokeColor = UIColor.transition(original: circleColor, transition: circleTransitionColor, progress: progress/maxTotal).cgColor
        } else {
            progressPieceLine.strokeColor = circleColor.cgColor
        }
        progressPieceLine.fillColor = UIColor.clear.cgColor
        
        return progressPieceLine
    }
    
    // MARK: - CABasicAnimation Components Initializers
    private func getIncreaseLineWidthAnimation(layer: CAShapeLayer) -> CABasicAnimation {
        let increaseLineWidthAnimation = CABasicAnimation(keyPath: "lineWidth")
        increaseLineWidthAnimation.delegate = self
        increaseLineWidthAnimation.beginTime = 0.0
        increaseLineWidthAnimation.duration = 0.1
        increaseLineWidthAnimation.speed = animationSpeed
        increaseLineWidthAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        increaseLineWidthAnimation.fromValue = NSNumber(value: Int(self.frame.width / maxTotal))
        increaseLineWidthAnimation.toValue = circleWidth
        increaseLineWidthAnimation.setLayer(layer: layer, name: .increaseLineWidthAnimation, current: Float(total))
        return increaseLineWidthAnimation
    }
    
    private func getInnerToOuterMoveAnimation(layer: CAShapeLayer) -> CABasicAnimation {
        let innerToOuterMoveAnimation = CABasicAnimation(keyPath: "path")
        innerToOuterMoveAnimation.delegate = self
        innerToOuterMoveAnimation.beginTime = CACurrentMediaTime() + Double(0.4) / Double(animationSpeed)
        innerToOuterMoveAnimation.duration = 0.5
        innerToOuterMoveAnimation.speed = animationSpeed
        innerToOuterMoveAnimation.timingFunction = CAMediaTimingFunction(controlPoints: 0.1, 0.25, 0.88, 0.0)
        innerToOuterMoveAnimation.fromValue = numberViewPath?.cgPath
        innerToOuterMoveAnimation.toValue = backgroundCirclePath?.cgPath
        innerToOuterMoveAnimation.setLayer(layer: layer, name: .innerToOuterMoveAnimation, current: Float(total))
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
            flashStartAnimation.toValue = UIColor.transition(original: circleColor, transition: circleTransitionColor, progress: progress/maxTotal)
        } else {
            flashStartAnimation.toValue = circleColor
        }
        flashStartAnimation.setLayer(layer: layer, name: .flashStartAnimation, current: Float(total))
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
        flashFadeAnimation.setLayer(layer: layer, name: .flashFadeAnimation, current: Float(progress))
        return flashFadeAnimation
    }
    
    private func getLineMoveAnimation(layer: CAShapeLayer, progress: CGFloat) -> CABasicAnimation {
        let lineMoveAnimation = CABasicAnimation(keyPath: "path")
        lineMoveAnimation.delegate = self
        lineMoveAnimation.beginTime = 0.0
        lineMoveAnimation.duration = 0.8
        lineMoveAnimation.speed = animationSpeed
        lineMoveAnimation.timingFunction = CAMediaTimingFunction(controlPoints: 0.1, 0.33, 0.33, 0.33)
        lineMoveAnimation.fromValue = innerBackgroundPath?.cgPath
        lineMoveAnimation.toValue = outerBackgroundPath?.cgPath
        lineMoveAnimation.setLayer(layer: layer, name: .lineMoveAnimation, current: Float(progress))
        return lineMoveAnimation
    }
    
    private func getLineFadeAnimation(layer: CAShapeLayer, progress: CGFloat) -> CABasicAnimation {
        let lineFadeAnimation = CABasicAnimation(keyPath: "opacity")
        lineFadeAnimation.delegate = self
        lineFadeAnimation.beginTime = CACurrentMediaTime() + Double(0.3) / Double(animationSpeed)
        lineFadeAnimation.duration = 0.8
        lineFadeAnimation.speed = animationSpeed
        lineFadeAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        lineFadeAnimation.fromValue = NSNumber(value: 1.0)
        lineFadeAnimation.toValue = NSNumber(value: 0.1)
        lineFadeAnimation.setLayer(layer: layer, name: .lineFadeAnimation, current: Float(progress))
        return lineFadeAnimation
    }
    
    private func getLineIsFinishedNarrowAnimation(layer: CAShapeLayer) -> CABasicAnimation {
        let lineIsFinishedNarrowAnimation = CABasicAnimation(keyPath: "lineWidth")
        lineIsFinishedNarrowAnimation.delegate = self
        lineIsFinishedNarrowAnimation.beginTime = CACurrentMediaTime() + Double(0.3) / Double(animationSpeed)
        lineIsFinishedNarrowAnimation.duration = 0.7
        lineIsFinishedNarrowAnimation.speed = animationSpeed
        lineIsFinishedNarrowAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        lineIsFinishedNarrowAnimation.fromValue = NSNumber(value: Int(layer.lineWidth))
        lineIsFinishedNarrowAnimation.toValue = NSNumber(value: Int(layer.lineWidth / 4))
        lineIsFinishedNarrowAnimation.setLayer(layer: layer, name: .lineFadeAnimation)
        return lineIsFinishedNarrowAnimation
    }
    
    private func getLineIsFinishedRetractAnimation(layer: CAShapeLayer, progress: CGFloat) -> CABasicAnimation {
        let lineIsFinishedRetractAnimation = CABasicAnimation(keyPath: "path")
        lineIsFinishedRetractAnimation.delegate = self
        lineIsFinishedRetractAnimation.beginTime = CACurrentMediaTime() + Double(0.7) / Double(animationSpeed)
        lineIsFinishedRetractAnimation.duration = 0.3
        lineIsFinishedRetractAnimation.speed = animationSpeed
        lineIsFinishedRetractAnimation.timingFunction = CAMediaTimingFunction(controlPoints: 0.77, 0.33, 0.77, 0.33)
        lineIsFinishedRetractAnimation.fromValue = outerBackgroundPath?.cgPath
        lineIsFinishedRetractAnimation.toValue = innerBackgroundPath?.cgPath
        lineIsFinishedRetractAnimation.setLayer(layer: layer, name: .lineIsFinishedRetractAnimation, current: Float(progress))
        return lineIsFinishedRetractAnimation
    }
    
    // MARK: - CAAnimationDelegate Methods
    func animationDidStart(_ anim: CAAnimation) {
        guard let name = anim.value(forKey: kName) as? String, let progressLayer = anim.value(forKey: kLayer) as? CAShapeLayer else {
            return
        }
        if let animationName = JLProgressPiece(rawValue: name) {
            switch animationName {
            case .innerToOuterMoveAnimation:
                progressLayer.path = backgroundCirclePath?.cgPath
            case .increaseLineWidthAnimation:
                progressLayer.lineWidth = circleWidth
            case .flashStartAnimation:
                guard let current = anim.value(forKey: kCurrent) as? NSNumber, let progressPieceLine = progressLayer.value(forKey: kLine) as? CAShapeLayer else {
                    return
                }
                
                numberLabel.textColor = numberLabelColor
                if transitionType == .gradual || transitionType == .incremental {
                    if transitionType == .gradual {
                        for pastProgressPiece in progressPieceArray {
                            pastProgressPiece.strokeColor = progressLayer.strokeColor
                        }
                    }
                    progressPieceArray.append(progressLayer)
                    
                    if shouldNumberLabelTransition {
                        numberLabel.textColor = UIColor.transition(original: numberLabelColor, transition: numberLabelTransitionColor, progress: CGFloat(current)/maxTotal)
                    }
                }
                
                if shouldShowAccentLine || (shouldShowFinishedAccentCircle && CGFloat(current) == maxTotal) {
                    addProgress(pieceLine: progressPieceLine, current: CGFloat(current))
                }
                
                if transitionType == .gradual && self.shouldHighligthProgress {
                    progressLayer.strokeColor = UIColor.transition(original: circleHighlightColor, transition: circleHighlightTransitionColor, progress: CGFloat(current)/maxTotal).cgColor
                } else {
                    progressLayer.strokeColor = shouldHighligthProgress ?circleHighlightColor.cgColor : progressLayer.strokeColor
                }
            case .flashFadeAnimation:
                guard let current = anim.value(forKey: kCurrent) as? NSNumber else {
                    return
                }
                progressLayer.strokeColor = circleColor.cgColor
                if transitionType == .gradual || transitionType == .incremental {
                    if transitionType == .gradual {
                        for pastProgressPiece in progressPieceArray {
                            pastProgressPiece.strokeColor = UIColor.transition(original: circleColor, transition: circleTransitionColor, progress: CGFloat(current)/maxTotal).cgColor
                        }
                    }
                    progressLayer.strokeColor = UIColor.transition(original: circleColor, transition: circleTransitionColor, progress: CGFloat(current)/maxTotal).cgColor
                }
            case .lineMoveAnimation:
                progressLayer.path = outerBackgroundPath?.cgPath
            case .lineFadeAnimation:
                progressLayer.opacity = 0
            case .lineIsFinishedNarrowAnimation:
                progressLayer.lineWidth = progressLayer.lineWidth / 4
            case .lineIsFinishedRetractAnimation:
                progressLayer.path = innerBackgroundPath?.cgPath
            }
        }
    }
    
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        guard let name = anim.value(forKey: kName) as? String, let progressLayer = anim.value(forKey: kLayer) as? CAShapeLayer, let current = anim.value(forKey: kCurrent) as? NSNumber else {
            return
        }
        
        if let animationName = JLProgressPiece(rawValue: name) {
            switch animationName {
            case .lineIsFinishedRetractAnimation:
                progressLayer.removeFromSuperlayer()
                notifyAnimateToProgress(currentValue: current.floatValue, animationComplete: true)
            case .innerToOuterMoveAnimation:
                if !shouldHighligthProgress && !shouldShowAccentLine {
                    notifyAnimateToProgress(currentValue: current.floatValue, animationComplete: true)
                }
            case .flashFadeAnimation:
                if !shouldShowAccentLine {
                    notifyAnimateToProgress(currentValue: current.floatValue, animationComplete: true)
                }
            case .lineFadeAnimation:
                notifyAnimateToProgress(currentValue: current.floatValue, animationComplete: true)
            default: ()
            }
        }
    }
    
    private func notifyAnimateToProgress(currentValue: Float, animationComplete: Bool) {
        if progressBlock != nil {
            progressBlock?(currentValue, animationComplete)
        } else if delegate != nil {
            delegate?.didAnimateToProgress(circle: self, progress: currentValue)
        }
    }
}
