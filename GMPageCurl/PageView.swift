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
    
    var text: String? {
        get {
            return textView.text
        }
        set {
            textView.text = newValue
        }
    }
    
    override init(frame: CGRect) {
        textView = UITextView()
        super.init(frame: frame)
        textView.isScrollEnabled = false
        textView.isEditable = false
        addSubview(textView)
        backgroundColor = .white
        textView.translatesAutoresizingMaskIntoConstraints = false
        
        textView.topAnchor.constraint(equalTo: topAnchor, constant: 8).isActive = true
        textView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8).isActive = true
        
        textView.leftAnchor.constraint(equalTo: leftAnchor, constant: 16).isActive = true
        textView.rightAnchor.constraint(equalTo: rightAnchor, constant: -16).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
