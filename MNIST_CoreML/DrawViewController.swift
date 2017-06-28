//
//  DrawViewController.swift
//  MNIST_CoreML
//
//  Created by Pedro Velmovitsky on 27/06/17.
//  Copyright © 2017 velmovitsky. All rights reserved.
//

import UIKit
import CoreML
import Vision
import ImageIO

class DrawViewController: UIViewController {
    var lastPoint = CGPoint.zero
    var red: CGFloat = 0.0
    var green: CGFloat = 0.0
    var blue: CGFloat = 0.0
    var brushWidth: CGFloat = 10.0
    var opacity: CGFloat = 1.0
    var swiped = false
    var inputImage: CIImage!
    
    @IBOutlet weak var tempImageView: UIImageView!
    @IBOutlet weak var classificationLabel: UILabel!
    @IBOutlet weak var correctedImageView: UIImageView!
    @IBAction func takePicture(_ sender: Any) {
    UIGraphicsBeginImageContext(tempImageView.frame.size)
        tempImageView.layer.render(in: UIGraphicsGetCurrentContext()!)
        guard let img = UIGraphicsGetImageFromCurrentImageContext() else { fatalError("no image from drawing") }
        classificationLabel.text = "Analyzing image"
        guard let ciImage = CIImage(image: img)
            else { fatalError("can't create CIImage from UIImage") }
        
        let orientation = CGImagePropertyOrientation(img.imageOrientation)
        inputImage = ciImage.applyingOrientation(Int32(orientation.rawValue))
        
        // Run the rectangle detector, which upon completion runs the ML classifier.
        let handler = VNImageRequestHandler(ciImage: ciImage, orientation: Int32(orientation.rawValue))
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                try handler.perform([self.rectanglesRequest])
            } catch {
                print(error)
            }
        }
        
        
        UIGraphicsEndImageContext()
       //MARK: Uncomment this code to save photo to photo album
       // UIImageWriteToSavedPhotosAlbum(img!, nil, nil, nil)
        
    }
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        tempImageView.layer.borderWidth = 1
        tempImageView.layer.borderColor = UIColor(red:222/255.0, green:225/255.0, blue:227/255.0, alpha: 1.0).cgColor
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        swiped = false
        if let touch = touches.first as? UITouch {
            lastPoint = touch.location(in: self.view)
        }
    }
    
    // Allow the drawing of lines in the image view
    func drawLineFrom(fromPoint: CGPoint, toPoint: CGPoint) {
        
        UIGraphicsBeginImageContext(view.frame.size)
        let context = UIGraphicsGetCurrentContext()
        tempImageView.image?.draw(in: CGRect(x: 0, y: 0, width: view.frame.size.width, height: view.frame.size.height))
        
        context?.move(to: CGPoint(x: fromPoint.x, y: fromPoint.y))
        context?.addLine(to: CGPoint(x: toPoint.x,y: toPoint.y))
        
        
        context!.setLineCap(CGLineCap.round)
        context!.setLineWidth(brushWidth)
        context?.setStrokeColor(red: red, green: green, blue: blue, alpha: 1.0)
        context!.setBlendMode(CGBlendMode.normal)
        
        context!.strokePath()
        
        tempImageView.image = UIGraphicsGetImageFromCurrentImageContext()
        tempImageView.alpha = opacity
        UIGraphicsEndImageContext()
        
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        swiped = true
        if let touch = touches.first as? UITouch {
            let currentPoint = touch.location(in: view)
            drawLineFrom(fromPoint: lastPoint, toPoint: currentPoint)
            
            lastPoint = currentPoint
        }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?){
        
        if !swiped {
            // draw a single point
            drawLineFrom(fromPoint: lastPoint, toPoint: lastPoint)
        }
    }
    
    lazy var classificationRequest: VNCoreMLRequest = {
        // Load the ML model through its generated class and create a Vision request for it.
        do {
            let model = try VNCoreMLModel(for: MNISTClassifier().model)
            return VNCoreMLRequest(model: model, completionHandler: self.handleClassification)
        } catch {
            fatalError("can't load Vision ML model: \(error)")
        }
    }()
    
    func handleClassification(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNClassificationObservation]
            else { fatalError("unexpected result type from VNCoreMLRequest") }
        guard let best = observations.first
            else { fatalError("can't get best result") }
        
        DispatchQueue.main.async {
            self.classificationLabel.text = "Classification: \"\(best.identifier)\" Confidence: \(best.confidence)"
        }
    }
    
    lazy var rectanglesRequest: VNDetectRectanglesRequest = {
        return VNDetectRectanglesRequest(completionHandler: self.handleRectangles)
    }()
    
    func handleRectangles(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNRectangleObservation]
            else { fatalError("unexpected result type from VNDetectRectanglesRequest") }
        guard let detectedRectangle = observations.first else {
            DispatchQueue.main.async {
                self.classificationLabel.text = "No rectangles detected."
            }
            return
        }
        let imageSize = inputImage.extent.size
        
        // Verify detected rectangle is valid.
        let boundingBox = detectedRectangle.boundingBox.scaled(to: imageSize)
        guard inputImage.extent.contains(boundingBox)
            else { print("invalid detected rectangle"); return }
        
        // Rectify the detected image and reduce it to inverted grayscale for applying model.
        let topLeft = detectedRectangle.topLeft.scaled(to: imageSize)
        let topRight = detectedRectangle.topRight.scaled(to: imageSize)
        let bottomLeft = detectedRectangle.bottomLeft.scaled(to: imageSize)
        let bottomRight = detectedRectangle.bottomRight.scaled(to: imageSize)
        let correctedImage = inputImage
            .cropping(to: boundingBox)
            .applyingFilter("CIPerspectiveCorrection", withInputParameters: [
                "inputTopLeft": CIVector(cgPoint: topLeft),
                "inputTopRight": CIVector(cgPoint: topRight),
                "inputBottomLeft": CIVector(cgPoint: bottomLeft),
                "inputBottomRight": CIVector(cgPoint: bottomRight)
                ])
            .applyingFilter("CIColorControls", withInputParameters: [
                kCIInputSaturationKey: 0,
                kCIInputContrastKey: 32
                ])
            .applyingFilter("CIColorInvert", withInputParameters: nil)
        
        
        // Run the Core ML MNIST classifier -- results in handleClassification method
        let handler = VNImageRequestHandler(ciImage: correctedImage)
        do {
            try handler.perform([classificationRequest])
        } catch {
            print(error)
        }
    }
    

}
