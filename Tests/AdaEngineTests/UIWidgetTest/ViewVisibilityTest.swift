//
//  ViewVisibilityTests.swift
//
//
//  Created by vladislav.prusakov on 11.08.2024.
//

import Testing
@testable import AdaEngine

@MainActor
struct ViewVisibilityTests {
    init() async throws {
        try Application.prepareForTest()
    }

    @Test
    func onAppearCalled_WhenVisible() {
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
        #expect(isAppeared)
    }

    @Test
    func onAppearCalledOnce_WhenVisibleAndDrawsMultipleTimes() {
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
        #expect(counter == 1)
    }

    // @Test
    // func onDisappearCalledOnce_WhenObjectWillMoveOut() {
    //     // given
    //     var isDisappeared = false
    //     var isAppeared = false
    //     @State var position: Point = Point(0, 0)

    //     let tester = ViewTester {
    //         Color.blue
    //             .frame(width: 50, height: 50)
    //             .offset(position)
    //             .onAppear {
    //                 isAppeared = true
    //             }
    //             .onChange(of: position, perform: { oldValue, newValue in
    //                 print(oldValue, newValue)
    //             })
    //             .onDisappear {
    //                 isDisappeared = true
    //             }
    //             .id("Color")
    //     }
    //     .setSize(
    //         Size(width: 200, height: 200)
    //     )
    //     .performLayout()

    //     // when
    //     tester.simulateRenderOneFrame()
    //     position = [400, 400]

    //     // Perform relayout for movement and simulate next frame
    //     tester
    //         .invalidateContent()
    //         .simulateRenderOneFrame()

    //     // then
    //     #expect(isAppeared, "Is not appeared at the first time.")
    //     #expect(isDisappeared, "Is not disappered after all.")
    // }
}
