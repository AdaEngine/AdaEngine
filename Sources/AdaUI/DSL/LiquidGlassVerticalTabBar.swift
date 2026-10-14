import AdaUtils

@MainActor
struct LiquidGlassVerticalTabBar: View {
    let configuration: TabViewStyleConfiguration
    let style: LiquidGlassTabBarStyle

    private var tabs: [ConfigurationTab] { configuration.tabs.filter { $0.placement == .bar } }
    private var floatingTabs: [ConfigurationTab] { configuration.tabs.filter { $0.placement == .floating } }
    private typealias ConfigurationTab = TabViewStyleConfiguration.Tab

    var preferredHeight: Float {
        let barHeight: Float = tabs.isEmpty ? 0 : Float(tabs.count) * 48 + 8
        let groupCount = (tabs.isEmpty ? 0 : 1) + floatingTabs.count
        return barHeight + Float(floatingTabs.count) * 44 + Float(max(0, groupCount - 1)) * 12
    }

    var body: some View {
        VStack(spacing: 12) {
            if !tabs.isEmpty {
                VStack(spacing: 4) {
                    ForEach(tabs) { tab in tabButton(tab, floating: false) }
                }
                .padding(6)
                .background(CapsuleShape().fill(style.backgroundColor))
                .glassEffect(.regular.tint(Color.white.opacity(0.035)), in: .capsule)
                .overlay {
                    CapsuleShape().stroke(style.borderColor, lineWidth: 1).allowsHitTesting(false)
                }
            }
            ForEach(floatingTabs) { tab in tabButton(tab, floating: true) }
        }
    }

    private func tabButton(_ tab: ConfigurationTab, floating: Bool) -> some View {
        Button(action: tab.action) {
            ZStack {
                if let label = tab.label, let symbol = style.symbols[label] {
                    Text(symbol).font(style.symbolFont)
                } else if let image = tab.image {
                    image.frame(width: 22, height: 22)
                } else if let label = tab.label {
                    Text(label).font(style.labelFont).lineLimit(1)
                }
            }
            .foregroundColor(tab.isSelected ? style.selectedColor : style.unselectedColor)
            .frame(width: 44, height: 44)
            .background(CapsuleShape().fill(tab.isSelected ? style.borderColor.opacity(0.65) : .clear))
        }
        .buttonStyle(DefaultButtonStyle())
        .accessibilityIdentifier(floating ? "AdaUI.TabView.Floating.\(tab.id)" : "AdaUI.TabView.Tab.\(tab.id)")
    }
}
