import assert from 'node:assert/strict'
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import path from 'node:path'
import { spawnSync } from 'node:child_process'
import { fileURLToPath } from 'node:url'
import test from 'node:test'

const scriptPath = fileURLToPath(new URL('../build-website-demos.mjs', import.meta.url))

test('generates metadata and previews for website demos', () => {
  const fixtureDirectory = mkdtempSync(path.join(tmpdir(), 'adaengine-website-demos-test-'))
  const outputDirectory = path.join(fixtureDirectory, 'output')

  try {
    mkdirSync(path.join(fixtureDirectory, 'Demos', 'UI'), { recursive: true })
    mkdirSync(path.join(fixtureDirectory, 'Demos', 'Games'), { recursive: true })
    mkdirSync(path.join(fixtureDirectory, 'WebsiteDemos', 'Previews'), { recursive: true })
    writeFileSync(
      path.join(fixtureDirectory, 'Package.swift'),
      `
let targets = [
    .exampleTarget(name: "CustomPreviewExample", path: "UI"),
    .exampleTarget(name: "GeneratedPreviewExample", path: "Games"),
]
`,
    )
    writeFileSync(
      path.join(fixtureDirectory, 'Demos', 'UI', 'CustomPreviewExample.swift'),
      '/// Demo description: A deliberately curated demo description.\nstruct CustomPreviewExample {}\n',
    )
    writeFileSync(
      path.join(fixtureDirectory, 'Demos', 'Games', 'GeneratedPreviewExample.swift'),
      'struct GeneratedPreviewExample {}\n',
    )
    writeFileSync(
      path.join(fixtureDirectory, 'WebsiteDemos', 'metadata.json'),
      `${JSON.stringify({
        schemaVersion: 1,
        demos: {
          CustomPreviewExample: {
            description: 'A curated catalog description.',
            keywords: ['UI', 'Cards'],
          },
        },
      }, null, 2)}\n`,
    )
    writeFileSync(
      path.join(fixtureDirectory, 'WebsiteDemos', 'Previews', 'CustomPreviewExample.svg'),
      '<svg xmlns="http://www.w3.org/2000/svg"><text>custom preview</text></svg>\n',
    )

    const result = spawnSync(
      process.execPath,
      [scriptPath, '--package-dir', fixtureDirectory, '--output', outputDirectory, '--skip-build', '--replace-manifest'],
      { encoding: 'utf8' },
    )
    assert.equal(result.status, 0, result.stderr)

    const customDirectory = path.join(outputDirectory, 'custom-preview-example')
    const generatedDirectory = path.join(outputDirectory, 'generated-preview-example')
    const customMetadata = readJSON(path.join(customDirectory, 'metadata.json'))
    const generatedMetadata = readJSON(path.join(generatedDirectory, 'metadata.json'))
    const manifest = readJSON(path.join(outputDirectory, 'manifest.json'))

    assert.equal(customMetadata.description, 'A curated catalog description.')
    assert.deepEqual(customMetadata.keywords, ['UI', 'Cards'])
    assert.equal(customMetadata.preview, 'preview.svg')
    assert.equal(customMetadata.previewKind, 'custom')
    assert.equal(customMetadata.previewAlt, 'Custom Preview Example preview')
    assert.equal(customMetadata.hasBuild, false)
    assert.match(readFileSync(path.join(customDirectory, 'preview.svg'), 'utf8'), /custom preview/)

    assert.equal(generatedMetadata.preview, 'preview.svg')
    assert.equal(generatedMetadata.previewKind, 'generated')
    assert.match(generatedMetadata.description, /AdaEngine demo/)
    assert.deepEqual(generatedMetadata.keywords, ['Games', 'AdaEngine', 'WebAssembly'])
    assert.match(readFileSync(path.join(generatedDirectory, 'preview.svg'), 'utf8'), /Generated Preview Example/)

    const generatedManifestEntry = manifest.demos.find((demo) => demo.product === 'GeneratedPreviewExample')
    assert.equal(generatedManifestEntry.metadata, 'demos/generated-preview-example/metadata.json')
    assert.equal(generatedManifestEntry.preview, 'demos/generated-preview-example/preview.svg')
    assert.equal(generatedManifestEntry.previewKind, 'generated')
    assert.deepEqual(generatedManifestEntry.keywords, ['Games', 'AdaEngine', 'WebAssembly'])
    assert.equal(existsSync(path.join(generatedDirectory, 'source.swift')), true)
  } finally {
    rmSync(fixtureDirectory, { recursive: true, force: true })
  }
})

function readJSON(filePath) {
  return JSON.parse(readFileSync(filePath, 'utf8'))
}
