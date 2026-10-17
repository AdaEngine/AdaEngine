// Navigation runs in the engine. This script chooses goals and reads the agent's state.
@system(id: "navigation.demo.patrol")
class RobotPatrol {
    @query(NavigationAgent3DComponent, NavigationTarget3DComponent, NavigationDemoPatrolComponent) var robots;
    var goals = [[8.0, 0.0, 4.0], [-8.0, 0.0, 5.0], [8.0, 0.0, -5.0], [0.0, 0.0, 5.0]];

    func update(context) {
        for (var row in robots) {
            if (!row.navigationDemoPatrolComponent.enabled) { continue; }
            if (row.navigationAgent3DComponent.hasArrived) {
                row.navigationDemoPatrolComponent.completedGoals = row.navigationDemoPatrolComponent.completedGoals + 1;
                row.navigationTarget3DComponent.destination = null;
            }
            if (row.navigationTarget3DComponent.destination == null) {
                var next = row.navigationDemoPatrolComponent.completedGoals % 4;
                row.navigationTarget3DComponent.destination = goals[next];
            }
        }
    }
}
