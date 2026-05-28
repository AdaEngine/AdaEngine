#!/usr/bin/env node

import { spawnSync } from 'node:child_process'
import { cpSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url))
const defaultPackageDirectory = path.resolve(scriptDirectory, '..')

const options = parseArguments(process.argv.slice(2))
const packageDirectory = path.resolve(options.packageDirectory ?? defaultPackageDirectory)
const packageFile = path.join(packageDirectory, 'Package.swift')
const demosDirectory = path.join(packageDirectory, 'Demos')
const outputDirectory = path.resolve(options.outputDirectory ?? defaultOutputDirectory(packageDirectory))
const scratchDirectory = path.resolve(options.scratchDirectory ?? path.join(packageDirectory, '.build-web-website-demos'))
const exportWorkDirectory = path.resolve(options.exportWorkDirectory ?? path.join(packageDirectory, 'dist', '.website-demo-export-work'))

if (!existsSync(packageFile)) {
  fail(`Package.swift was not found at ${packageFile}`)
}

if (!existsSync(demosDirectory)) {
  fail(`Demos directory was not found at ${demosDirectory}`)
}

const products = discoverDemoProducts(packageFile)
  .filter((demo) => !options.only.size || options.only.has(demo.product))
  .filter((demo) => !options.skipProducts.has(demo.product))
  .sort((lhs, rhs) => lhs.tag.localeCompare(rhs.tag) || lhs.title.localeCompare(rhs.title))

if (!products.length) {
  fail(options.only.size ? `No matching demo products found for: ${[...options.only].join(', ')}` : 'No demo products were found in Package.swift')
}

if (options.list) {
  for (const demo of products) {
    console.log(`${demo.product}\t${demo.slug}\t${demo.sourcePath}`)
  }
  process.exit(0)
}

mkdirSync(outputDirectory, { recursive: true })

const commit = captureGit(['rev-parse', 'HEAD'], packageDirectory)
const failures = []
const manifest = {
  schemaVersion: 1,
  generatedAt: new Date().toISOString(),
  repository: 'AdaEngine/AdaEngine',
  commit,
  demos: [],
}

for (const demo of products) {
  const demoOutputDirectory = path.join(outputDirectory, demo.slug)
  const pluginOutputDirectory = isSubpath(demoOutputDirectory, packageDirectory)
    ? demoOutputDirectory
    : path.join(exportWorkDirectory, demo.slug)
  const sourceFile = path.join(demosDirectory, demo.tag, `${demo.product}.swift`)

  if (!existsSync(sourceFile)) {
    fail(`Demo source was not found for ${demo.product}: ${sourceFile}`)
  }

  if (!options.skipBuild) {
    rmSync(demoOutputDirectory, { recursive: true, force: true })
    rmSync(pluginOutputDirectory, { recursive: true, force: true })
    mkdirSync(demoOutputDirectory, { recursive: true })
    mkdirSync(pluginOutputDirectory, { recursive: true })
    const result = exportDemo(demo.product, pluginOutputDirectory)
    if (result.ok) {
      const verification = verifyWasmABI(demo.product, pluginOutputDirectory)
      if (verification.ok) {
        const stripResult = options.stripWasmDebug ? stripWasmDebugSections(demo.product, pluginOutputDirectory) : { ok: true }
        if (stripResult.ok && pluginOutputDirectory !== demoOutputDirectory) {
          cpSync(pluginOutputDirectory, demoOutputDirectory, { recursive: true })
        } else if (!stripResult.ok) {
          failures.push(demo.product)
          if (!options.continueOnError) {
            fail(stripResult.message)
          }
        }
      } else if (!verification.ok) {
        failures.push(demo.product)
        if (!options.continueOnError) {
          fail(verification.message)
        }
      }
    } else {
      failures.push(demo.product)
      if (!options.continueOnError) {
        fail(`Failed to export ${demo.product}`)
      }
    }
  } else {
    mkdirSync(demoOutputDirectory, { recursive: true })
  }

  const source = readFileSync(sourceFile, 'utf8')
  writeFileSync(path.join(demoOutputDirectory, 'source.swift'), source)
  writeFileSync(
    path.join(demoOutputDirectory, 'metadata.json'),
    `${JSON.stringify({
      product: demo.product,
      title: demo.title,
      tag: demo.tag,
      sourcePath: demo.sourcePath,
    }, null, 2)}\n`,
  )

  manifest.demos.push({
    product: demo.product,
    slug: demo.slug,
    title: demo.title,
    tag: demo.tag,
    tagTitle: tagTitle(demo.tag),
    description: demoDescription(demo.product, demo.tag, source),
    sourcePath: demo.sourcePath,
    source: `demos/${demo.slug}/source.swift`,
    embed: `demos/${demo.slug}/index.html`,
    hasBuild: !options.skipBuild || existsSync(path.join(demoOutputDirectory, 'index.html')),
  })
}

