# AdaEngine local patches to Box2D 3.2.0

- `src/joint.c`, `b2GetJointConstraintTorque`: mover and pogo joints report zero
  angular constraint torque, consistent with `b2GetJointReaction`.
  They carry linear impulses; the force getter already handles both types.
  Upstream 3.2.0 omitted these cases, so the public torque getter, threshold-event
  snapshot and `drawJointExtras` hit an assertion for the new joint types.
  Covered by `Physics2DJointBreakingTests.linearJointThresholdsHaveNoAngularImpulse`
  and the native mechanisms playground. Re-evaluate/remove this patch on the next
  vendor update if upstream includes the same fix.
