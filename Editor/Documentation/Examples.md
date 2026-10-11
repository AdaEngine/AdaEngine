# Examples in the Studio HUB

The HUB's Samples section reads the official [AdaExamples catalog](https://github.com/AdaEngine/AdaExamples/blob/main/catalog.json).
It lists focused examples and complete sample games with descriptions and searchable language, genre, feature and platform tags.

Choose a project and **Download example**, then select a destination folder. Studio
creates a separate editable copy and opens it through its normal project loader.
An existing folder is never overwritten. Swift projects require the standalone
Studio distribution. Immersive Garden requires Xcode and visionOS 26 to run.

Catalog and project files come from the same pinned GitHub commit. Downloads omit
build output, Git data and editor workspace state, preserve executable scripts,
and reject symbolic links, incomplete files, unsupported tree entries and excessive
sizes. The project is staged beside the destination and moved into place only after
all files and `.ada/project.json` have been received. A failed download removes its
staging folder and displays a retryable error in the HUB.

For local development, launch Studio with `ADAEXAMPLES_PATH` set to an AdaExamples
checkout. This uses the same catalog and project materialization path while avoiding
network requests. Distribution builds use GitHub when this override is absent.

Games belong in AdaExamples's `Samples`; focused projects belong in `Examples`.
The engine package retains technical QA executables and independent regression
fixtures, rather than depending on a neighboring examples checkout for its tests.
Release ZIP archives are built by AdaExamples's `scripts/package_catalog.py`.
Adding local catalog items does not publish them: commit and push AdaExamples to
make those items available to installed Studio distributions.