const finalManifest = mergeManifest(manifest, outputDirectory, options.only.size > 0 && !options.replaceManifest)
writeFileSync(path.join(outputDirectory, 'manifest.json'), `${JSON.stringify(finalManifest, null, 2)}\n`)
console.log(`Prepared ${finalManifest.demos.length} demo entries in ${outputDirectory}`)
const unexpectedFailures = failures.filter((product) => !options.allowFailures.has(product))
if (unexpectedFailures.length) {
  fail(`Failed demo exports: ${unexpectedFailures.join(', ')}`)
}
if (failures.length) {
  console.warn(`Allowed failed demo exports: ${failures.join(', ')}`)
}

function parseArguments(args) {
  const parsed = {
    allowFailures: new Set(),
    continueOnError: false,
    list: false,
    only: new Set(),
    outputDirectory: undefined,
    packageDirectory: undefined,
    skipBuild: false,
    skipProducts: new Set(),
    swiftSDK: process.env.ADAENGINE_WASM_SDK ?? 'swift-6.3.2-RELEASE_wasm',
    replaceManifest: false,
    scratchDirectory: undefined,
    exportWorkDirectory: undefined,
    stripWasmDebug: false,
  }

  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index]
    switch (argument) {
    case '--output':
      parsed.outputDirectory = requireValue(args, ++index, argument)
      break
    case '--package-dir':
      parsed.packageDirectory = requireValue(args, ++index, argument)
      break
    case '--swift-sdk':
      parsed.swiftSDK = requireValue(args, ++index, argument)
      break
    case '--scratch-path':
      parsed.scratchDirectory = requireValue(args, ++index, argument)
      break
    case '--export-work-dir':
      parsed.exportWorkDirectory = requireValue(args, ++index, argument)
      break
    case '--only':
      for (const product of requireValue(args, ++index, argument).split(',')) {
        if (product.trim()) parsed.only.add(product.trim())
      }
      break
    case '--skip-product':
    case '--skip-products':
      for (const product of requireValue(args, ++index, argument).split(',')) {
        if (product.trim()) parsed.skipProducts.add(product.trim())
      }
      break
    case '--allow-failure':
    case '--allow-failures':
      for (const product of requireValue(args, ++index, argument).split(',')) {
        if (product.trim()) parsed.allowFailures.add(product.trim())
      }
      break
    case '--continue-on-error':
      parsed.continueOnError = true
      break
    case '--replace-manifest':
      parsed.replaceManifest = true
      break
    case '--list':
      parsed.list = true
      break
    case '--skip-build':
      parsed.skipBuild = true
      break
    case '--strip-wasm-debug':
      parsed.stripWasmDebug = true
      break
    case '--help':
      printHelp()
      process.exit(0)
      break
    default:
      fail(`Unknown argument: ${argument}`)
    }
  }

  return parsed
}

function requireValue(args, index, argument) {
  const value = args[index]
  if (!value || value.startsWith('--')) {
    fail(`Missing value for ${argument}`)
  }

  return value
}

