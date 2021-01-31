//
//  SharedDevice.swift
//  GMPageCurl
//
//  Created by g00dm0us3 on 1/31/21.
//  Copyright © 2021 Homer. All rights reserved.
//

import Foundation
import Metal

struct DeviceWrapper {
    static var device: MTLDevice = {
        return MTLCreateSystemDefaultDevice()!
    }()
}
