//
//  EditorWorkspaceView.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 18.05.2026.
//

@_spi(AdaEngine) import AdaEngine

struct EditorWorkspaceView<
    LeftPanel: View,
    MainPanel: View,
    RightPanel: View,
    BottomPanel: View
>: View {

    let viewModel: EditorViewModel
    @ViewBuilder let leftPanel: () -> LeftPanel
    @ViewBuilder let mainPanel: () -> MainPanel
    @ViewBuilder let rightPanel: () -> RightPanel
    @ViewBuilder let bottomPanel: () -> BottomPanel

    @Environment(\.metrics) private var metrics

    @State private var projectSidebarWidth: Float = AdaEngineStyleLayoutSpec.projectSidebarWidth
    @State private var inspectorSidebarWidth: Float = AdaEngineStyleLayoutSpec.inspectorWidth
    @State private var outputPanelHeight: Float = 180
    @State private var projectSidebarWidthAtDragStart: Float?
    @State private var inspectorSidebarWidthAtDragStart: Float?
    @State private var outputPanelHeightAtDragStart: Float?

    var body: some View {
        GeometryReader { geometry in
            let layout = EditorWorkspaceLayout(
                size: geometry.size,
                showsLeftPanel: viewModel.showLeftPanel,
                showsRightPanel: viewModel.showRightPanel,
                showsBottomPanel: viewModel.showBottomPanel,
                requestedLeftPanelWidth: projectSidebarWidth,
                requestedRightPanelWidth: inspectorSidebarWidth,
                requestedBottomPanelHeight: outputPanelHeight,
                fallbackLeftPanelWidth: metrics.projectSidebarWidth,
                fallbackRightPanelWidth: metrics.inspectorWidth
            )

            ZStack(anchor: .topLeading) {
                let leftHandleX = layout.leftPanelWidth
                let mainPanelX = leftHandleX + (layout.showsLeftPanel ? EditorWorkspaceLayout.resizeHandleSize : 0)
                let rightHandleX = mainPanelX + layout.mainPanelWidth
                let rightPanelX = rightHandleX
                    + (layout.showsRightPanel ? EditorWorkspaceLayout.resizeHandleSize : 0)

                if layout.showsLeftPanel {
                    leftPanel()
                        .frame(width: layout.leftPanelWidth, height: layout.mainPanelHeight)

                    EditorResizeHandle(
                        axis: .horizontal,
                        onResize: { translation in
                            let startWidth = projectSidebarWidthAtDragStart ?? layout.leftPanelWidth
                            projectSidebarWidthAtDragStart = startWidth
                            let width = startWidth + translation.width
                            if width < EditorWorkspaceLayout.minimumLeftPanelWidth {
                                viewModel.showLeftPanel = false
                                projectSidebarWidth = max(startWidth, EditorWorkspaceLayout.minimumLeftPanelWidth)
                                projectSidebarWidthAtDragStart = nil
                            } else {
                                projectSidebarWidth = width
                            }
                        },
                        onResizeEnded: {
                            projectSidebarWidthAtDragStart = nil
                        }
                    )
                    .frame(height: layout.mainPanelHeight)
                    .offset(x: leftHandleX)
                    .accessibilityIdentifier("AdaEditor.Workspace.ResizeLeft")
                }

                mainPanel()
                    .frame(width: layout.mainPanelWidth, height: layout.mainPanelHeight)
                    .offset(x: mainPanelX)

                if layout.showsRightPanel {
                    EditorResizeHandle(
                        axis: .horizontal,
                        onResize: { translation in
                            let startWidth = inspectorSidebarWidthAtDragStart ?? layout.rightPanelWidth
                            inspectorSidebarWidthAtDragStart = startWidth
                            let width = startWidth - translation.width
                            if width < EditorWorkspaceLayout.minimumRightPanelWidth {
                                viewModel.showRightPanel = false
                                inspectorSidebarWidth = max(startWidth, EditorWorkspaceLayout.minimumRightPanelWidth)
                                inspectorSidebarWidthAtDragStart = nil
                            } else {
                                inspectorSidebarWidth = width
                            }
                        },
                        onResizeEnded: {
                            inspectorSidebarWidthAtDragStart = nil
                        }
                    )
                    .frame(height: layout.mainPanelHeight)
                    .offset(x: rightHandleX)
                    .accessibilityIdentifier("AdaEditor.Workspace.ResizeRight")

                    rightPanel()
                        .frame(width: layout.rightPanelWidth, height: layout.mainPanelHeight)
                        .offset(x: rightPanelX)
                }

                if layout.showsBottomPanel {
                    bottomPanel(geometry, layout: layout)
                        .offset(y: layout.mainPanelHeight)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
    }
}

extension EditorWorkspaceView {

    private func bottomPanel(_ geometry: GeometryProxy, layout: EditorWorkspaceLayout) -> some View {
        ZStack(anchor: .topLeading) {
            EditorResizeHandle(
                axis: .vertical,
                onResize: { translation in
                    resizeOutputPanel(geometry, translation: translation)
                },
                onResizeEnded: {
                    outputPanelHeightAtDragStart = nil
                }
            )
            .frame(width: geometry.size.width)
            .accessibilityIdentifier("AdaEditor.Workspace.ResizeBottom")

            bottomPanel()
                .frame(width: geometry.size.width, height: layout.bottomPanelHeight)
                .offset(y: EditorWorkspaceLayout.resizeHandleSize)
        }
        .frame(
            width: geometry.size.width,
            height: EditorWorkspaceLayout.resizeHandleSize + layout.bottomPanelHeight,
            alignment: .topLeading
        )
    }

    private func resizeOutputPanel(_ geometry: GeometryProxy, translation: Size) {
        let bottomHeight = EditorWorkspaceLayout.clampedBottomPanelHeight(outputPanelHeight, in: geometry.size)
        let startHeight = outputPanelHeightAtDragStart ?? bottomHeight
        outputPanelHeightAtDragStart = startHeight
        let height = startHeight - translation.height
        if height < EditorWorkspaceLayout.minimumBottomPanelHeight {
            viewModel.showBottomPanel = false
            outputPanelHeight = startHeight
            outputPanelHeightAtDragStart = nil
        } else {
            outputPanelHeight = EditorWorkspaceLayout.clampedBottomPanelHeight(height, in: geometry.size)
        }
    }
}

struct EditorWorkspaceLayout: Equatable {
    static let resizeHandleSize: Float = 8
    static let minimumMainPanelHeight: Float = 140
    static let minimumLeftPanelWidth: Float = 180
    static let minimumRightPanelWidth: Float = 220
    static let minimumBottomPanelHeight: Float = 72

    let leftPanelWidth: Float
    let mainPanelWidth: Float
    let rightPanelWidth: Float
    let mainPanelHeight: Float
    let bottomPanelHeight: Float

    var showsLeftPanel: Bool { leftPanelWidth > 0 }
    var showsRightPanel: Bool { rightPanelWidth > 0 }
    var showsBottomPanel: Bool { bottomPanelHeight > 0 }

    init(
        size: Size,
        showsLeftPanel: Bool,
        showsRightPanel: Bool,
        showsBottomPanel: Bool,
        requestedLeftPanelWidth: Float,
        requestedRightPanelWidth: Float,
        requestedBottomPanelHeight: Float,
        fallbackLeftPanelWidth: Float,
        fallbackRightPanelWidth: Float
    ) {
        let panelWidths = Self.panelWidths(
            availableWidth: max(0, size.width),
            showsLeftPanel: showsLeftPanel,
            showsRightPanel: showsRightPanel,
            requestedLeftPanelWidth: requestedLeftPanelWidth,
            requestedRightPanelWidth: requestedRightPanelWidth,
            fallbackLeftPanelWidth: fallbackLeftPanelWidth,
            fallbackRightPanelWidth: fallbackRightPanelWidth
        )

        leftPanelWidth = panelWidths.left
        rightPanelWidth = panelWidths.right
        let horizontalHandleWidth = Float((leftPanelWidth > 0 ? 1 : 0) + (rightPanelWidth > 0 ? 1 : 0)) * Self.resizeHandleSize
        mainPanelWidth = max(0, size.width - horizontalHandleWidth - leftPanelWidth - rightPanelWidth)

        bottomPanelHeight = showsBottomPanel
            ? Self.clampedBottomPanelHeight(requestedBottomPanelHeight, in: size)
            : 0
        let verticalHandleHeight = bottomPanelHeight > 0 ? Self.resizeHandleSize : 0
        mainPanelHeight = max(0, size.height - verticalHandleHeight - bottomPanelHeight)
    }

    static func clampedBottomPanelHeight(_ height: Float, in size: Size) -> Float {
        let maximumHeight = min(520, size.height - resizeHandleSize - minimumMainPanelHeight)
        guard maximumHeight >= minimumBottomPanelHeight, height >= minimumBottomPanelHeight else {
            return 0
        }
        return min(height, maximumHeight)
    }
}

private extension EditorWorkspaceLayout {
    static func panelWidths(
        availableWidth: Float,
        showsLeftPanel: Bool,
        showsRightPanel: Bool,
        requestedLeftPanelWidth: Float,
        requestedRightPanelWidth: Float,
        fallbackLeftPanelWidth: Float,
        fallbackRightPanelWidth: Float
    ) -> (left: Float, right: Float) {
        var left = showsLeftPanel ? resolvedPanelWidth(requestedLeftPanelWidth, fallback: fallbackLeftPanelWidth) : 0
        var right = showsRightPanel ? resolvedPanelWidth(requestedRightPanelWidth, fallback: fallbackRightPanelWidth) : 0
        if left < minimumLeftPanelWidth { left = 0 }
        if right < minimumRightPanelWidth { right = 0 }

        // Reclaim both the content and divider of a collapsed panel before sizing its siblings.
        while left > 0 || right > 0 {
            let handles = Float((left > 0 ? 1 : 0) + (right > 0 ? 1 : 0)) * resizeHandleSize
            let budget = max(0, availableWidth - handles)
            let scale = min(1, budget / (left + right))
            let fittedLeft = left * scale
            let fittedRight = right * scale
            if left > 0 && fittedLeft < minimumLeftPanelWidth {
                left = 0
            } else if right > 0 && fittedRight < minimumRightPanelWidth {
                right = 0
            } else {
                return (fittedLeft, fittedRight)
            }
        }
        return (0, 0)
    }

    static func resolvedPanelWidth(_ width: Float, fallback: Float) -> Float {
        let resolvedWidth = width.isFinite ? width : fallback
        return max(0, resolvedWidth)
    }
}
