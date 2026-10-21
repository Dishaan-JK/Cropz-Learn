import { spawn } from 'node:child_process'

const backendUrl = process.env.LUMI_BACKEND_URL ?? 'http://127.0.0.1:8080'
const frontendPort = process.env.LUMI_FRONTEND_PORT ?? '5173'
const npm = process.platform === 'win32' ? 'npm.cmd' : 'npm'

async function isReachable() {
  try {
    return (await fetch(`${backendUrl}/api/notes`)).ok
  } catch {
    return false
  }
}

async function waitForBackend() {
  for (let attempt = 0; attempt < 45; attempt += 1) {
    if (await isReachable()) return
    await new Promise((resolve) => setTimeout(resolve, 1000))
  }
  throw new Error(`Lumi backend did not become available at ${backendUrl}.`)
}

async function isFrontendOriginAllowed() {
  const origins = [`http://127.0.0.1:${frontendPort}`, `http://localhost:${frontendPort}`]
  const allowed = await Promise.all(origins.map(async (origin) => {
    try {
      const response = await fetch(`${backendUrl}/api/settings/models`, {
        method: 'OPTIONS',
        headers: {
          Origin: origin,
          'Access-Control-Request-Method': 'POST',
          'Access-Control-Request-Headers': 'content-type',
        },
      })
      return response.status === 204 && response.headers.get('access-control-allow-origin') === origin
    } catch {
      return false
    }
  }))
  return allowed.every(Boolean)
}

let backendProcess
if (!await isReachable()) {
  backendProcess = spawn(process.execPath, ['scripts/start-lumi-backend.mjs'], {
    stdio: 'inherit',
    env: { ...process.env, LUMI_FRONTEND_PORT: frontendPort },
  })
  await waitForBackend()
}

if (!await isFrontendOriginAllowed()) {
  console.error(`The backend at ${backendUrl} does not allow the Lumi UI origin on port ${frontendPort}. Restart the backend with LUMI_ALLOWED_ORIGINS=http://127.0.0.1:${frontendPort},http://localhost:${frontendPort}, or set LUMI_FRONTEND_PORT to an allowed port.`)
  backendProcess?.kill('SIGTERM')
  process.exit(1)
}

const frontendProcess = spawn(npm, ['run', 'dev', '--', '--host', '127.0.0.1', '--port', frontendPort, '--strictPort'], { stdio: 'inherit', env: process.env })

function stop(signal) {
  frontendProcess.kill(signal)
  backendProcess?.kill(signal)
}

for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => stop(signal))
frontendProcess.on('exit', (code) => {
  backendProcess?.kill('SIGTERM')
  process.exit(code ?? 1)
})
