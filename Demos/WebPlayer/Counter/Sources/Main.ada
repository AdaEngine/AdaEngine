@view
class PocketCounter {
    @state var count = 0;

    func body() {
        VStack(spacing: 24) {
            Text("AdaScript Pocket Counter").fontSize(28);
            Text("Repacked without rebuilding WASM").fontSize(16);
            Text("Taps: " + count).fontSize(36);
            Button("Tap me") {
                count += 1;
                System.print("[PocketCounter] taps=" + count);
            }
            .padding(20)
            .background("#cbcaffff");
        }
        .padding(32)
        .background("#f7f5efff");
    }
}
