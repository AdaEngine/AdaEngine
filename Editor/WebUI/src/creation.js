export function creationOptions(value = {}) {
  return {
    dimension: value?.dimension === 2 ? 2 : 3,
    players: value?.players === "multiplayer" ? "multiplayer" : "single",
  };
}
export function creationContext(value) {
  const { dimension, players } = creationOptions(value);
  return `\n[User-selected game brief]\nWorld: ${dimension}D\nPlayers: ${players === "single" ? "single-player" : "multiplayer"}\nTreat multiplayer as a requested design requirement, not an already working feature. Check available networking APIs and verify any implementation before claiming it works.\n[End game brief]`;
}
