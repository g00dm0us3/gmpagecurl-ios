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
    
    private let transformer = Input.PanGestureTransformer(maxPhi: CGFloat.pi/3, turnPageDistanceThreshold: 1.5)

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
        if(gesture.state == UIGestureRecognizer.State.ended) {
            renderer.runPlayBack()
            return
        }
        
        if gesture.state == .began {
            renderer.stopPlayBack()
        }

        let translation = gesture.translation(in: view)

        if Input.PanGestureTransformer.shouldTransform(translation) {
            let res = transformer.transform(translation: translation, in: view.bounds)
            renderer.superPhi = Float(res.phi)
            renderer.superRadius = Float(res.distanceFromRightEdge)
        }
    }
}


