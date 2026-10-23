# AdaEngine local patches to Box2D 3.2.0

- `src/joint.c`, `b2GetJointConstraintTorque`: mover and pogo joints report zero
  angular constraint torque, consistent with `b2GetJointReaction`.
  They carry linear impulses; the force getter already handles both types.
  Upstream 3.2.0 omitted these cases, so the public torque getter, threshold-event
  snapshot and `drawJointExtras` hit an assertion for the new joint types.
  Covered by `Physics2DJointBreakingTests.linearJointThresholdsHaveNoAngularImpulse`
  and the native mechanisms playground. Re-evaluate/remove this patch on the next
  vendor update if upstream includes the same fix.

## Double world positions

`include/box2d/config.h` enables `BOX2D_DOUBLE_PRECISION` for both the native sources
and every header consumer, including Swift's importer. The exported creation symbol
is `b2CreateWorldDoublePrecision`, retaining upstream ABI mismatch protection.
Only global positions/translations become Double; local shapes, rotations and solver
velocities remain Float. AdaPhysics distinguishes these coordinate spaces explicitly.
