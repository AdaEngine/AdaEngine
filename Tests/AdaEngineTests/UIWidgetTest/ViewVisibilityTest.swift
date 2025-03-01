//
//  ViewVisibilityTests.swift
//
//
//  Created by vladislav.prusakov on 11.08.2024.
//

import XCTest
@testable import AdaEngine

@MainActor
final class ViewVisibilityTests: XCTestCase {

    override func setUp() async throws {
        try Application.prepareForTest()
    }

    func test_OnAppearCalled_WhenVisible() {
        // given
        var isAppeared = false
        let tester = ViewTester {
            Color.blue
                .frame(width: 50, height: 50)
                .onAppear {
                    isAppeared = true
                }
        }
        .setSize(
            Size(width: 400, height: 400)
        )
        .performLayout()

        // when
        tester.simulateRenderOneFrame()

        // then
        XCTAssert(isAppeared)
    }

    func test_OnAppearCalledOnce_WhenVisibleAndDrawsMultipleTimes() {
        // given
        var counter = 0
        let tester = ViewTester {
            Color.blue
                .frame(width: 50, height: 50)
                .onAppear {
                    counter += 1
                }
        }
        .setSize(
            Size(width: 400, height: 400)
        )
        .performLayout()

        // when
        tester.simulateRenderOneFrame()
        tester.simulateRenderOneFrame()
        tester.simulateRenderOneFrame()
        tester.simulateRenderOneFrame()

        // then
        XCTAssert(counter == 1)
    }

    func test_OnDisappearCalledOnce_WhenObjectWillMoveOut() {
        // given
        var isDisappeared = false
        var isAppeared = false
        @State var position: Point = Point(0, 0)

        let tester = ViewTester {
            Color.blue
                .frame(width: 50, height: 50)
                .offset(position)
                .onAppear {
                    isAppeared = true
                }
                .onChange(of: position, perform: { oldValue, newValue in
                    print(oldValue, newValue)
                })
                .onDisappear {
                    isDisappeared = true
                }
                .id("Color")
        }
        .setSize(
            Size(width: 200, height: 200)
        )
        .performLayout()

        // when
        tester.simulateRenderOneFrame()
        position = [400, 400]

        // Perform relayout for movement and simulate next frame
        tester
            .invalidateContent()
            .simulateRenderOneFrame()

        // then
        XCTAssert(isAppeared, "Is not appeared at the first time.")
        XCTAssert(isDisappeared, "Is not disappered after all.")
    }
}