function discoverDemoProducts(packageFilePath) {
  const packageSource = readFileSync(packageFilePath, 'utf8')
  const expression = /\.exampleTarget\(\s*name:\s*"([^"]+)"\s*,\s*path:\s*"([^"]+)"/g
  const demos = []

  for (const match of packageSource.matchAll(expression)) {
    const product = match[1]
    const tag = match[2]
    demos.push({
      product,
      tag,
      title: titleFromProduct(product),
      slug: slugFor(product),
      sourcePath: `Demos/${tag}/${product}.swift`,
    })
  }

  return demos
}

function exportDemo(product, demoOutputDirectory) {
  const args = [
    'package',
    '--allow-writing-to-package-directory',
    '--allow-network-connections',
    'all',
    'export-web',
    '--product',
    product,
    '--output',
    demoOutputDirectory,
    '--scratch-path',
    scratchDirectory,
    '--release',
  ]

  if (options.swiftSDK && options.swiftSDK !== 'auto') {
    args.push('--swift-sdk', options.swiftSDK)
  }

  console.log(`Exporting ${product}...`)
  const result = spawnSync('swift', args, {
    cwd: packageDirectory,
    stdio: 'inherit',
    env: {
      ...process.env,
      ADAENGINE_WEB_EXPORT: '1',
    },
  })

  if (result.status !== 0) {
    return { ok: false }
  }

  return { ok: true }
}

function verifyWasmABI(product, demoOutputDirectory) {
  const wasmPath = path.join(demoOutputDirectory, `${product}.wasm`)
  if (!existsSync(wasmPath)) {
    return { ok: false, message: `Expected wasm was not found: ${wasmPath}` }
  }

  let exports
  try {
    const wasm = readFileSync(wasmPath)
    exports = WebAssembly.Module.exports(new WebAssembly.Module(wasm))
      .map((entry) => `${entry.kind}:${entry.name}`)
  } catch (error) {
    return { ok: false, message: `Could not inspect ${wasmPath}: ${error.message}` }
  }

  if (exports.includes('function:_start')) {
    return { ok: false, message: `${product}.wasm exports _start; JavaScriptKit expects reactor ABI` }
  }

  if (!exports.includes('function:main') && !exports.includes('function:__main_argc_argv')) {
    return { ok: false, message: `${product}.wasm does not export main or __main_argc_argv` }
  }

  return { ok: true }
}

function stripWasmDebugSections(product, demoOutputDirectory) {
  const wasmPath = path.join(demoOutputDirectory, `${product}.wasm`)
  if (!existsSync(wasmPath)) {
    return { ok: false, message: `Expected wasm was not found before stripping: ${wasmPath}` }
  }

  const objcopy = process.env.LLVM_OBJCOPY ?? 'llvm-objcopy'
  const args = [
    '--strip-debug',
    '--remove-section=name',
    wasmPath,
  ]

  console.log(`Stripping debug/name sections from ${product}.wasm...`)
  const result = spawnSync(objcopy, args, {
    cwd: packageDirectory,
    stdio: 'inherit',
  })

  if (result.error) {
    return { ok: false, message: `Failed to run ${objcopy} while stripping ${product}.wasm: ${result.error.message}` }
  }

  if (result.status !== 0) {
    return { ok: false, message: `Failed to strip debug/name sections from ${product}.wasm` }
  }

  return { ok: true }
}

function defaultOutputDirectory(packageDirectoryPath) {
  if (process.env.ADAENGINE_WEBSITE_DEMOS_DIR) {
    return process.env.ADAENGINE_WEBSITE_DEMOS_DIR
  }

  const siblingWebsiteDemos = path.resolve(packageDirectoryPath, '..', 'adawebsite', 'public', 'demos')
  if (existsSync(siblingWebsiteDemos)) {
    return siblingWebsiteDemos
  }

  return path.join(packageDirectoryPath, 'dist', 'website-demos')
}

function titleFromProduct(product) {
  return product
    .replace(/Example$/, ' Example')
    .replace(/([A-Za-z])([0-9])/g, '$1 $2')
    .replace(/([a-z])([A-Z])/g, '$1 $2')
    .replace(/2d/gi, '2D')
    .replace(/3d/gi, '3D')
}

function slugFor(product) {
  return product
    .replace(/([a-z0-9])([A-Z])/g, '$1-$2')
    .toLowerCase()
}

function tagTitle(tag) {
  if (/^2d$/i.test(tag)) return '2D'
  if (/^3d$/i.test(tag)) return '3D'
  return tag
    .replace(/[-_]/g, ' ')
    .replace(/\b\w/g, (letter) => letter.toUpperCase())
}

function demoDescription(product, tag, source) {
  const explicit = source.match(/\/\/\/\s*(?:Demo description:|Description:)\s*(.+)/i)?.[1]?.trim()
  if (explicit) return explicit

  const firstDocComment = source
    .split('\n')
    .map((line) => line.match(/^\s*\/\/\/\s*(.+)/)?.[1]?.trim())
    .find((line) => line && !line.startsWith('MARK:'))

  if (firstDocComment) return firstDocComment

  return `A ${tagTitle(tag)} AdaEngine demo built from ${product}.`
}

function captureGit(args, cwd) {
  const result = spawnSync('git', args, { cwd, encoding: 'utf8' })
  return result.status === 0 ? result.stdout.trim() : null
}

function isSubpath(child, parent) {
  const relative = path.relative(parent, child)
  return relative === '' || (!relative.startsWith('..') && !path.isAbsolute(relative))
}

function mergeManifest(newManifest, outputDirectoryPath, shouldMerge) {
  if (!shouldMerge) {
    return newManifest
  }

  const manifestPath = path.join(outputDirectoryPath, 'manifest.json')
  if (!existsSync(manifestPath)) {
    return newManifest
  }

  let existingManifest
  try {
    existingManifest = JSON.parse(readFileSync(manifestPath, 'utf8'))
  } catch {
    return newManifest
  }

  if (!Array.isArray(existingManifest.demos)) {
    return newManifest
  }

  const updates = new Map(newManifest.demos.map((demo) => [demo.product, demo]))
  const mergedDemos = existingManifest.demos.map((demo) => updates.get(demo.product) ?? demo)
  const existingProducts = new Set(existingManifest.demos.map((demo) => demo.product))
  for (const demo of newManifest.demos) {
    if (!existingProducts.has(demo.product)) {
      mergedDemos.push(demo)
    }
  }

  return {
    ...existingManifest,
    generatedAt: newManifest.generatedAt,
    repository: newManifest.repository,
    commit: newManifest.commit,
    demos: mergedDemos,
  }
}

function printHelp() {
  console.log(`
Usage:
  node scripts/build-website-demos.mjs [--output public/demos] [--package-dir AdaEngine] [--swift-sdk swift-6.3.2-RELEASE_wasm] [--scratch-path .build-web-website-demos] [--only ProductA,ProductB] [--skip-products ProductC] [--continue-on-error] [--allow-failures ProductD] [--strip-wasm-debug] [--skip-build] [--list]

The output directory is meant to be the website public/demos folder. Each demo
gets its exported web bundle, source.swift, metadata.json, and the shared
manifest.json used by adaengine.org.

Default output is ADAENGINE_WEBSITE_DEMOS_DIR, then ../adawebsite/public/demos
when that directory exists, then dist/website-demos. Use --swift-sdk auto to let
the SwiftPM plugin choose an installed wasm SDK.

Use --strip-wasm-debug to remove DWARF debug sections and the wasm name section
from exported .wasm files. Set LLVM_OBJCOPY to override the objcopy executable.

When --only is used and manifest.json already exists, selected entries are
merged into the existing manifest. Use --replace-manifest to write only the
selected entries.
`.trim())
}

function fail(message) {
  console.error(message)
  process.exit(1)
}
