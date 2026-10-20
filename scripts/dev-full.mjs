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

let backendProcess
if (!await isReachable()) {
  backendProcess = spawn(process.execPath, ['scripts/start-lumi-backend.mjs'], {
    stdio: 'inherit',
    env: { ...process.env, LUMI_FRONTEND_PORT: frontendPort },
  })
  await waitForBackend()
}

const frontendProcess = spawn(npm, ['run', 'dev', '--', '--host', '127.0.0.1', '--port', frontendPort], { stdio: 'inherit', env: process.env })

function stop(signal) {
  frontendProcess.kill(signal)
  backendProcess?.kill(signal)
}

for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => stop(signal))
frontendProcess.on('exit', (code) => {
  backendProcess?.kill('SIGTERM')
  process.exit(code ?? 1)
})
