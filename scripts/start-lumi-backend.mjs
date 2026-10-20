import { existsSync } from 'node:fs'
import { resolve, join } from 'node:path'
import { spawn } from 'node:child_process'

const projectRoot = resolve(import.meta.dirname, '..')
const backendRoot = resolve(process.env.LUMI_BACKEND_ROOT ?? join(projectRoot, '../Learning-App'))
const backendUrl = process.env.LUMI_BACKEND_URL ?? 'http://127.0.0.1:8080'
const frontendPort = process.env.LUMI_FRONTEND_PORT ?? '5173'
const localDevOrigins = `http://127.0.0.1:${frontendPort},http://localhost:${frontendPort}`

async function isReachable() {
  try {
    return (await fetch(`${backendUrl}/api/notes`)).ok
  } catch {
    return false
  }
}

if (await isReachable()) {
  console.log(`Lumi backend is already available at ${backendUrl}; not starting a duplicate process.`)
  process.exit(0)
}

const dart = join(backendRoot, 'scripts', 'dart')
if (!existsSync(dart)) {
  throw new Error(`Lumi Dart backend was not found at ${backendRoot}. Set LUMI_BACKEND_ROOT to the existing Lumi project.`)
}

const child = spawn(dart, ['--packages=.dart_tool/package_config.json', 'bin/server.dart'], {
  cwd: backendRoot,
  env: {
    ...process.env,
    // The backend rejects every browser origin unless it is explicitly named.
    // Keep the default limited to this local Vite instance; deployments should
    // set LUMI_ALLOWED_ORIGINS themselves.
    LUMI_ALLOWED_ORIGINS: process.env.LUMI_ALLOWED_ORIGINS ?? localDevOrigins,
  },
  stdio: 'inherit',
})

for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, () => child.kill(signal))
}

child.on('exit', (code) => process.exit(code ?? 1))
