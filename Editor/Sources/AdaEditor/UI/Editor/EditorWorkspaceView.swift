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
                fallbackRightPanelWidth: metrics.inspectorWidth,
                panelSpacing: metrics.panelSpacing
            )

            ZStack(anchor: .topLeading) {
                let leftHandleX = layout.leftPanelWidth
                let mainPanelX = leftHandleX + (viewModel.showLeftPanel ? EditorWorkspaceLayout.resizeHandleSize : 0)
                let rightHandleX = mainPanelX + layout.mainPanelWidth
                let rightPanelX = rightHandleX
                    + (viewModel.showRightPanel ? EditorWorkspaceLayout.resizeHandleSize + metrics.panelSpacing : 0)

                if viewModel.showLeftPanel {
                    leftPanel()
                        .frame(width: layout.leftPanelWidth, height: layout.mainPanelHeight)

                    EditorResizeHandle(
                        axis: .horizontal,
                        onResize: { translation in
                            let startWidth = projectSidebarWidthAtDragStart ?? layout.leftPanelWidth
                            projectSidebarWidthAtDragStart = startWidth
                            projectSidebarWidth = startWidth + translation.width
                        },
                        onResizeEnded: {
                            projectSidebarWidthAtDragStart = nil
                        }
                    )
                    .frame(height: layout.mainPanelHeight)
                    .offset(x: leftHandleX)
                }

                mainPanel()
                    .frame(width: layout.mainPanelWidth, height: layout.mainPanelHeight)
                    .offset(x: mainPanelX)

                if viewModel.showRightPanel {
                    EditorResizeHandle(
                        axis: .horizontal,
                        onResize: { translation in
                            let startWidth = inspectorSidebarWidthAtDragStart ?? layout.rightPanelWidth
                            inspectorSidebarWidthAtDragStart = startWidth
                            inspectorSidebarWidth = startWidth - translation.width
                        },
                        onResizeEnded: {
                            inspectorSidebarWidthAtDragStart = nil
                        }
                    )
                    .frame(height: layout.mainPanelHeight)
                    .offset(x: rightHandleX)

                    rightPanel()
                        .frame(width: layout.rightPanelWidth, height: layout.mainPanelHeight)
                        .offset(x: rightPanelX)
                }

                if viewModel.showBottomPanel {
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
        outputPanelHeight = EditorWorkspaceLayout.clampedBottomPanelHeight(startHeight - translation.height, in: geometry.size)
    }
}

struct EditorWorkspaceLayout: Equatable {
    static let resizeHandleSize: Float = 8
    static let minimumMainPanelWidth: Float = 360
    static let minimumMainPanelHeight: Float = 140

    let leftPanelWidth: Float
    let mainPanelWidth: Float
    let rightPanelWidth: Float
    let mainPanelHeight: Float
    let bottomPanelHeight: Float

    init(
        size: Size,
        showsLeftPanel: Bool,
        showsRightPanel: Bool,
        showsBottomPanel: Bool,
        requestedLeftPanelWidth: Float,
        requestedRightPanelWidth: Float,
        requestedBottomPanelHeight: Float,
        fallbackLeftPanelWidth: Float,
        fallbackRightPanelWidth: Float,
        panelSpacing: Float
    ) {
        let horizontalHandleWidth = Float((showsLeftPanel ? 1 : 0) + (showsRightPanel ? 1 : 0)) * Self.resizeHandleSize
        let rightPanelSpacing = showsRightPanel ? panelSpacing : 0
        let availablePanelWidth = max(0, size.width - horizontalHandleWidth - rightPanelSpacing - Self.minimumMainPanelWidth)
        let panelWidths = Self.panelWidths(
            availableWidth: availablePanelWidth,
            showsLeftPanel: showsLeftPanel,
            showsRightPanel: showsRightPanel,
            requestedLeftPanelWidth: requestedLeftPanelWidth,
            requestedRightPanelWidth: requestedRightPanelWidth,
            fallbackLeftPanelWidth: fallbackLeftPanelWidth,
            fallbackRightPanelWidth: fallbackRightPanelWidth
        )

        leftPanelWidth = panelWidths.left
        rightPanelWidth = panelWidths.right
        mainPanelWidth = max(0, size.width - horizontalHandleWidth - rightPanelSpacing - leftPanelWidth - rightPanelWidth)

        bottomPanelHeight = showsBottomPanel
            ? Self.clampedBottomPanelHeight(requestedBottomPanelHeight, in: size)
            : 0
        let verticalHandleHeight = showsBottomPanel ? Self.resizeHandleSize : 0
        mainPanelHeight = max(0, size.height - verticalHandleHeight - bottomPanelHeight)
    }

    static func clampedBottomPanelHeight(_ height: Float, in size: Size) -> Float {
        let maximumHeight = min(520, max(72, size.height - resizeHandleSize - minimumMainPanelHeight))
        return max(72, min(height, maximumHeight))
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
        let minimumLeftWidth: Float = showsLeftPanel ? 180 : 0
        let minimumRightWidth: Float = showsRightPanel ? 220 : 0
        let desiredLeftWidth = showsLeftPanel
            ? clampedPanelWidth(requestedLeftPanelWidth, fallback: fallbackLeftPanelWidth, minimum: minimumLeftWidth)
            : 0
        let desiredRightWidth = showsRightPanel
            ? clampedPanelWidth(requestedRightPanelWidth, fallback: fallbackRightPanelWidth, minimum: minimumRightWidth)
            : 0
        let desiredTotal = desiredLeftWidth + desiredRightWidth

        guard desiredTotal > availableWidth else {
            return (desiredLeftWidth, desiredRightWidth)
        }

        guard availableWidth >= minimumLeftWidth + minimumRightWidth else {
            guard desiredTotal > 0 else {
                return (0, 0)
            }
            return (
                availableWidth * desiredLeftWidth / desiredTotal,
                availableWidth * desiredRightWidth / desiredTotal
            )
        }

        let leftFlexibleWidth = desiredLeftWidth - minimumLeftWidth
        let rightFlexibleWidth = desiredRightWidth - minimumRightWidth
        let totalFlexibleWidth = leftFlexibleWidth + rightFlexibleWidth
        guard totalFlexibleWidth > 0 else {
            return (desiredLeftWidth, desiredRightWidth)
        }

        let availableFlexibleWidth = availableWidth - minimumLeftWidth - minimumRightWidth
        return (
            minimumLeftWidth + availableFlexibleWidth * leftFlexibleWidth / totalFlexibleWidth,
            minimumRightWidth + availableFlexibleWidth * rightFlexibleWidth / totalFlexibleWidth
        )
    }

    static func clampedPanelWidth(_ width: Float, fallback: Float, minimum: Float) -> Float {
        let resolvedWidth = width.isFinite ? width : fallback
        return max(minimum, min(resolvedWidth, 600))
    }
}
