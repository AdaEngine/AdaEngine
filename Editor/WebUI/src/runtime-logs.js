import { LocalizedError } from "./localization.js";
/** Reconcile AdaPlayer's bounded log snapshots, including repeated messages and rollover. */
export class RuntimeLogBuffer {
  lines = [];
  previous = [];
  source = null;
  sequence = 0;

  update(snapshot, source) {
    if (
      !Array.isArray(snapshot) ||
      snapshot.some((line) => typeof line !== "string")
    )
      throw new LocalizedError("Invalid AdaPlayer log snapshot");
    if (source !== this.source) {
      this.source = source;
      this.previous = [];
    }
    let overlap = Math.min(this.previous.length, snapshot.length);
    while (
      overlap > 0 &&
      !snapshot
        .slice(0, overlap)
        .every(
          (line, index) =>
            line === this.previous[this.previous.length - overlap + index],
        )
    )
      overlap--;
    const added = snapshot.slice(overlap);
    this.previous = [...snapshot];
    if (!added.length) return false;
    this.lines = this.lines
      .concat(added.map((text) => ({ id: ++this.sequence, text })))
      .slice(-1000);
    return true;
  }

  clear() {
    // Keep the source cursor so the next poll cannot bring cleared lines back.
    this.lines = [];
  }
}
