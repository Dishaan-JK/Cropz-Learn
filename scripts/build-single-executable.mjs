import { mkdir, mkdtemp, readFile, readdir, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { dirname, join, relative, resolve, sep } from 'node:path'
import { fileURLToPath } from 'node:url'
import { existsSync } from 'node:fs'
import { execFile } from 'node:child_process'
import { promisify } from 'node:util'

const execFileAsync = promisify(execFile)
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const backendRoot = resolve(root, '../Learning-App')
const output = resolve(process.argv[2] ?? join(root, 'release/lumi-linux-x64'))
const temp = await mkdtemp(join(tmpdir(), 'lumi-single-build-'))

if (process.platform !== 'linux' || process.arch !== 'x64') {
  throw new Error('This build script currently targets Linux x86_64. Build on another supported target with its native toolchain.')
}

async function run(command, args, cwd, env = process.env) {
  const { stdout, stderr } = await execFileAsync(command, args, { cwd, env, maxBuffer: 16 * 1024 * 1024 })
  if (stdout.trim()) process.stdout.write(stdout)
  if (stderr.trim()) process.stderr.write(stderr)
}
async function listFiles(directory) {
  const out = []
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name)
    if (entry.isDirectory()) out.push(...await listFiles(path))
    else if (entry.isFile()) out.push(path)
  }
  return out
}

try {
  await mkdir(dirname(output), { recursive: true })
  await run('npm', ['run', 'build'], root)
  const backendBinary = join(temp, 'lumi-backend')
  try {
    await run(join(backendRoot, 'scripts/dart'), ['compile', 'exe', '--packages=.dart_tool/package_config.json', 'bin/server.dart', '-o', backendBinary], backendRoot, {
      ...process.env,
      FLUTTER_SUPPRESS_ANALYTICS: 'true',
      DART_SUPPRESS_ANALYTICS: 'true',
    })
  } catch (error) {
    const diagnostic = String(error.stderr ?? error.message ?? error)
    if (!existsSync(backendBinary) || !diagnostic.includes('/.dart-tool/dart-flutter-telemetry.log')) throw error
    process.stderr.write('Dart generated the backend executable; its post-build analytics log cleanup was blocked by the read-only home directory. Continuing with the generated binary.\n')
  }

  const assetEntries = (await listFiles(join(root, 'dist'))).map((path) => {
    const name = relative(join(root, 'dist'), path).split(sep).join('/')
    const escapedName = JSON.stringify(name)
    return `(${escapedName}, include_bytes!(concat!(env!("LUMI_DIST_DIR"), "/${name}")) as &[u8])`
  }).join(',\n    ')
  const template = await readFile(join(root, 'scripts/single-launcher.rs'), 'utf8')
  const generated = template.replace('__LUMI_ASSET_ENTRIES__', assetEntries)
  const generatedSource = join(temp, 'launcher.rs')
  await writeFile(generatedSource, generated)
  await run('rustc', ['--edition=2021', '-C', 'opt-level=3', generatedSource, '-o', output], root, {
    ...process.env,
    LUMI_BACKEND_BINARY: backendBinary,
    LUMI_DIST_DIR: join(root, 'dist'),
  })
  process.stdout.write(`Built ${output}\n`)
} finally {
  await rm(temp, { recursive: true, force: true })
}
