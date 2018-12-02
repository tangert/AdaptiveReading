//
//  ViewController.swift
//  AdaptiveReading
//
//  Created by Tyler Angert on 11/10/18.
//  Copyright © 2018 Tyler Angert. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import AttributedTextView

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var eyePositionIndicatorView: UIView!
    @IBOutlet weak var eyePositionIndicatorCenterView: UIView!
    @IBOutlet weak var attrTextView: AttributedTextView!
    
    var faceNode: SCNNode = SCNNode()
    
    var eyeLNode: SCNNode = {
        let geometry = SCNCone(topRadius: 0.005, bottomRadius: 0, height: 0.2)
        geometry.radialSegmentCount = 3
        geometry.firstMaterial?.diffuse.contents = UIColor.blue
        let node = SCNNode()
        node.geometry = geometry
        node.eulerAngles.x = -.pi / 2
        node.position.z = 0.1
        let parentNode = SCNNode()
        parentNode.addChildNode(node)
        return parentNode
    }()
    
    var eyeRNode: SCNNode = {
        let geometry = SCNCone(topRadius: 0.005, bottomRadius: 0, height: 0.2)
        geometry.radialSegmentCount = 3
        geometry.firstMaterial?.diffuse.contents = UIColor.blue
        let node = SCNNode()
        node.geometry = geometry
        node.eulerAngles.x = -.pi / 2
        node.position.z = 0.1
        let parentNode = SCNNode()
        parentNode.addChildNode(node)
        return parentNode
    }()
    
    var lookAtTargetEyeLNode: SCNNode = SCNNode()
    var lookAtTargetEyeRNode: SCNNode = SCNNode()
    
    // actual physical size of iPhoneX screen
    let phoneScreenSize = CGSize(width: 0.0623908297, height: 0.135096943231532)
    
    // actual point size of iPhoneX screen
    let phoneScreenPointSize = CGSize(width: 375, height: 812)
    
    var virtualPhoneNode: SCNNode = SCNNode()
    
    var virtualScreenNode: SCNNode = {
        
        let screenGeometry = SCNPlane(width: 1, height: 1)
        screenGeometry.firstMaterial?.isDoubleSided = true
        screenGeometry.firstMaterial?.diffuse.contents = UIColor.green
        
        return SCNNode(geometry: screenGeometry)
    }()
    
    var eyeLookAtPositionXs: [CGFloat] = []
    var eyeLookAtPositionYs: [CGFloat] = []
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        // Setup Design Elements
        eyePositionIndicatorView.layer.cornerRadius = eyePositionIndicatorView.bounds.width / 2
        sceneView.layer.cornerRadius = 28
        eyePositionIndicatorCenterView.layer.cornerRadius = 4
        eyePositionIndicatorView.alpha = 0.75
        self.view.bringSubviewToFront(eyePositionIndicatorView)
        
        // Set the view's delegate
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        
        // Setup Scenegraph
        sceneView.scene.rootNode.addChildNode(faceNode)
        sceneView.scene.rootNode.addChildNode(virtualPhoneNode)
        virtualPhoneNode.addChildNode(virtualScreenNode)
        
        faceNode.addChildNode(eyeLNode)
        faceNode.addChildNode(eyeRNode)
        
        eyeLNode.addChildNode(lookAtTargetEyeLNode)
        eyeRNode.addChildNode(lookAtTargetEyeRNode)
        
        // Set LookAtTargetEye at 2 meters away from the center of eyeballs to create segment vector
        let distance: Float = 2
        lookAtTargetEyeLNode.position.z = distance
        lookAtTargetEyeRNode.position.z = distance
        
        
        // Setup the text view
        attrTextView.allowsEditingTextAttributes = true
        attrTextView.isEditable = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        guard ARFaceTrackingConfiguration.isSupported else { return }
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        
        // Run the view's session
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        faceNode.transform = node.transform
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        
        update(withFaceAnchor: faceAnchor)
    }
    
    // MARK: - update(ARFaceAnchor)
    // Where does this come from?
    let heightCompensation: CGFloat = 312
    
    func highlightContent(at position: CGPoint, in textView: AttributedTextView, with granularity: UITextGranularity) {
        
        var point = position
        let fontSize: CGFloat = 24
        let font = UIFont.systemFont(ofSize: fontSize, weight: UIFont.Weight.regular)
        let lineHeight = font.lineHeight
        
        // Eliminate scroll offset
        point.y += textView.contentOffset.y
        
        // Calculations for lines to highlight
        let lineFactor: CGFloat = 3 // amount of lines above and below the selected point that you will highlight
        let yOffset = lineHeight * lineFactor
        let startPoint = CGPoint(x: point.x, y: point.y - yOffset)
        let endPoint = CGPoint(x: point.x, y: point.y + yOffset)
        
        //get location in text from textposition at point
        guard let startClosestPos = textView.closestPosition(to: startPoint) else { return }
        guard let endClosestPos = textView.closestPosition(to: endPoint) else { return }
        
        // Get the ranges of each of the positions with the inputted granularity (word, line, or paragraph)
        guard let startingRange = textView.tokenizer.rangeEnclosingPosition(startClosestPos, with: granularity, inDirection: UITextDirection(rawValue: UITextWritingDirection.rightToLeft.rawValue)) else {
            return
        }
        
        guard let endingRange = textView.tokenizer.rangeEnclosingPosition(endClosestPos, with: granularity, inDirection: UITextDirection(rawValue: UITextWritingDirection.rightToLeft.rawValue)) else {
            return
        }
        
        // Adjust word range to include whole line and various lines above it on demand
        let highlightedOpacity: CGFloat = 0.9
        let normalOpacity: CGFloat = 0.4
        
        let normalAttrs: [NSAttributedString.Key: Any] = [.font: font,
                                                          .foregroundColor: UIColor.black.withAlphaComponent(normalOpacity)]
        
        let highlightedAttrs: [NSAttributedString.Key: Any] = [.font: font,
                                                               .foregroundColor: UIColor.black.withAlphaComponent(highlightedOpacity)]
        
        
        // Range calculations
        let wholeOffset = textView.offset(from: textView.beginningOfDocument, to: textView.endOfDocument)
        let wholeRange = NSRange(location: 0, length: wholeOffset)
        
        // Now that we have both the starting and ending lines, we can create the entire selected range and apply styles across it
        let selectedRangeStart = textView.offset(from: textView.beginningOfDocument, to: startingRange.start)
        let selectedRangeEnd = textView.offset(from: textView.beginningOfDocument, to: endingRange.end)
        
        
        // Finally, create the attributed text
        let allAttributed = NSMutableAttributedString(string: textView.text!)
        
        
        // Add the initial attributes
        allAttributed.addAttributes(normalAttrs, range: wholeRange)
        
        // Add the highlighted attributes
        allAttributed.addAttributes(highlightedAttrs, range: NSRange(location: selectedRangeStart, length: selectedRangeEnd-selectedRangeStart))
        
        // Apply the text back to the view
        // FIXME: Animate
        let transition = CATransition()
        transition.duration = 0.15
        transition.type = CATransitionType.fade
        textView.layer.add(transition, forKey: nil)
        textView.attributedText = allAttributed
    }
    
    func update(withFaceAnchor anchor: ARFaceAnchor) {
        
        eyeRNode.simdTransform = anchor.rightEyeTransform
        eyeLNode.simdTransform = anchor.leftEyeTransform
        
        DispatchQueue.main.async {
            
            // Initialize the look at points
            var eyeLLookAt = CGPoint()
            var eyeRLookAt = CGPoint()
            
            // Perform the hit tests.
            let phoneScreenEyeRHitTestResults = self.virtualPhoneNode.hitTestWithSegment(from: self.lookAtTargetEyeRNode.worldPosition, to: self.eyeRNode.worldPosition, options: nil)
            let phoneScreenEyeLHitTestResults = self.virtualPhoneNode.hitTestWithSegment(from: self.lookAtTargetEyeLNode.worldPosition, to: self.eyeLNode.worldPosition, options: nil)
            
            
            // Iterate through the hit test results and assign the X/Y coordinates for each eye.
            for result in phoneScreenEyeRHitTestResults {
                eyeRLookAt.x = CGFloat(result.localCoordinates.x) / (self.phoneScreenSize.width / 2) * self.phoneScreenPointSize.width
                eyeRLookAt.y = CGFloat(result.localCoordinates.y) / (self.phoneScreenSize.height / 2) * self.phoneScreenPointSize.height + self.heightCompensation
            }
            
            for result in phoneScreenEyeLHitTestResults {
                eyeLLookAt.x = CGFloat(result.localCoordinates.x) / (self.phoneScreenSize.width / 2) * self.phoneScreenPointSize.width
                eyeLLookAt.y = CGFloat(result.localCoordinates.y) / (self.phoneScreenSize.height / 2) * self.phoneScreenPointSize.height + self.heightCompensation
            }
            
            // Add the latest position and keep up to some recent position to smooth with.
            let smoothThresholdNumber = 10
            
            self.eyeLookAtPositionXs.append((eyeRLookAt.x + eyeLLookAt.x) / 2)
            self.eyeLookAtPositionYs.append(-(eyeRLookAt.y + eyeLLookAt.y) / 2)
            self.eyeLookAtPositionXs = Array(self.eyeLookAtPositionXs.suffix(smoothThresholdNumber))
            self.eyeLookAtPositionYs = Array(self.eyeLookAtPositionYs.suffix(smoothThresholdNumber))
            
            let smoothEyeLookAtPositionX = self.eyeLookAtPositionXs.average!
            let smoothEyeLookAtPositionY = self.eyeLookAtPositionYs.average!
            
            // Calculate distance of the eyes to the camera
            let distanceL = self.eyeLNode.worldPosition - SCNVector3Zero
            let distanceR = self.eyeRNode.worldPosition - SCNVector3Zero
            //            let distance = (distanceL.length() + distanceR.length())/2
            
            let xOffset: CGFloat = self.phoneScreenPointSize.width/2
            let yOffset: CGFloat = self.phoneScreenPointSize.height/2
            
            let adjustedX = CGFloat(round(smoothEyeLookAtPositionX + xOffset))
            let adjustedY = CGFloat(round(smoothEyeLookAtPositionY + yOffset))
            let eyePoint = CGPoint(x: adjustedX, y: adjustedY)
            
            // For some reason the position is off
            var indicatorX = adjustedX - xOffset
            //            if adjustedX < self.phoneScreenPointSize.width/2 {
            //                indicatorX -= xOffset
            //            }
            
            // Update UI
            self.eyePositionIndicatorView.transform = CGAffineTransform(translationX: indicatorX - self.eyePositionIndicatorView.bounds.width/2, y: adjustedY - yOffset)
            self.highlightContent(at: eyePoint, in: self.attrTextView, with: .line)
        }
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        virtualPhoneNode.transform = (sceneView.pointOfView?.transform)!
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        faceNode.transform = node.transform
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        update(withFaceAnchor: faceAnchor)
    }
}
