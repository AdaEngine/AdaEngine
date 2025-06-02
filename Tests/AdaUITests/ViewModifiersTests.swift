//
//  ViewModifiersTests.swift
//
//
//  Created by vladislav.prusakov on 12.08.2024.
//

import Testing
@testable import AdaUI
@testable import AdaPlatform
import AdaInput

@MainActor
struct ViewModifiersTests {

    init() async throws {
        try Application.prepareForTest()
    }

//    @Test
//    func onAppearCalled_WhenVisible() {
//        // given
//        var isChanged = false
//        let tester = ViewTester {
//            MutableViewWithState(state: true) { isAppeared in
//                Color.blue
//                    .onChange(of: isAppeared.wrappedValue) { oldValue, newValue in
//                        isChanged = true
//                    }
//                    .onAppear {
//                        isAppeared.wrappedValue = true
//                    }
//            }
//        }
//        .setSize(
//            Size(width: 400, height: 400)
//        )
//        .performLayout()
//
//        // when
//        tester.simulateRenderOneFrame()
//            .invalidateContent()
//
//        // then
//        #expect(isChanged)
//    }
}

struct MutableViewWithState<T, Content: View>: View {
    @State var state: T
    @ViewBuilder var content: (Binding<T>) -> Content

    var body: some View {
        content(self.$state)
    }
}
