import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

const project = path.resolve(import.meta.dirname, '..');

function validateResource(resourceRoot, read = (file) => fs.readFileSync(file, 'utf8'), exists = fs.existsSync) {
  const errors = [];
  const manifest = read(path.join(resourceRoot, 'scripts.xml'));
  const entries = [...manifest.matchAll(/<(script|file)\s+src="([^"]+)"([^>]*)\/>/g)];
  const paths = new Set();
  for (const [, kind, relative, attributes] of entries) {
    if (paths.has(relative)) errors.push(`Duplicate manifest path: ${relative}`);
    paths.add(relative);
    if (!exists(path.join(resourceRoot, relative))) errors.push(`Missing file: ${relative}`);
    if (kind === 'script' && /type="server"/.test(attributes) && /download=/.test(attributes)) {
      errors.push(`Server script marked for download: ${relative}`);
    }
  }
  for (const relative of paths) {
    if (!relative.endsWith('.rml') || !exists(path.join(resourceRoot, relative))) continue;
    const rml = read(path.join(resourceRoot, relative));
    const ids = new Set();
    for (const [, id] of rml.matchAll(/\bid="([^"]+)"/g)) {
      if (ids.has(id)) errors.push(`Duplicate RML ID: ${relative}#${id}`);
      ids.add(id);
    }
    for (const [, asset] of rml.matchAll(/(?:href|src)="([^"]+\.(?:rcss|png|webp|svg))"/g)) {
      const normalized = path.posix.normalize(path.posix.join(path.posix.dirname(relative), asset));
      if (!paths.has(normalized)) errors.push(`Asset not in manifest: ${normalized}`);
      if (!exists(path.join(resourceRoot, normalized))) errors.push(`Missing asset: ${normalized}`);
    }
  }
  return errors;
}

test('both resources include all files and unique UI IDs', () => {
  for (const resource of ['roleplay_lite', 'chat']) {
    assert.deepEqual(validateResource(path.join(project, 'resources', resource)), []);
  }
});

test('validator catches missing assets, manifest entries and duplicate IDs', () => {
  const root = path.join(project, 'resources', 'roleplay_lite');
  const manifest = fs.readFileSync(path.join(root, 'scripts.xml'), 'utf8');
  const badManifest = manifest.replace('<file src="ui/lite.rcss" download="join" />', '');
  const badRml = '<rml><head><link href="lite.rcss" /></head><body><div id="x" /><p id="x" /></body></rml>';
  const errors = validateResource(root,
    (file) => file.endsWith('scripts.xml') ? badManifest : file.endsWith('access.rml') ? badRml : fs.readFileSync(file, 'utf8'),
    (file) => file.endsWith('mine.rml') ? false : fs.existsSync(file));
  assert(errors.some((value) => value.includes('Asset not in manifest')));
  assert(errors.some((value) => value.includes('Duplicate RML ID')));
  assert(errors.some((value) => value.includes('Missing file')));
});
