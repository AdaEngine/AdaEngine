import { t } from "./localization.js";

// UI summaries only. The original workflow instructions and project content stay intact.
const summaries = {
  "ada-3d-animation": () => t("Animate 3D models and preview their motion."),
  "ada-3d-assets": () => t("Import and prepare 3D models for your game."),
  "ada-3d-materials": () =>
    t("Create materials, lighting and surface effects."),
  "ada-assets": () => t("Find, import and organize game assets."),
  "ada-autonomous-studio": () =>
    t("Create a game with an autonomous Studio workflow."),
  "ada-build-run": () => t("Build, run and diagnose your project."),
  "ada-coding": () => t("Write and update your game’s AdaScript code."),
  "ada-community-publish": () => t("Prepare a game for Community review."),
  "ada-game-builder": () => t("Turn your idea into a playable game."),
  "ada-gravity-lsp": () => t("Check AdaScript symbols and code diagnostics."),
  "ada-pixel-art": () => t("Create pixel art and animated sprites."),
  "ada-procedural-models": () =>
    t("Generate 3D models from shapes and parameters."),
  "ada-project-orientation": () =>
    t("Explore the project and choose the next step."),
  "ada-scene-authoring": () =>
    t("Create and edit scene objects and components."),
  "ada-sound-design": () => t("Add sound effects and music to your game."),
  "ada-ui-debugging": () => t("Find and fix problems in your game’s UI."),
  "ada-ui-forms": () => t("Create interactive forms and UI controls."),
  "ada-visual-verification": () => t("Check how your game looks and behaves."),
  "ada-voxel-models": () => t("Create voxel models for your game."),
  "ada-chat-ui": () => t("Show interactive controls and previews in chat."),
};
export function skillPresentation(skill) {
  const description = skill.project
    ? t("Project workflow")
    : (summaries[skill.id]?.() ?? skill.description);
  return { ...skill, description };
}
