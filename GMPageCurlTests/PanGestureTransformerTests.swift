//
//  PanGestureTransformerTests.swift
//  GMPageCurlTests
//
//  Created by g00dm0us3 on 1/31/21.
//  Copyright © 2021 Homer. All rights reserved.
//

import XCTest

class PanGestureTransformerTests: XCTestCase {
    func testDistanceTransform() throws {
        let transformer = Input.PanGestureTransformer(maxPhi: CGFloat.pi/2, turnPageDistanceThreshold: 1.5)
        let maxX = CGFloat(100)
        let rect = CGRect(origin: .zero, size: CGSize(width: maxX, height: maxX))

        var val = transformer.transform(translation: CGPoint(x: -maxX, y: 0), in: rect)
        XCTAssertEqual(val.distanceFromRightEdge, 1.5, "Should be distance threshold")

        val = transformer.transform(translation: CGPoint(x: maxX, y: 0), in: rect)
        XCTAssertEqual(val.distanceFromRightEdge, 0, "Should be distance threshold")
        
        val = transformer.transform(translation: CGPoint(x: maxX/2, y: 0), in: rect)
        XCTAssertEqual(val.distanceFromRightEdge, 1, "Should be distance threshold")
        
        val = transformer.transform(translation: CGPoint(x: -maxX/2, y: 0), in: rect)
        XCTAssertEqual(val.distanceFromRightEdge, 1, "Should be distance threshold")
    }
}
