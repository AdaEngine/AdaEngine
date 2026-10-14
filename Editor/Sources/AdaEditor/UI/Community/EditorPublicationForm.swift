@_spi(AdaEngine) import AdaEngine
import Foundation

/// The publication editor shares its layout across phone and wider displays.
struct EditorPublicationForm: View {
    @Environment(\.theme) private var theme
    @Binding var title: String
    @Binding var description: String
    let cover: URL?
    let screenshots: [URL]
    let busy: Bool
    let message: String
    let primaryTitle: String
    let primaryEnabled: Bool
    let footerCaption: String
    let close: () -> Void
    let chooseCover: () -> Void
    let removeCover: () -> Void
    let addScreenshots: () -> Void
    let removeScreenshot: (URL) -> Void
    let primaryAction: () -> Void
    var refreshPlan: (() -> Void)?

    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width >= 720
            let padding: Float = wide ? 24 : 16
            let width = max(0, min(1024, geometry.size.width - padding * 2))
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, padding)
                    .padding(.vertical, 18)
                ScrollView(.vertical, showsIndicators: false, respectsSafeArea: false, extendsUnderNavigationBar: false) {
                    columns(width: width, wide: wide)
                        .padding(.vertical, 6)
                        .padding(.bottom, 20)
                        .frame(maxWidth: .infinity)
                }
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                .accessibilityIdentifier("AdaEditor.Mobile.Publish.Scroll")
                footer(wide: wide)
                    .padding(.horizontal, padding)
                    .padding(.vertical, 14)
                    .background(theme.editorColors.background)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .foregroundColor(theme.editorColors.text)
        .background(theme.editorColors.background)
    }

    private var header: some View {
        HStack(spacing: 12) {
            symbol("\u{E86F}", size: 22)
                .foregroundColor(theme.editorColors.blue)
                .frame(width: 44, height: 44)
                .background(RoundedRectangleShape(cornerRadius: 14).fill(theme.editorColors.blue.opacity(0.12)))
            VStack(alignment: .leading, spacing: 4) {
                Text("Publish game").font(.system(size: 23, weight: .bold))
                Text("Create your Community listing")
                    .font(.system(size: 12)).foregroundColor(theme.editorColors.muted)
            }
            Spacer(minLength: 8)
            Button(action: close) {
                symbol("\u{E5CD}", size: 22)
                    .foregroundColor(theme.editorColors.muted)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(theme.editorColors.surface))
            }
            .buttonStyle(DefaultButtonStyle())
            .disabled(busy)
            .accessibilityIdentifier("AdaEditor.Mobile.Publish.Close")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func columns(width: Float, wide: Bool) -> AnyView {
        if wide {
            let previewWidth: Float = 280
            return AnyView(HStack(alignment: .top, spacing: 20) {
                formSections.frame(width: max(0, width - previewWidth - 20))
                preview.frame(width: previewWidth)
            }.frame(width: width, alignment: .topLeading))
        }
        return AnyView(formSections.frame(width: width))
    }

    private var formSections: some View {
        VStack(spacing: 16) {
            PublicationSection(title: "Game details", symbol: "\u{E88E}") {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        label("Game title")
                        TextField("Give your game a name", text: _title)
                            .textFieldStyle(PlainTextFieldStyle())
                            .font(.system(size: 16))
                            .padding(.horizontal, 14)
                            .frame(height: 48)
                            .background(RoundedRectangleShape(cornerRadius: 12).fill(theme.editorColors.surfaceElevated))
                            .overlay { RoundedRectangleShape(cornerRadius: 12).stroke(theme.editorColors.border, lineWidth: 1).allowsHitTesting(false) }
                            .accessibilityIdentifier("AdaEditor.Mobile.Publish.Title")
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        label("Description")
                        TextEditor(text: _description, showsLineNumbers: false, showsScrollIndicators: false, wrapsLines: true)
                            .font(.system(size: 15))
                            .textEditorColors(TextEditorColors(
                                background: theme.editorColors.surfaceElevated,
                                border: .clear,
                                focusedBorder: theme.editorColors.blue,
                                gutter: .clear,
                                gutterRule: .clear,
                                currentLineBackground: .clear,
                                selection: theme.editorColors.blue.opacity(0.24)
                            ))
                            .frame(height: 128)
                            .mask(RoundedRectangleShape(cornerRadius: 12))
                            .overlay {
                                RoundedRectangleShape(cornerRadius: 12).stroke(theme.editorColors.border, lineWidth: 1).allowsHitTesting(false)
                            }
                            .overlay(anchor: .topLeading) {
                                if description.isEmpty {
                                    Text("What is your game about?")
                                        .font(.system(size: 15)).foregroundColor(theme.editorColors.muted)
                                        .padding(12).allowsHitTesting(false)
                                }
                            }
                            .accessibilityIdentifier("AdaEditor.Mobile.Publish.Description")
                        caption("Tell players what makes your game fun.")
                    }
                }
            }
            PublicationSection(title: "Artwork", symbol: "\u{E3F4}") {
                VStack(alignment: .leading, spacing: 16) {
                    coverPicker
                    HStack {
                        label("Screenshots")
                        Spacer()
                        caption("\(screenshots.count) / 5 · optional")
                    }
                    if !screenshots.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false, respectsSafeArea: false) {
                            HStack(spacing: 10) {
                                ForEach(screenshots, id: \.absoluteString) { url in
                                    screenshot(url)
                                }
                            }
                        }.frame(height: 92)
                    }
                    Button(action: addScreenshots) {
                        HStack(spacing: 8) {
                            symbol("\u{E145}", size: 20)
                            Text("Add screenshots").font(.system(size: 14, weight: .semibold))
                            Spacer()
                        }
                        .foregroundColor(theme.editorColors.blue)
                        .padding(.horizontal, 14)
                        .frame(height: 46)
                        .background(RoundedRectangleShape(cornerRadius: 12).fill(theme.editorColors.blue.opacity(0.08)))
                    }
                    .buttonStyle(DefaultButtonStyle())
                    .disabled(busy || screenshots.count >= 5)
                    .accessibilityIdentifier("AdaEditor.Mobile.Publish.Screenshots")
                }
            }
        }
        .disabled(busy)
    }

    private var coverPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                label("Cover image")
                Spacer()
                if cover != nil {
                    Button("Remove", action: removeCover)
                        .font(.system(size: 12)).foregroundColor(theme.editorColors.muted)
                        .frame(minHeight: 32)
                        .accessibilityIdentifier("AdaEditor.Mobile.Publish.RemoveCover")
                }
            }
            Button(action: chooseCover) {
                HStack(spacing: 14) {
                    PublicationCover(url: cover).frame(width: 72, height: 56).mask(RoundedRectangleShape(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 5) {
                        Text(cover == nil ? "Choose cover" : "Change cover")
                            .font(.system(size: 14, weight: .semibold)).foregroundColor(theme.editorColors.text).lineLimit(1)
                        caption("PNG or JPEG").lineLimit(1)
                    }.frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                    symbol("\u{E5CC}", size: 20).foregroundColor(theme.editorColors.muted)
                        .frame(width: 24, height: 24)
                }
                .padding(12)
                .background(RoundedRectangleShape(cornerRadius: 14).fill(theme.editorColors.surfaceElevated))
                .overlay { RoundedRectangleShape(cornerRadius: 14).stroke(theme.editorColors.border, lineWidth: 1).allowsHitTesting(false) }
            }
            .buttonStyle(DefaultButtonStyle())
            .accessibilityIdentifier("AdaEditor.Mobile.Publish.Cover")
            caption("Images up to 5 MB each.")
        }
    }

    private func screenshot(_ url: URL) -> some View {
        VStack(spacing: 4) {
            PublicationCover(url: url).frame(width: 96, height: 64).mask(RoundedRectangleShape(cornerRadius: 10))
            Button("Remove") { removeScreenshot(url) }
                .font(.system(size: 11)).foregroundColor(theme.editorColors.muted)
                .frame(width: 96, height: 24)
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 6) {
                symbol("\u{E417}", size: 16)
                Text("LISTING PREVIEW").font(.system(size: 11, weight: .semibold))
            }.foregroundColor(theme.editorColors.muted)
            VStack(alignment: .leading, spacing: 0) {
                PublicationCover(url: cover).frame(height: 164).frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 10) {
                    Text(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Your game" : title)
                        .font(.system(size: 19, weight: .bold)).lineLimit(2)
                    Text(description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Your game's description will appear here." : description)
                        .font(.system(size: 13)).foregroundColor(theme.editorColors.muted).lineLimit(4)
                    Text("Community").font(.system(size: 11, weight: .semibold))
                        .foregroundColor(theme.editorColors.blue)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(CapsuleShape().fill(theme.editorColors.blue.opacity(0.1)))
                }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(theme.editorColors.surface)
            .mask(RoundedRectangleShape(cornerRadius: 18))
            .overlay { RoundedRectangleShape(cornerRadius: 18).stroke(theme.editorColors.border, lineWidth: 1).allowsHitTesting(false) }
            HStack(alignment: .top, spacing: 10) {
                symbol("\u{E88E}", size: 20).foregroundColor(theme.editorColors.blue)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Community review").font(.system(size: 14, weight: .semibold))
                    caption("Your game goes live after Community review. You can update its listing with a new release.")
                }
            }.padding(4)
        }
        .accessibilityIdentifier("AdaEditor.Mobile.Publish.Preview")
    }

    private func footer(wide: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if !message.isEmpty {
                HStack(spacing: 8) {
                    symbol("\u{E88E}", size: 18).foregroundColor(theme.editorColors.blue)
                    Text(message).font(.system(size: 13)).lineLimit(3)
                }.accessibilityIdentifier("AdaEditor.Mobile.Publish.Status")
            }
            let layout = wide ? AnyLayout(HStackLayout(spacing: 20)) : AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            layout {
                VStack(alignment: .leading, spacing: 4) {
                    caption(footerCaption)
                    if let refreshPlan {
                        Button("Refresh plan", action: refreshPlan)
                            .font(.system(size: 12, weight: .semibold)).foregroundColor(theme.editorColors.blue)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                Button(action: primaryAction) {
                    HStack(spacing: 10) {
                        Text(primaryTitle).font(.system(size: 15, weight: .semibold))
                        symbol("\u{E5CC}", size: 20)
                    }
                    .foregroundColor(.white)
                    .frame(height: 48)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .background(RoundedRectangleShape(cornerRadius: 14).fill(theme.editorColors.blue))
                    .opacity(primaryEnabled ? 1 : 0.45)
                }
                .buttonStyle(DefaultButtonStyle())
                .disabled(!primaryEnabled)
                .frame(width: wide ? 240 : nil)
                .accessibilityIdentifier("AdaEditor.Mobile.Publish.Submit")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("AdaEditor.Mobile.Publish.Footer")
    }

    private func label(_ value: String) -> some View { Text(value).font(.system(size: 13, weight: .semibold)) }
    private func caption(_ value: String) -> some View { Text(value).font(.system(size: 12)).foregroundColor(theme.editorColors.muted) }
    private func symbol(_ value: String, size: Double) -> some View { Text(value).font(AdaEditorMaterialSymbolFont.font(size: size)) }
}

private struct PublicationSection<Content: View>: View {
    @Environment(\.theme) private var theme
    let title: String
    let symbol: String
    let content: Content

    init(title: String, symbol: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.symbol = symbol
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 9) {
                Text(symbol).font(AdaEditorMaterialSymbolFont.font(size: 19)).foregroundColor(theme.editorColors.blue)
                Text(title).font(.system(size: 16, weight: .semibold))
            }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangleShape(cornerRadius: 18).fill(theme.editorColors.surface))
        .overlay { RoundedRectangleShape(cornerRadius: 18).stroke(theme.editorColors.border.opacity(0.7), lineWidth: 1).allowsHitTesting(false) }
    }
}

private struct PublicationCover: View {
    @Environment(\.theme) private var theme
    let url: URL?

    var body: some View {
        ZStack {
            LinearGradient(colors: [theme.editorColors.blue.opacity(0.25), theme.editorColors.purple.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
            if let url, let image = try? Image(contentsOf: url) {
                image.resizable().scaledToFill()
            } else {
                Text("\u{E3F4}").font(AdaEditorMaterialSymbolFont.font(size: 40)).foregroundColor(theme.editorColors.blue.opacity(0.8))
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity).mask(RectangleShape())
    }
}
