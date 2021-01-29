//
//  ViewController.swift
//  GMPageCurl
//
//  Created by g00dm0us3 on 3/15/19.
//  Copyright © 2019 g00dm0us3. All rights reserved.
//

import UIKit
import Metal

final class ViewController: RenderingViewController {

    var gestureRecognizer: UIPanGestureRecognizer!
    var pinchGestureRecognizer: UIPinchGestureRecognizer!

    override func viewDidLoad() {
        super.viewDidLoad()
        gestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(move))
        gestureRecognizer.minimumNumberOfTouches = 1
        gestureRecognizer.maximumNumberOfTouches = 1
        gestureRecognizer.cancelsTouchesInView = false
        view.addGestureRecognizer(gestureRecognizer)

        pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(pinch))
        view.addGestureRecognizer(pinchGestureRecognizer)
    }

    override func touchesBegan(_ touches: Set<UITouch>,
                      with event: UIEvent?) {
        let touch = touches.first
        //todo: render - true, on touches began
        if touch != nil {

        }

    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        //model.replaying = true

    }

    @objc
    func pinch(gesture: UIPinchGestureRecognizer) {
        /*if (gesture.state == UIGestureRecognizer.State.ended) {
            inputManager.pinchGestureEnded()
            return
        }
        inputManager.pinchGestureChanged(Float(gesture.scale))*/
    }

    @objc
    func move(gesture: UIPanGestureRecognizer) {
        /*if(gesture.state == UIGestureRecognizer.State.ended) {
            inputManager.panGestureEnded()
            return
        }

        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)
        inputManager.panGestureChanged(translation, velocity: velocity)*/
        
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)
        
        let dot = translation.normalize().dot(CGPoint(x: 1, y: 0))
        let mul = CGFloat(translation.y < 0 ? -1 : 1)
        let rads = mul*(CGFloat.pi-acos(dot))
        //print(rads.rad2deg())
        
        if rads >= -CGFloat.pi/3 && rads <= CGFloat.pi/3 {
            renderer.superPhi = Float(rads)
        }
    }
}

extension CGFloat {
    func rad2deg() -> CGFloat {
        return (self * 180) / CGFloat.pi
    }
}

extension CGPoint {
    func length() -> CGFloat {
        return sqrt(x*x+y*y)
    }
    
    func normalize() -> CGPoint {
        return CGPoint(x: x/self.length(), y: y/self.length())
    }
    
    func dot(_ vec: CGPoint) -> CGFloat {
        return x*vec.x+y*vec.y
    }
}
