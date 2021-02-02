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
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        textView.text = nil
    }
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        textView.frame = CGRect(x: 8, y: 8, width: rect.width - 8, height: rect.height - 8)
    }

}
