//
//  ViewController.swift
//  GMPageCurl
//
//  Created by g00dm0us3 on 3/15/19.
//  Copyright © 2019 g00dm0us3. All rights reserved.
//

import UIKit
import Metal

class ViewController: RenderingViewController {

    var gestureRecognizer: UIPanGestureRecognizer!
    override func viewDidLoad() {
        super.viewDidLoad()
        gestureRecognizer = UIPanGestureRecognizer.init(target: self, action: #selector(move))
        gestureRecognizer.minimumNumberOfTouches = 1;
        gestureRecognizer.maximumNumberOfTouches = 1;
        gestureRecognizer.cancelsTouchesInView = false;
        view.addGestureRecognizer(gestureRecognizer)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>,
                      with event: UIEvent?) {
        let touch = touches.first
        //todo: render - true, on touches began
        if touch != nil {
            
            //model.replaying = false
            //model.firstTouch = touch!.preciseLocation(in: view)
            //model.displacement = Float(model.firstTouch.x / 325.0);
            //model.lastTouch = touch!.preciseLocation(in: view)
        }
        
        
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        //model.replaying = true
        
    }
    
    /*override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        model.replaying = true
        model.lastTouch = CGPoint.zero
        model.firstTouch = CGPoint.zero
    }*/
    
    @objc
    func move(gesture: UIPanGestureRecognizer) {
        if(gesture.state == UIGestureRecognizer.State.ended){
            return
        }
        
        let translation = gesture.translation(in: view)
        //model.translation = translation
    }
}

