@scriptable(id: "shadowfold.director", version: 1)
class Director {
    @export var moveX = 0.0;
    @export var moveY = 0.0;
    @export var jump = 0;
    @export var flip = 0;
    @export var transfer = 0;
    @export var restart = 0;
    @export var instruction = "Fold the light. Find the way.";
    @export var status = "01 / THE SHADOW BRIDGE";
    @res var input: ShadowPlayerInput;
    @res var progress: ShadowProgress;
    @res var pose: FoldPose;
    var loggedCheckpoint = -1;
    var loggedOuter = false;
    var loggedCompleted = false;
    var loggedJump = 0;
    var loggedFlip = 0;
    var loggedTransfer = 0;
    var loggedRestart = 0;

    func update(context) {
        if (progress.outer) moveX = 0.0;
        input.moveX = moveX;
        input.jump = jump;
        input.flip = flip;
        input.transfer = transfer;
        input.restart = restart;
        logInputChanges();
        status = "01 / THE SHADOW BRIDGE";
        instruction = "Bend the leaves until the shadow reaches the next island.";
        if (progress.checkpoint == 1) {
            status = "02 / ACROSS THE FOLD";
            instruction = "Find a new angle. Walk across the crease.";
        }
        if (progress.checkpoint >= 2) {
            status = "03 / THE OTHER SIDE";
            instruction = "Turn outside. Bring the prism into this world.";
        }
        if (progress.outer) {
            status = "OUTER SCREEN / TRANSFER PORTAL";
            instruction = "Drag the amber prism into the ring. Press Transfer, then Turn.";
        }
        if (progress.message != "") instruction = progress.message;
        if (progress.completed) {
            status = "SHADOW FOLD / COMPLETE";
            instruction = "You folded the light. You found the way.";
        }
        logProgressChanges();
    }

    func logInputChanges() {
        if (jump != loggedJump) {
            System.print("[ShadowFold.Director] Jump requested (sequence \(jump))");
            loggedJump = jump;
        }
        if (flip != loggedFlip) {
            System.print("[ShadowFold.Director] Turn requested (sequence \(flip))");
            loggedFlip = flip;
        }
        if (transfer != loggedTransfer) {
            System.print("[ShadowFold.Director] Transfer requested (sequence \(transfer))");
            loggedTransfer = transfer;
        }
        if (restart != loggedRestart) {
            System.print("[ShadowFold.Director] Reset requested (sequence \(restart))");
            loggedRestart = restart;
        }
    }

    func logProgressChanges() {
        if (progress.checkpoint != loggedCheckpoint) {
            System.print("[ShadowFold.Director] Checkpoint changed to \(progress.checkpoint)");
            loggedCheckpoint = progress.checkpoint;
        }
        if (progress.outer != loggedOuter) {
            System.print("[ShadowFold.Director] Outer screen active: \(progress.outer)");
            loggedOuter = progress.outer;
        }
        if (progress.completed != loggedCompleted) {
            System.print("[ShadowFold.Director] Completion changed to \(progress.completed)");
            loggedCompleted = progress.completed;
        }
    }
}
