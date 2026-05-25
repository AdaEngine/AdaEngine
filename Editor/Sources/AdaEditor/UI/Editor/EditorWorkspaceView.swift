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

    @State var viewModel: EditorViewModel
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
            let leftWidth = clampedPanelWidth(projectSidebarWidth, in: geometry.size, minimumWidth: 220, fallback: metrics.projectSidebarWidth)
            let rightWidth = clampedPanelWidth(inspectorSidebarWidth, in: geometry.size, minimumWidth: 220, fallback: metrics.inspectorWidth)

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    if viewModel.showLeftPanel {
                        leftPanel()
                            .frame(width: leftWidth)

                        EditorResizeHandle(
                            axis: .horizontal,
                            onResize: { translation in
                                let startWidth = projectSidebarWidthAtDragStart ?? leftWidth
                                projectSidebarWidthAtDragStart = startWidth
                                projectSidebarWidth = clampedPanelWidth(
                                    startWidth + translation.width,
                                    in: geometry.size,
                                    minimumWidth: 180,
                                    fallback: metrics.projectSidebarWidth
                                )
                            },
                            onResizeEnded: {
                                projectSidebarWidthAtDragStart = nil
                            }
                        )
                    }

                    mainPanel()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .layoutPriority(100)

                    if viewModel.showRightPanel {
                        EditorResizeHandle(
                            axis: .horizontal,
                            onResize: { translation in
                                let startWidth = inspectorSidebarWidthAtDragStart ?? rightWidth
                                inspectorSidebarWidthAtDragStart = startWidth
                                inspectorSidebarWidth = clampedPanelWidth(
                                    startWidth - translation.width,
                                    in: geometry.size,
                                    minimumWidth: 220,
                                    fallback: metrics.inspectorWidth
                                )
                            },
                            onResizeEnded: {
                                inspectorSidebarWidthAtDragStart = nil
                            }
                        )

                        Spacer()
                            .frame(width: metrics.panelSpacing)

                        rightPanel()
                            .frame(width: rightWidth)
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
                .layoutPriority(100)

                bottomPanel(geometry)
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
    }
}

extension EditorWorkspaceView {
    @ViewBuilder
    private func bottomPanel(_ geometry: GeometryProxy) -> some View {
        if viewModel.showBottomPanel {
            EditorResizeHandle(
                axis: .vertical,
                onResize: { translation in
                    resizeOutputPanel(geometry, translation: translation)
                },
                onResizeEnded: {
                    outputPanelHeightAtDragStart = nil
                }
            )

            bottomPanel()
                .frame(height: outputPanelHeight)
        }
    }

    private func clampedPanelWidth(_ width: Float, in size: Size, minimumWidth: Float, fallback: Float) -> Float {
        let visibleSidePanelCount = (viewModel.showLeftPanel ? 1 : 0) + (viewModel.showRightPanel ? 1 : 0)
        let resizeHandleWidth: Float = visibleSidePanelCount > 0 ? Float(visibleSidePanelCount) * 8 : 0
        let panelSpacingWidth = viewModel.showRightPanel ? metrics.panelSpacing : 0
        let reservedWidth = resizeHandleWidth + panelSpacingWidth + 360
        let availableWidth = max(0, size.width - reservedWidth)
        let maximumWidth = min(600, max(fallback, availableWidth))
        return max(minimumWidth, min(width, maximumWidth))
    }

    private func clampedOutputPanelHeight(_ height: Float, in size: Size) -> Float {
        let topToolbarHeight = size.height < 520 ? 46 : AdaEngineStyleLayoutSpec.topToolbarHeight
        let footerHeight = size.height < 520 ? 20 : AdaEngineStyleLayoutSpec.footerHeight
        let minimumWorkbenchHeight: Float = 140
        let verticalChromeHeight = topToolbarHeight + footerHeight + 16
        let maximumHeight = min(520, max(120, size.height - verticalChromeHeight - minimumWorkbenchHeight))
        return max(72, min(height, maximumHeight))
    }

    private func resizeOutputPanel(_ geometry: GeometryProxy, translation: Size) {
        let bottomHeight = clampedOutputPanelHeight(outputPanelHeight, in: geometry.size)
        let startHeight = outputPanelHeightAtDragStart ?? bottomHeight
        outputPanelHeightAtDragStart = startHeight
        outputPanelHeight = clampedOutputPanelHeight(startHeight - translation.height, in: geometry.size)
    }
}
