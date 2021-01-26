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
    var cadDisplayLink: CADisplayLink!
    var renderingView: RenderingView!
    
    private var innerInputManager: InputManager = RenderingTestInputManager()
    var inputManager: InputManager {
        return innerInputManager
    }

    init() {
        super.init(nibName: nil, bundle: nil)
        renderer = Renderer(inputManager: inputManager)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        renderer = Renderer(inputManager: inputManager)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        renderingView = RenderingView(frame: CGRect.zero)
        renderingView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(renderingView)

        renderingView.topAnchor.constraint(equalTo: view.topAnchor, constant: 50).isActive = true
        renderingView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        renderingView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        renderingView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true

        cadDisplayLink = CADisplayLink(target: self, selector: #selector(redraw))
        cadDisplayLink.add(to: RunLoop.main, forMode: RunLoop.Mode.default)
    }

    @objc
    func redraw() {
        guard let mtlLayer = renderingView.layer as? CAMetalLayer else { fatalError("This should be rendering layer!") }
        renderer.render(in: mtlLayer)
    }
}
