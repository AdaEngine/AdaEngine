@resource(id: "navigation.native.report", autoInsert: true)
struct NativeNavigationReport {
    @export var arrivals = 0;
    @export var state = "";
    @export var error = "";
}

@system(id: "navigation.native.control")
class NativeNavigationControl {
    @query(NavigationAgent3DComponent, NavigationTarget3DComponent) var robots;
    @resource(NativeNavigationReport) var report;
    var assigned = false;
    func update(context) {
        for (var row in robots) {
            if (!assigned) {
                row.navigationTarget3DComponent.destination = [11.0, 0.0, 6.0];
                row.navigationAgent3DComponent.maximumSpeed = 4.0;
                assigned = true;
            } else if (row.navigationAgent3DComponent.hasArrived) {
                report.arrivals = report.arrivals + 1;
                row.navigationTarget3DComponent.destination = null;
            }
            report.state = row.navigationAgent3DComponent.state;
            report.error = row.navigationAgent3DComponent.errorCode;
        }
    }
}
