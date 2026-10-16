import AdaInput

extension TextFieldViewNode {
    /// Native editing state belongs to this caret and document version. Restarting
    /// the host discards its old Editable and invalidates queued connection replies.
    func invalidateInputComposition() {
        guard !isApplyingInputComposition else { return }
        var shouldRestart = hasNativeInputSession
        #if os(Android)
        shouldRestart = shouldRestart || isFocused
        #endif
        if shouldRestart { restartInputComposition() }
    }

    func restartInputComposition() {
        nativeInputSession?.invalidate()
        nativeInputSession = nil
        inputComposition = TextInputComposition()
        hasNativeInputSession = false
        if isFocused { owner?.window?.windowManager.textInputFocusDidChange(true) }
    }

    func applyInputComposition(_ event: TextInputEvent) {
        isApplyingInputComposition = true
        defer { isApplyingInputComposition = false }
        hasNativeInputSession = true
        nativeInputSession = event.session
        let edit = inputComposition.apply(
            event, text: text, selectionAnchor: selectionAnchor, selectionHead: selectionHead,
            insertedText: Self.normalizeInputText(event.text)
        )
        performEdit {
            let changed = self.text != edit.text || self.selectionAnchor != edit.anchor || self.selectionHead != edit.head
            self.text = edit.text
            self.selectionAnchor = edit.anchor
            self.selectionHead = edit.head
            return changed
        }
    }
}
