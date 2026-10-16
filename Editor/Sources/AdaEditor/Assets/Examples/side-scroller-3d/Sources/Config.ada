// Every balance number lives here. Systems and rules read Config and never hard-code values.
// World units are metres: +x is the scroll direction, +y is up, the camera looks along -z.
class Config {
    // Round phases.
    static var phaseReady = 0;
    static var phasePlaying = 1;
    static var phaseOver = 2;

    // Player.
    static var playerX = -3.0;
    static var playerStartY = 0.0;
    static var playerRadius = 0.35;
    static var gravity = 22.0;
    static var flapSpeed = 7.5;
    static var floorY = -3.0;
    static var ceilingY = 3.6;

    // Obstacles: a fixed pool that scrolls left and is reused when it leaves the screen.
    static var obstacleCount = 4;
    static var obstacleSpacing = 5.5;
    static var obstacleStartX = 4.0;
    static var obstacleHalfWidth = 0.6;
    static var gapHalfHeight = 1.3;
    static var gapRange = 1.2;
    static var scrollSpeed = 3.5;
    static var recycleX = -8.0;

    // Longest frame the simulation accepts, so a stall cannot tunnel through an obstacle.
    static var maxStep = 0.05;
}
