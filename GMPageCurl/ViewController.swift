//
//  ViewController.swift
//  GMPageCurl
//
//  Created by g00dm0us3 on 3/15/19.
//  Copyright © 2019 g00dm0us3. All rights reserved.
//

import UIKit

/// For testing
class ViewController: UIViewController {
    private var renderingView: CurlRenderingView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        renderingView = CurlRenderingView(frame: CGRect.zero)
        renderingView.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .blue
        view.addSubview(renderingView)

        renderingView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
        renderingView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        renderingView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        renderingView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
    }
}
