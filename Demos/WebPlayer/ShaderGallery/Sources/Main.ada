@view
class ShaderGallery {
    @state var amount = 0;

    func body() {
        VStack(spacing: 16) {
            NativeView("Player.Text", font: "display", text: "SHADER LAB", size: 28);
            Text("Your texture. Your shader. Your font.").fontSize(14);
            NativeView("Player.Material", material: "poster-effect", amount: amount).frame(300, 240);
            Button("Invert colors: " + amount) {
                amount = 1 - amount;
                System.print("[ShaderGallery] amount=" + amount);
            }.padding(12).background("#cbcaffff");
            NativeView("Player.Audio", audio: "music");
        }.padding(24).background("#f7f5efff");
    }
}
