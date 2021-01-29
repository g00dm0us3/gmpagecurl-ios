//
//  RenderingLoop.swift
//  GMPageCurl
//
//  Created by g00dm0us3 on 3/16/19.
//  Copyright © 2019 g00dm0us3. All rights reserved.
//

import Foundation
import UIKit

class RenderingViewController: UIViewController {
    var renderer: Renderer!
    var renderingView: RenderingView!

    override func viewDidLoad() {
        super.viewDidLoad()

        renderingView = RenderingView(frame: CGRect.zero)
        renderingView.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .blue
        view.addSubview(renderingView)

        renderingView.topAnchor.constraint(equalTo: view.topAnchor, constant: 50).isActive = true
        renderingView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        renderingView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        renderingView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true

        renderer = Renderer(renderingView, underlyingView: view)
    }
}
