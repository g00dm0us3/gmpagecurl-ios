//
//  Device.swift
//  GMPageCurl
//
//  Created by g00dm0us3 on 3/16/19.
//  Copyright © 2019 g00dm0us3. All rights reserved.
//

import Foundation
import Metal

class RenderingDevice {
    static var defaultDevice: MTLDevice {
        let dev = RenderingDevice()
        return dev.device
    }
    
    private var device: MTLDevice
    
    private init() {
        guard let device = MTLCreateSystemDefaultDevice() else { fatalError("Couldn't create Metal device!") }
        
        self.device = device
    }    
}
