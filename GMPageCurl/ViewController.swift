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
    private var renderingView: GMPageCurlView!

    override func viewDidLoad() {
        super.viewDidLoad()

        renderingView = GMPageCurlView()
        renderingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(renderingView)

        renderingView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
        renderingView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
        renderingView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        renderingView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        renderingView.dataSource = self
        renderingView.loadPages()
    }
}

extension ViewController: GMPageCurlDatasource {
    func makePageView() -> UIView {
        return PageView(frame: .zero)
    }
    
    func updatePageView(_ view: UIView, pageIndex: UInt32, numberOfPages: UInt32) {
        let page = view as! PageView
        page.text = "Page index: \(pageIndex), page number: \(pageIndex+1)"
        page.setPageNumber(pageIndex+1, numberOfPages: numberOfPages)
    }
    
    func numberOfPages() -> UInt32 {
        return 20
    }
}
