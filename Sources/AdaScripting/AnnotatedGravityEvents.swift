@_spi(Scripting) import AdaECS
import Gravity

/// A received event. `name` is the declared event name and `value` exposes its fields.
@GSExportable("AdaEvent")
final class AnnotatedGravityEventBridge: @unchecked Sendable {
    let name: String
    let value: AdaScriptNetworkValueBridge

    @GSExportableIgnore
    init(event: AdaScriptRuntimeEvent, virtualMachine: GravityVirtualMachine) {
        self.name = event.name
        self.value = AdaScriptNetworkValueBridge(values: event.fields, virtualMachine: virtualMachine)
    }

    @GSExportableIgnore
    init() {
        self.name = ""
        self.value = AdaScriptNetworkValueBridge()
    }
}

/// Sends the single event declared by `@eventWriter(Name)`.
///
/// The payload is a flat list of alternating field names and values, which keeps every
/// queued field a detached primitive: `writer.send(["amount", 5.0, "target", entity.id])`.
@GSExportable("AdaEventWriter")
final class AnnotatedGravityEventWriter: @unchecked Sendable, AdaScriptNonSendableBridge {
    @GSExportableIgnore
    private let eventName: String
    @GSExportableIgnore
    private var sender: EventsSender<AdaScriptRuntimeEvent>?
    @GSExportableIgnore
    private let reportDiagnostic: @Sendable (String) -> Void

    @GSExportableIgnore
    init(eventName: String, sender: EventsSender<AdaScriptRuntimeEvent>, reportDiagnostic: @escaping @Sendable (String) -> Void) {
        self.eventName = eventName
        self.sender = sender
        self.reportDiagnostic = reportDiagnostic
    }

    @GSExportableIgnore
    init() {
        self.eventName = ""
        self.sender = nil
        self.reportDiagnostic = { _ in }
    }

    @discardableResult
    func send(_ payload: GSValue) -> Bool {
        guard let sender else {
            reportDiagnostic("Event writer '\(eventName)' is no longer valid")
            return false
        }
        var fields: [String: ReflectedFieldValue] = [:]
        if payload.isList {
            let items = payload.toList
            guard items.count.isMultiple(of: 2) else {
                reportDiagnostic("Event '\(eventName)' payload must be alternating field names and values")
                return false
            }
            for index in stride(from: 0, to: items.count, by: 2) {
                guard items[index].isString, let value = AnnotatedGravityValueBridge.makeReflectedFieldValue(items[index + 1]) else {
                    reportDiagnostic("Event '\(eventName)' payload contains an unsupported field")
                    return false
                }
                fields[items[index].toString] = value
            }
        } else if !(payload.isNull || payload.isUndefined) {
            reportDiagnostic("Event '\(eventName)' payload must be a list")
            return false
        }
        sender.send(AdaScriptRuntimeEvent(name: eventName, fields: fields))
        return true
    }

    @GSExportableIgnore
    func invalidate() {
        sender = nil
    }
}
