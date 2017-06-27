//
//  DrawViewController.swift
//  MNIST_CoreML
//
//  Created by Pedro Velmovitsky on 27/06/17.
//  Copyright © 2017 velmovitsky. All rights reserved.
//

import UIKit

class DrawViewController: UIViewController {
    var lastPoint = CGPoint.zero
    var red: CGFloat = 0.0
    var green: CGFloat = 0.0
    var blue: CGFloat = 0.0
    var brushWidth: CGFloat = 10.0
    var opacity: CGFloat = 1.0
    var swiped = false

    @IBOutlet weak var tempImageView: UIImageView!
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
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
    

}
