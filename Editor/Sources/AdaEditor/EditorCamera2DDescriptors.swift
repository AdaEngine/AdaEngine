@_spi(AdaEngine) import AdaEngine
import Foundation

extension EditorComponentRegistry {
    static let camera2DControllerDescriptor = EditorComponentDescriptor(
        typeName: EditorBuiltInComponentType.camera2DController,
        displayName: "Camera 2D Controller",
        category: "2D",
        description: "Follows Camera Target 2D entities of a group, with dead zone, smoothing, limits, zoom, shake and pixel snapping. Keep the camera at the scene root.",
        requiredComponentTypeNames: [EditorBuiltInComponentType.camera],
        fields: [
            EditorComponentField(key: "isEnabled", label: "Enabled", kind: .bool),
            EditorComponentField(key: "targetGroup", label: "Target Group", kind: .string),
            EditorComponentField(key: "offset", label: "Offset", kind: .vector2),
            EditorComponentField(key: "smoothingTime", label: "Smoothing (s)", kind: .float),
            EditorComponentField(key: "deadZone", label: "Dead Zone", kind: .vector2),
            EditorComponentField(key: "limitsEnabled", label: "Use Limits", kind: .bool),
            EditorComponentField(key: "limitMin", label: "Limit Min", kind: .vector2),
            EditorComponentField(key: "limitMax", label: "Limit Max", kind: .vector2),
            EditorComponentField(key: "zoom", label: "Zoom", kind: .float),
            EditorComponentField(key: "minZoom", label: "Min Zoom", kind: .float),
            EditorComponentField(key: "maxZoom", label: "Max Zoom", kind: .float),
            EditorComponentField(key: "zoomSmoothingTime", label: "Zoom Smoothing (s)", kind: .float),
            EditorComponentField(key: "trauma", label: "Trauma", kind: .float),
            EditorComponentField(key: "traumaDecay", label: "Trauma Decay / s", kind: .float),
            EditorComponentField(key: "shakeMaxOffset", label: "Shake Offset", kind: .vector2),
            EditorComponentField(key: "shakeMaxRoll", label: "Shake Roll °", kind: .float),
            EditorComponentField(key: "shakeFrequency", label: "Shake Frequency", kind: .float),
            EditorComponentField(key: "snapsToPixels", label: "Snap to Pixels", kind: .bool),
        ],
        makeDefaultPayload: {
            [
                "isEnabled": .bool(true), "targetGroup": .string(""), "offset": vector(0, 0), "smoothingTime": .double(0),
                "deadZone": vector(0, 0), "limitsEnabled": .bool(false), "limitMin": vector(0, 0), "limitMax": vector(0, 0),
                "zoom": .double(1), "minZoom": .double(0.1), "maxZoom": .double(16), "zoomSmoothingTime": .double(0),
                "trauma": .double(0), "traumaDecay": .double(1), "shakeMaxOffset": vector(16, 16), "shakeMaxRoll": .double(0),
                "shakeFrequency": .double(25), "snapsToPixels": .bool(false),
            ]
        },
        decode: { payload in
            var controller = Camera2DController(
                targetGroup: payload["targetGroup"]?.stringValue ?? "",
                smoothingTime: payload["smoothingTime"]?.doubleValue.map(Float.init) ?? 0,
                zoom: payload["zoom"]?.doubleValue.map(Float.init) ?? 1,
                isEnabled: payload["isEnabled"]?.boolValue ?? true
            )
            controller.offset = payload["offset"]?.vector2Value ?? controller.offset
            controller.deadZone = payload["deadZone"]?.vector2Value ?? controller.deadZone
            controller.limitsEnabled = payload["limitsEnabled"]?.boolValue ?? false
            controller.limitMin = payload["limitMin"]?.vector2Value ?? controller.limitMin
            controller.limitMax = payload["limitMax"]?.vector2Value ?? controller.limitMax
            controller.minZoom = payload["minZoom"]?.doubleValue.map(Float.init) ?? controller.minZoom
            controller.maxZoom = payload["maxZoom"]?.doubleValue.map(Float.init) ?? controller.maxZoom
            controller.zoomSmoothingTime = payload["zoomSmoothingTime"]?.doubleValue.map(Float.init) ?? 0
            controller.trauma = payload["trauma"]?.doubleValue.map(Float.init) ?? 0
            controller.traumaDecay = payload["traumaDecay"]?.doubleValue.map(Float.init) ?? controller.traumaDecay
            controller.shakeMaxOffset = payload["shakeMaxOffset"]?.vector2Value ?? controller.shakeMaxOffset
            controller.shakeMaxRoll = payload["shakeMaxRoll"]?.doubleValue.map(Float.init) ?? 0
            controller.shakeFrequency = payload["shakeFrequency"]?.doubleValue.map(Float.init) ?? controller.shakeFrequency
            controller.snapsToPixels = payload["snapsToPixels"]?.boolValue ?? false
            return controller
        }
    )

    static let cameraTarget2DDescriptor = EditorComponentDescriptor(
        typeName: EditorBuiltInComponentType.cameraTarget2D,
        displayName: "Camera Target 2D",
        category: "2D",
        description: "Marks this entity as something a Camera 2D Controller of the same group follows. Several targets share the camera by weight.",
        requiredComponentTypeNames: [EditorBuiltInComponentType.transform],
        fields: [
            EditorComponentField(key: "group", label: "Group", kind: .string),
            EditorComponentField(key: "weight", label: "Weight", kind: .float),
        ],
        makeDefaultPayload: { ["group": .string(""), "weight": .double(1)] },
        decode: { payload in
            CameraTarget2D(group: payload["group"]?.stringValue ?? "", weight: payload["weight"]?.doubleValue.map(Float.init) ?? 1)
        }
    )

    private static func vector(_ x: Double, _ y: Double) -> EditorSceneValue {
        .array([.double(x), .double(y)])
    }
}
