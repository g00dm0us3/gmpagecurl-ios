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
        
        var time:timeval = timeval(tv_sec: 0, tv_usec: 0)
        gettimeofday(&time, nil)
        let image = renderer.image { (ctx) in
            self.view.layer.render(in: ctx.cgContext)
        }
        var time1:timeval = timeval(tv_sec: 0, tv_usec: 0)
        gettimeofday(&time1, nil)

        print("Sec \(time1.tv_sec - time.tv_sec) msec \(Double((time1.tv_usec - time.tv_usec)) / 1000.0)")
        
        let vc = ImageViewController()
        present(vc, animated: true, completion: nil)
        vc.setImage(image)
    }
    
    override func viewDidLayoutSubviews() {
        
    }
}
