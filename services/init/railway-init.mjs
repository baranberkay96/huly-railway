// One-shot owner bootstrap for Huly on Railway (runs in the official tool image).
//
// The template disables public sign-up (DISABLE_SIGNUP=true on account and
// front), so this creates the first account with Huly's own tool command
// `create-account`, then verifies it by logging in through the account service.
// Idempotent: an existing account is left alone (its password is never reset).
import { spawnSync } from 'node:child_process'

const env = process.env
const accountsUrl = env.ACCOUNTS_URL
const email = (env.HULY_OWNER_EMAIL || '').trim().toLowerCase()
const password = env.HULY_OWNER_PASSWORD || ''
const log = (msg) => console.log(`[railway-init] ${msg}`)
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms))

if (!accountsUrl || !email || !password) {
  log('ACCOUNTS_URL, HULY_OWNER_EMAIL and HULY_OWNER_PASSWORD are required')
  process.exit(1)
}

async function rpc (method, params) {
  const res = await fetch(accountsUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ method, params })
  })
  return await res.json()
}

async function canLogin () {
  const reply = await rpc('login', { email, password })
  return Boolean(reply?.result?.token)
}

// The account service creates its database schema on start; wait for it.
const deadline = Date.now() + Number(env.WAIT_SECONDS || 900) * 1000
for (;;) {
  try {
    await rpc('getProviders', {})
    break
  } catch {
    if (Date.now() > deadline) {
      log(`account service at ${accountsUrl} not reachable; giving up (Railway will retry)`)
      process.exit(1)
    }
    log('waiting for the account service...')
    await sleep(10000)
  }
}

if (await canLogin()) {
  log(`owner account ${email} already exists; nothing to do`)
  process.exit(0)
}

log(`creating owner account ${email}`)
const result = spawnSync('node', ['bundle.js', 'create-account', email,
  '-p', password, '-f', env.HULY_OWNER_FIRST_NAME || 'Owner', '-l', env.HULY_OWNER_LAST_NAME || 'Admin'],
{ encoding: 'utf8' })
const output = `${result.stdout}\n${result.stderr}`
if (output.includes('AccountAlreadyExists')) {
  log(`an account for ${email} already exists with another password; leaving it unchanged`)
  process.exit(0)
}

if (await canLogin()) {
  log(`owner account ${email} created; sign in at the public URL and create your workspace`)
  process.exit(0)
}
console.error(output)
log('account creation could not be verified')
process.exit(1)
