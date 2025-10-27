#!/usr/bin/env node
import { promises as fs } from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

function parseArgs(argv) {
  const options = {
    dryRun: false,
    namespace: undefined,
    version: undefined,
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--dry-run') {
      options.dryRun = true;
    } else if (arg === '--namespace') {
      if (i + 1 >= argv.length) {
        throw new Error('Expected value after --namespace');
      }
      options.namespace = argv[i + 1];
      i += 1;
    } else if (arg === '--version') {
      if (i + 1 >= argv.length) {
        throw new Error('Expected value after --version');
      }
      options.version = argv[i + 1];
      i += 1;
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }

  return options;
}

async function* walk(dir) {
  const entries = await fs.readdir(dir, { withFileTypes: true });
  for (const entry of entries) {
    const entryPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      yield* walk(entryPath);
    } else if (entry.isFile()) {
      yield entryPath;
    }
  }
}

function escapeForRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function replaceFeatureRefs(content, namespace, version, { dryRun }) {
  const filePattern = /file:(?:\.\.\/+)+features\/([A-Za-z0-9_-]+)/g;
  const fileMatches = [...content.matchAll(filePattern)];

  if (dryRun) {
    return { changed: fileMatches.length > 0, updated: content };
  }

  let updated = content.replace(filePattern, (_, featureId) => {
    return `ghcr.io/${namespace}/features/${featureId}:${version}`;
  });

  const namespacePattern = escapeForRegex(namespace);
  const ghcrPattern = new RegExp(
    `ghcr\\.io/${namespacePattern}/features/([A-Za-z0-9_-]+):[A-Za-z0-9._-]+`,
    'g'
  );

  updated = updated.replace(ghcrPattern, (fullMatch, featureId) => {
    const replacement = `ghcr.io/${namespace}/features/${featureId}:${version}`;
    if (fullMatch === replacement) {
      return fullMatch;
    }
    return replacement;
  });

  return { changed: updated !== content, updated };
}

async function main() {
  const { dryRun, namespace, version } = parseArgs(process.argv.slice(2));

  if (!dryRun && (!namespace || !version)) {
    console.error('Error: --namespace and --version are required unless --dry-run is specified.');
    process.exit(1);
  }

  const devcontainersDir = path.resolve(__dirname, '..');
  const templatesDir = path.join(devcontainersDir, 'templates');
  const targetFiles = [];

  for await (const filePath of walk(templatesDir)) {
    const filename = path.basename(filePath);
    if (
      filename === 'devcontainer-template.json' ||
      (filename === 'devcontainer.json' && filePath.includes(`${path.sep}.devcontainer${path.sep}`))
    ) {
      targetFiles.push(filePath);
    }
  }

  const filesNeedingUpdate = [];

  for (const filePath of targetFiles) {
    const original = await fs.readFile(filePath, 'utf8');
    const { changed, updated } = replaceFeatureRefs(original, namespace ?? '', version ?? '', {
      dryRun,
    });
    if (!changed) {
      continue;
    }

    filesNeedingUpdate.push(filePath);

    if (!dryRun) {
      await fs.writeFile(filePath, updated, 'utf8');
    }
  }

  if (filesNeedingUpdate.length > 0) {
    if (dryRun) {
      console.error('The following template files reference local features and must be updated:');
      for (const file of filesNeedingUpdate) {
        console.error(` - ${path.relative(process.cwd(), file)}`);
      }
      process.exit(1);
    } else {
      console.log('Updated feature references in:');
      for (const file of filesNeedingUpdate) {
        console.log(` - ${path.relative(process.cwd(), file)}`);
      }
    }
  } else if (dryRun) {
    console.log('No template files contain local feature references.');
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
