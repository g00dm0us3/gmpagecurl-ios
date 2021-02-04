//
//  GMPageCurlView.swift
//  GMPageCurl
//
//  Created by g00dm0us3 on 2/4/21.
//  Copyright © 2021 Homer. All rights reserved.
//

import UIKit
import MetalKit

final class GMPageCurlView: UIView {
    private let metalPageCurlView = MetalPageCurlView()
    
    init() {
        super.init(frame: .zero)
        addSubview(extremelyTestPageView)
        
        extremelyTestPageView.frame = bounds
        extremelyTestPageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        addSubview(metalPageCurlView)
        metalPageCurlView.frame = bounds
        metalPageCurlView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        metalPageCurlView.isHidden = true
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(panHandler(gesture:)))
        addGestureRecognizer(panGesture)
    }
    
    
    @objc
    private func panHandler(gesture: UIPanGestureRecognizer) {
        guard let topSubview = subviews.last else { return }
        
        if gesture.state == .began {
            // intentially not using topSubview's frame here, since if it doesn't match the size
            // of curl view, the behavior is pretty much undefined (book has non-uniform page sizes)
            let imageRenderer = UIGraphicsImageRenderer(size: frame.size)

            let image = imageRenderer.image { (ctx) in
                self.layer.render(in: ctx.cgContext)
            }

            //removeGestureRecognizer(gesture)
            isUserInteractionEnabled = false
            
            metalPageCurlView.beginFlip(with: image.cgImage!)
        }
        
        if gesture.state == .changed {
            let translation = gesture.translation(in: self)
            metalPageCurlView.updateFlip(translation: translation)
        }
        
        if gesture.state == .ended {
            isUserInteractionEnabled = true // only after flip back / forward animtion ends
            metalPageCurlView.endFlip()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// - TODO: replace w. call to datasource
    private lazy var extremelyTestPageView: UIView = {
        let view = UIView()
        
        view.backgroundColor = .white
        let label = UITextView()
        label.backgroundColor = .white
        label.font = UIFont.systemFont(ofSize: 14)
        label.text = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Ut vitae bibendum nisi, in laoreet leo. Curabitur pulvinar quam ac nulla volutpat, et aliquam neque vulputate. Sed mollis leo at orci faucibus pellentesque. Curabitur posuere enim non ex accumsan suscipit. Fusce ante ante, viverra at mauris id, auctor hendrerit magna. Mauris mollis ipsum ac diam vehicula, nec consequat nisl dictum. Nunc egestas lectus eget est efficitur accumsan. Aenean convallis rhoncus metus sit amet ullamcorper. Cras quis facilisis odio. Nam vestibulum efficitur auctor. Pellentesque non ullamcorper nisi. Mauris consequat, nisi nec volutpat pellentesque, diam ipsum condimentum risus, eget mattis libero elit eget mi. In eget lacinia erat. Aliquam velit lectus, dapibus eget sem ut, varius maximus ipsum. Aenean posuere semper enim sit amet finibus. Mauris quis aliquam dui, ac luctus lacus. Donec hendrerit vehicula odio ac vestibulum. Nullam ipsum metus, vestibulum eleifend molestie in, tincidunt nec est. Pellentesque euismod varius mauris, vel mattis dolor consequat ut. Sed eu risus arcu. Interdum et malesuada fames ac ante ipsum primis in faucibus. Mauris erat leo, mattis id est quis, aliquam ultricies ante. Etiam at felis ornare est luctus fringilla eget sit amet augue. Sed a ultricies nibh. Donec egestas pellentesque ullamcorper. Phasellus at dapibus tortor, et condimentum magna. Suspendisse in neque ligula. Nullam commodo in lectus in porttitor. Ut consequat magna eget semper vehicula. Sed rutrum mollis pulvinar. Sed luctus risus convallis, pharetra felis ut, sodales enim. In lacinia metus eu sem bibendum porttitor id ac augue. Donec id iaculis mauris, a tristique nibh. Nullam eget ex dictum, tempor nisl at, lacinia erat. Morbi eleifend, augue sed ultrices blandit, tortor nunc efficitur magna, ut molestie elit est vitae mi. Vestibulum vel nulla ex. Duis at laoreet dui. Mauris dapibus, velit sed cursus tincidunt, risus velit rhoncus nibh, a ultricies elit neque at libero. Vestibulum purus ligula, laoreet sed purus aliquet, facilisis gravida lorem. Cras luctus libero sed justo elementum pellentesque. Cras aliquet tellus metus, ac sodales lorem pretium non. Suspendisse vitae elementum odio. Nunc nec odio cursus, rhoncus risus ac, hendrerit ante. Pellentesque efficitur erat vel dapibus aliquam. Duis venenatis dui at luctus tincidunt. Integer vel egestas mauris, et mattis justo. Nullam ut felis purus.  Donec nisi ipsum, suscipit vitae purus in, commodo vulputate ligula. Aenean lacinia dolor quis augue rhoncus, ac dapibus justo varius. Curabitur consectetur lorem et libero rutrum dignissim. Interdum et malesuada fames ac ante ipsum primis in faucibus. Pellentesque ornare justo in gravida lobortis. Cras scelerisque, odio eu rhoncus tincidunt, orci lacus rhoncus magna, ut efficitur dui neque non felis. Nulla mattis ullamcorper bibendum."

        view.addSubview(label)
        label.frame = view.bounds
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return view
    }()
    
    private lazy var extremelyTestPageView1: UIView = {
        let view = UIView()
        view.frame = bounds
        view.backgroundColor = .white
        let label = UITextView()
        label.backgroundColor = .white
        label.font = UIFont.systemFont(ofSize: 14)
        label.text = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Ut vitae bibendum nisi, in laoreet leo. Curabitur pulvinar quam ac nulla volutpat, et aliquam neque vulputate. Sed mollis leo at orci faucibus pellentesque. Curabitur posuere enim non ex accumsan suscipit. Fusce ante ante, viverra at mauris id, auctor hendrerit magna. Mauris mollis ipsum ac diam vehicula, nec consequat nisl dictum. Nunc egestas lectus eget est efficitur accumsan. Aenean convallis rhoncus metus sit amet ullamcorper. Cras quis facilisis odio. Nam vestibulum efficitur auctor. Pellentesque non ullamcorper nisi. Mauris consequat, nisi nec volutpat pellentesque, diam ipsum condimentum risus, eget mattis libero elit eget mi. In eget lacinia erat. Aliquam velit lectus, dapibus eget sem ut, varius maximus ipsum. Aenean posuere semper enim sit amet finibus. Mauris quis aliquam dui, ac luctus lacus. Donec hendrerit vehicula odio ac vestibulum. Nullam ipsum metus, vestibulum eleifend molestie in, tincidunt nec est. Pellentesque euismod varius mauris, vel mattis dolor consequat ut. Sed eu risus arcu. Interdum et malesuada fames ac ante ipsum primis in faucibus. Mauris erat leo, mattis id est quis, aliquam ultricies ante. Etiam at felis ornare est luctus fringilla eget sit amet augue. Sed a ultricies nibh. Donec egestas pellentesque ullamcorper. Phasellus at dapibus tortor, et condimentum magna. Suspendisse in neque ligula. Nullam commodo in lectus in porttitor. Ut consequat magna eget semper vehicula. Sed rutrum mollis pulvinar. Sed luctus risus convallis, pharetra felis ut, sodales enim. In lacinia metus eu sem bibendum porttitor id ac augue. Donec id iaculis mauris, a tristique nibh. Nullam eget ex dictum, tempor nisl at, lacinia erat. Morbi eleifend, augue sed ultrices blandit, tortor nunc efficitur magna, ut molestie elit est vitae mi. Vestibulum vel nulla ex. Duis at laoreet dui. Mauris dapibus, velit sed cursus tincidunt, risus velit rhoncus nibh, a ultricies elit neque at libero. Vestibulum purus ligula, laoreet sed purus aliquet, facilisis gravida lorem. Cras luctus libero sed justo elementum pellentesque. Cras aliquet tellus metus, ac sodales lorem pretium non. Suspendisse vitae elementum odio. Nunc nec odio cursus, rhoncus risus ac, hendrerit ante. Pellentesque efficitur erat vel dapibus aliquam. Duis venenatis dui at luctus tincidunt. Integer vel egestas mauris, et mattis justo. Nullam ut felis purus.  Donec nisi ipsum, suscipit vitae purus in, commodo vulputate ligula. Aenean lacinia dolor quis augue rhoncus, ac dapibus justo varius. Curabitur consectetur lorem et libero rutrum dignissim. Interdum et malesuada fames ac ante ipsum primis in faucibus. Pellentesque ornare justo in gravida lobortis. Cras scelerisque, odio eu rhoncus tincidunt, orci lacus rhoncus magna, ut efficitur dui neque non felis. Nulla mattis ullamcorper bibendum."

        view.addSubview(label)
        label.frame = view.bounds
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return view
    }()
}
