import { spawnSync } from 'node:child_process';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const cli = require.resolve('fengari-node-cli/src/lua-cli.js');
const cases = [
  ['tests/run.lua', 'Roleplay Lite: login, spawn, mining, write failure, replay, disconnect and chat allowlist passed.'],
  ['tests/client.lua', 'Roleplay Lite: access UI, mining game and input lifecycle passed.']
];
for (const [file, sentinel] of cases) {
  const result = spawnSync(process.execPath, [cli, file], {
    cwd: new URL('../', import.meta.url),
    encoding: 'utf8'
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  process.stdout.write(output);
  if (result.error || result.status !== 0 || !output.includes(sentinel)) {
    process.exitCode = 1;
    break;
  }
}
