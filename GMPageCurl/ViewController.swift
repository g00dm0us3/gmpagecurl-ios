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

    var currentState = RenderViewStates.cylinder
    var buttonTitles = ["Cyl. View", "Box View"]

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

    @IBAction func switchView(_ sender: UIBarButtonItem) {
        currentState = currentState == .box ? .cylinder : .box
        sender.title = buttonTitles[currentState.rawValue]
        inputManager.setRenderingState(currentState)
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
        if (gesture.state == UIGestureRecognizer.State.ended) {
            inputManager.pinchGestureEnded()
            return
        }
        inputManager.pinchGestureChanged(Float(gesture.scale))
    }

    @objc
    func move(gesture: UIPanGestureRecognizer) {
        if(gesture.state == UIGestureRecognizer.State.ended) {
            inputManager.panGestureEnded()
            return
        }

        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)
        inputManager.panGestureChanged(translation, velocity: velocity)
    }
}
