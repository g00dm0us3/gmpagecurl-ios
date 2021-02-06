//
//  PageView.swift
//  GMPageCurl
//
//  Created by g00dm0us3 on 2/2/21.
//  Copyright © 2021 Homer. All rights reserved.
//

import UIKit

final class PageView: GMPageView {
    private var textView: UITextView
    private var pageNumber: UILabel
    
    var text: String? {
        get {
            return textView.text
        }
        set {
            textView.text = newValue
        }
    }
    
    func setPageNumber(_ pageNumber: UInt32, numberOfPages: UInt32) {
        self.pageNumber.text = "\(pageNumber) of \(numberOfPages)"
    }
    
    override init(frame: CGRect) {
        textView = UITextView()
        pageNumber = UILabel()
        
        super.init(frame: frame)
        textView.isScrollEnabled = false
        textView.isEditable = false
        addSubview(textView)
        addSubview(pageNumber)
        backgroundColor = .white
        textView.translatesAutoresizingMaskIntoConstraints = false
        
        pageNumber.translatesAutoresizingMaskIntoConstraints = false
        pageNumber.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16).isActive = true
        pageNumber.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        pageNumber.heightAnchor.constraint(equalToConstant: 20).isActive = true
        
        textView.topAnchor.constraint(equalTo: topAnchor, constant: 32).isActive = true
        textView.bottomAnchor.constraint(equalTo: pageNumber.topAnchor, constant: -16).isActive = true
        
        textView.leftAnchor.constraint(equalTo: leftAnchor, constant: 50).isActive = true
        textView.rightAnchor.constraint(equalTo: rightAnchor, constant: -50).isActive = true
        textView.font = UIFont.systemFont(ofSize: 24)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
