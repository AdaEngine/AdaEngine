#!/usr/bin/env node

import { spawnSync } from 'node:child_process'
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url))
const defaultPackageDirectory = path.resolve(scriptDirectory, '..')

const options = parseArguments(process.argv.slice(2))
const packageDirectory = path.resolve(options.packageDirectory ?? defaultPackageDirectory)
const outputDirectory = path.resolve(options.outputDirectory ?? path.join(packageDirectory, 'dist', 'website-demos'))
const packageFile = path.join(packageDirectory, 'Package.swift')
const demosDirectory = path.join(packageDirectory, 'Demos')

if (!existsSync(packageFile)) {
  fail(`Package.swift was not found at ${packageFile}`)
}

if (!existsSync(demosDirectory)) {
  fail(`Demos directory was not found at ${demosDirectory}`)
}

const products = discoverDemoProducts(packageFile)
  .filter((demo) => !options.only.size || options.only.has(demo.product))
  .sort((lhs, rhs) => lhs.tag.localeCompare(rhs.tag) || lhs.title.localeCompare(rhs.title))

if (!products.length) {
  fail(options.only.size ? `No matching demo products found for: ${[...options.only].join(', ')}` : 'No demo products were found in Package.swift')
}

mkdirSync(outputDirectory, { recursive: true })

const commit = captureGit(['rev-parse', 'HEAD'], packageDirectory)
const manifest = {
  schemaVersion: 1,
  generatedAt: new Date().toISOString(),
  repository: 'AdaEngine/AdaEngine',
  commit,
  demos: [],
}

for (const demo of products) {
  const demoOutputDirectory = path.join(outputDirectory, demo.slug)
  const sourceFile = path.join(demosDirectory, demo.tag, `${demo.product}.swift`)

  if (!existsSync(sourceFile)) {
    fail(`Demo source was not found for ${demo.product}: ${sourceFile}`)
  }

  if (!options.skipBuild) {
    rmSync(demoOutputDirectory, { recursive: true, force: true })
    mkdirSync(demoOutputDirectory, { recursive: true })
    exportDemo(demo.product, demoOutputDirectory)
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

writeFileSync(path.join(outputDirectory, 'manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`)
console.log(`Prepared ${manifest.demos.length} demo entries in ${outputDirectory}`)

function parseArguments(args) {
  const parsed = {
    only: new Set(),
    outputDirectory: undefined,
    packageDirectory: undefined,
    skipBuild: false,
    swiftSDK: undefined,
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
    case '--only':
      for (const product of requireValue(args, ++index, argument).split(',')) {
        if (product.trim()) parsed.only.add(product.trim())
      }
      break
    case '--skip-build':
      parsed.skipBuild = true
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
    '--release',
  ]

  if (options.swiftSDK) {
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
    fail(`Failed to export ${product}`)
  }
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

function printHelp() {
  console.log(`
Usage:
  node scripts/build-website-demos.mjs [--output public/demos] [--package-dir AdaEngine] [--swift-sdk swift-6.3.2-RELEASE_wasm] [--only ProductA,ProductB] [--skip-build]

The output directory is meant to be the website public/demos folder. Each demo
gets its exported web bundle, source.swift, metadata.json, and the shared
manifest.json used by adaengine.org.
`.trim())
}

function fail(message) {
  console.error(message)
  process.exit(1)
}
