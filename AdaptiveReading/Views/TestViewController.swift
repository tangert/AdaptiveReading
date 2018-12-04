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

class TestViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    
    // On screen
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var eyePositionIndicatorView: UIView!
    @IBOutlet weak var eyePositionIndicatorCenterView: UIView!
    @IBOutlet weak var attrTextView: AttributedTextView!
    
    // Nav bar
    // Activate pop up to save data after this
    @IBOutlet weak var doneButton: UIBarButtonItem!
    
    // MARK: Data export and collection
    // Main dataframe
    var df: DataFrame = DataFrame()
    
    // Participant and session information
    var done: Bool! = false
    var participantID: String!
    var highlighted: Bool!
    var textType: String!
    var testType: String!
    
    ///////////////////////////////////////
    ///////////////////////////////////////
    ///////////////////////////////////////
    ///////////////////////////////////////

    // Global text attributes
    let FONT_SIZE: CGFloat = 16
    
    // Intermediate data structures
    var eyeLookAtPositionXs: [CGFloat] = []
    var eyeLookAtPositionYs: [CGFloat] = []
    
    // MARK: ARKit nodes
    
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
    
    // blinking threshold
    // need to set this individually for each user...
    let blinkThreshold: Float = 0.35
    
    var virtualPhoneNode: SCNNode = SCNNode()
    
    var virtualScreenNode: SCNNode = {
        
        let screenGeometry = SCNPlane(width: 1, height: 1)
        screenGeometry.firstMaterial?.isDoubleSided = true
        screenGeometry.firstMaterial?.diffuse.contents = UIColor.green
        
        return SCNNode(geometry: screenGeometry)
    }()
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup DataFrame
        // Set the headers
        df.header = ["participantID", "highlighted", "testType", "textType", "timestamp", "gazeX", "gazeY", "eyeBlinkRight", "eyeBlinkLeft", "estText"]
        df.name = "participant-\(self.participantID!)-\(self.testType!)"
        
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
        let distance: Float = 1
        lookAtTargetEyeLNode.position.z = distance
        lookAtTargetEyeRNode.position.z = distance
        
        
        // Setup the text view
        attrTextView.allowsEditingTextAttributes = true
        attrTextView.isEditable = false
        attrTextView.isScrollEnabled = false
        
        // MARK: EXPERIMENTAL VARIABLE SETUP
        attrTextView.text = self.textType == "A" ? TEXT_A : TEXT_B
        attrTextView.font = UIFont.systemFont(ofSize: FONT_SIZE, weight: UIFont.Weight.regular)
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
    
    @IBAction func donePressed(_ sender: Any) {
        // Done pressed will save a CSV of the current session to the phone!
        // Avoid duplicate exports
        if !done {
            df.toCSV()
        }
        done = true
    }
    
    // MARK: Data preparation
    func generateCurrentTimeStamp () -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-hh-mm-ss-SS"
        return (formatter.string(from: Date()) as NSString) as String
    }
    
    // MARK: - ARSCNViewDelegate
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        faceNode.transform = node.transform
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        
        if !done {
            update(withFaceAnchor: faceAnchor)
        }
    }
    
    // MARK: - update(ARFaceAnchor)
    // Where does this come from?
    let heightCompensation: CGFloat = 312
    
    func highlightContent(at position: CGPoint,
                          in textView: AttributedTextView,
                          with granularity: UITextGranularity) -> String? {
        
        
        var point = position
        let font = UIFont.systemFont(ofSize: FONT_SIZE, weight: UIFont.Weight.regular)
        let lineHeight = font.lineHeight
        
        // Eliminate scroll offset
        point.y += textView.contentOffset.y
        
        // Calculations for lines to highlight
        let lineFactor: CGFloat = 4 // amount of lines above and below the selected point that you will highlight
        let yOffset = lineHeight * lineFactor
        let startPoint = CGPoint(x: point.x, y: point.y - yOffset)
        let endPoint = CGPoint(x: point.x, y: point.y + yOffset)
        
        //get location in text from textposition at point
        guard let startClosestPos = textView.closestPosition(to: startPoint) else { return nil }
        guard let endClosestPos = textView.closestPosition(to: endPoint) else { return nil }
        
        // Get the ranges of each of the positions with the inputted granularity (word, line, or paragraph)
        guard let startingRange = textView.tokenizer.rangeEnclosingPosition(startClosestPos, with: granularity, inDirection: UITextDirection(rawValue: UITextWritingDirection.rightToLeft.rawValue)) else {
            return nil
        }
        
        guard let endingRange = textView.tokenizer.rangeEnclosingPosition(endClosestPos, with: granularity, inDirection: UITextDirection(rawValue: UITextWritingDirection.rightToLeft.rawValue)) else {
            return nil
        }
        
        if self.highlighted {
            
            // Adjust word range to include whole line and various lines above it on demand
            let highlightedOpacity: CGFloat = 0.9
            let normalOpacity: CGFloat = 0.25
            
            // Create the attributes for the normal / highlighted portions of the text
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
            
            // Only change the te
                // Finally, create the attributed text
                let allAttributed = NSMutableAttributedString(string: textView.text!)
            
                // Add the initial attributes
                allAttributed.addAttributes(normalAttrs, range: wholeRange)
            
                // Add the highlighted attributes
                allAttributed.addAttributes(highlightedAttrs, range: NSRange(location: selectedRangeStart, length: selectedRangeEnd-selectedRangeStart))
            
                textView.attributedText = allAttributed
        }
        
//        textView.text(in: startingRange)!.append(textView.text(in: endingRange))
        // Figure this out
        return ""
        
    }
    
    func update(withFaceAnchor anchor: ARFaceAnchor) {
        
        // SET UP A NEW DATA ROW
        var newRow: [String:Any] = [:]
        
        let eyeBlinkRight = anchor.blendShapes[.eyeBlinkRight]?.floatValue ?? 0.0
        let eyeBlinkLeft = anchor.blendShapes[.eyeBlinkLeft]?.floatValue ?? 0.0
        let blinked = eyeBlinkRight > blinkThreshold || eyeBlinkLeft > blinkThreshold
        
        // Exit out of the update function if you notice a blink
        if(blinked) {
            return
        }
        
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
            let smoothThresholdNumber = 20
            
            self.eyeLookAtPositionXs.append((eyeRLookAt.x + eyeLLookAt.x) / 2)
            self.eyeLookAtPositionYs.append(-(eyeRLookAt.y + eyeLLookAt.y) / 2)
            self.eyeLookAtPositionXs = Array(self.eyeLookAtPositionXs.suffix(smoothThresholdNumber))
            self.eyeLookAtPositionYs = Array(self.eyeLookAtPositionYs.suffix(smoothThresholdNumber))
            
            let smoothEyeLookAtPositionX = self.eyeLookAtPositionXs.average!
            let smoothEyeLookAtPositionY = self.eyeLookAtPositionYs.average!
            
            // Calculate distance of the eyes to the camera
            let distanceL = self.eyeLNode.worldPosition - SCNVector3Zero
            let distanceR = self.eyeRNode.worldPosition - SCNVector3Zero
            let _ = (distanceL.length() + distanceR.length())/2
            
            let xOffset: CGFloat = self.phoneScreenPointSize.width/2
            let yOffset: CGFloat = self.phoneScreenPointSize.height/2
            
            let adjustedX = CGFloat(round(smoothEyeLookAtPositionX + xOffset))
            let indicatorX = adjustedX

            let adjustedY = CGFloat(round(smoothEyeLookAtPositionY + yOffset))
            let eyePoint = CGPoint(x: adjustedX, y: adjustedY)
            
            // Update UI
            self.eyePositionIndicatorView.transform = CGAffineTransform(translationX: indicatorX, y: adjustedY - yOffset)
            let estimatedText = self.highlightContent(at: eyePoint, in: self.attrTextView, with: .sentence)
            
            // Reference of columns
            // ["participantID", "highlighted", "textType", "timestamp", "gazeX", "gazeY", "eyeBlinkRight", "eyeBlinkLeft", "estText"]
            // Set the new data
            
            newRow["participantID"] = self.participantID
            newRow["highlighted"] = self.highlighted
            newRow["testType"] = self.testType
            newRow["textType"] = self.textType
            newRow["timestamp"] = self.generateCurrentTimeStamp()
            newRow["gazeX"] = adjustedX
            newRow["gazeY"] = adjustedY
            newRow["eyeBlinkRight"] = eyeBlinkRight
            newRow["eyeBlinkLeft"] = eyeBlinkLeft
            newRow["estText"] = estimatedText
            
            // Add the row to the data frame
            self.df.addRow(row: newRow)
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
