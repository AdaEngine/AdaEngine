/** Keep a noisy Player from pushing the current tool group out of model context. */
export function boundedRuntimeLines(
  values,
  maximumBytes = 12000,
  maximumLines = 40,
) {
  const encoder = new TextEncoder();
  const result = [];
  let remaining = maximumBytes;
  for (const value of (Array.isArray(values) ? values : [])
    .slice(-maximumLines)
    .reverse()) {
    if (remaining <= 0) break;
    let text = String(value).slice(0, 2000);
    let size = encoder.encode(text).length;
    while (size > remaining) {
      text = text.slice(0, Math.floor((text.length * remaining) / size));
      size = encoder.encode(text).length;
    }
    result.unshift(text);
    remaining -= size;
  }
  return result;
}
