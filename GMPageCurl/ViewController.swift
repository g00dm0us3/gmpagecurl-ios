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
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Show Image", style: .plain, target: self, action: #selector(showImageTap))
    }
    
    @objc
    private func showImageTap() {
        let renderer = UIGraphicsImageRenderer(size: renderingView.frame.size)
        
        let view1 = UIView(frame: CGRect(origin: .zero, size: CGSize(width: view.bounds.width, height: view.bounds.height)))
        view1.backgroundColor = .white
        let label = UILabel(frame: CGRect(x: 100, y: 100, width: 100, height: 20))
        label.text = "Hi ya'll!"
        view1.addSubview(label)
        let image = renderer.image { (ctx) in
            view1.layer.render(in: ctx.cgContext)
        }

        let vc = ImageViewController()
        present(vc, animated: true, completion: nil)
        vc.setImage(image)
    }
    
    override func viewDidLayoutSubviews() {
        
    }
}
