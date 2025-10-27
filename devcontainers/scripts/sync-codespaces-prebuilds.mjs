#!/usr/bin/env node

import { promises as fs } from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..", "..");

const args = process.argv.slice(2);

let stackId = "classroom";
let outputPath;
let dryRun = false;
let namespace = process.env.DEVCONTAINERS_NAMESPACE || "airnub-labs/devcontainers";

for (let i = 0; i < args.length; i += 1) {
  const arg = args[i];
  if (arg === "--stack" && i + 1 < args.length) {
    stackId = args[++i];
  } else if (arg === "--output" && i + 1 < args.length) {
    outputPath = path.resolve(args[++i]);
  } else if (arg === "--namespace" && i + 1 < args.length) {
    namespace = args[++i];
  } else if (arg === "--dry-run") {
    dryRun = true;
  } else {
    throw new Error(`Unknown or incomplete argument: ${arg}`);
  }
}

const stackDir = path.join(repoRoot, "devcontainers", "stacks", stackId);
const stackManifestPath = path.join(stackDir, "stack.json");

async function readJson(filePath) {
  const data = await fs.readFile(filePath, "utf8");
  return JSON.parse(data);
}

const stackManifest = await readJson(stackManifestPath);
const templates = Array.isArray(stackManifest.templates) ? stackManifest.templates : [];

const registryBase = `ghcr.io/${namespace.replace(/\/+$/, "")}/templates`;

const templateEntries = [];

for (const template of templates) {
  const templatePath = path.resolve(stackDir, template.path ?? "");
  const manifestPath = path.join(templatePath, "devcontainer-template.json");
  const manifest = await readJson(manifestPath);
  const version = manifest.version || "latest";
  const uri = `${registryBase}/${manifest.id}:${version}`;

  templateEntries.push({
    id: manifest.id,
    name: manifest.name,
    version,
    uri,
    documentationURL: manifest.documentationURL ?? null,
  });
}

const config = {
  $schema: "https://schemas.github.com/codespaces/prebuild-configuration", // informational only
  stack: {
    id: stackManifest.id,
    name: stackManifest.name,
    version: stackManifest.version,
    documentationURL: stackManifest.documentationURL ?? null,
  },
  generatedAt: new Date().toISOString(),
  namespace: registryBase,
  templates: templateEntries,
};

if (!outputPath) {
  outputPath = path.join(repoRoot, ".github", "codespaces", "prebuilds", `${stackId}.json`);
}

if (dryRun) {
  console.log(JSON.stringify(config, null, 2));
} else {
  await fs.mkdir(path.dirname(outputPath), { recursive: true });
  await fs.writeFile(outputPath, `${JSON.stringify(config, null, 2)}\n`, "utf8");
  console.log(`Wrote ${outputPath}`);
}
