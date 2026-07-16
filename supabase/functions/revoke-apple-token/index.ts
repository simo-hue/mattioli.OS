import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.2/mod.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const APPLE_AUTH_HOST = 'https://appleid.apple.com'

function json(body: unknown, status: number) {
  return new Response(
    JSON.stringify(body),
    { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
  )
}

// Apple hands out the signing key as a PKCS#8 PEM (.p8). Secret managers that
// only carry single-line values turn its newlines into literal `\n`, so both
// shapes have to parse.
function importApplePrivateKey(pem: string): Promise<CryptoKey> {
  const der = pem
    .replace(/\\n/g, '\n')
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '')

  const binary = atob(der)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)

  return crypto.subtle.importKey(
    'pkcs8',
    bytes,
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign'],
  )
}

// Apple authenticates the app with a short-lived ES256 JWT rather than a static
// secret; it is minted per request and never leaves the server.
async function buildClientSecret(
  teamId: string,
  keyId: string,
  clientId: string,
  privateKeyPem: string,
): Promise<string> {
  const key = await importApplePrivateKey(privateKeyPem)
  return await create(
    { alg: 'ES256', kid: keyId, typ: 'JWT' },
    {
      iss: teamId,
      iat: getNumericDate(0),
      exp: getNumericDate(60 * 5),
      aud: APPLE_AUTH_HOST,
      sub: clientId,
    },
    key,
  )
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 1. Fail loudly when the Apple credentials are not configured. Silently
    //    reporting success here would let the client believe the Apple grant was
    //    revoked when nothing was ever sent to Apple.
    const teamId = Deno.env.get('APPLE_TEAM_ID')
    const keyId = Deno.env.get('APPLE_KEY_ID')
    const clientId = Deno.env.get('APPLE_CLIENT_ID')
    const privateKey = Deno.env.get('APPLE_PRIVATE_KEY')

    const missing = Object.entries({
      APPLE_TEAM_ID: teamId,
      APPLE_KEY_ID: keyId,
      APPLE_CLIENT_ID: clientId,
      APPLE_PRIVATE_KEY: privateKey,
    }).filter(([, value]) => !value).map(([name]) => name)

    if (missing.length > 0) {
      console.error(`[Revoke Apple] Missing required secrets: ${missing.join(', ')}`)
      return json(
        { error: `Apple revocation is not configured: missing ${missing.join(', ')}.` },
        500,
      )
    }

    // 2. Only the owner of an account may revoke its Apple grant, so the caller's
    //    JWT — not a service-role key — decides who this is.
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return json({ error: 'Unauthorized: missing Authorization header.' }, 401)
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    )

    const { data: { user }, error: userError } = await supabase.auth.getUser()
    if (userError || !user) {
      return json({ error: 'Unauthorized: invalid or expired session.' }, 401)
    }

    const body = await req.json().catch(() => ({}))
    const authorizationCode = body.authorization_code
    if (typeof authorizationCode !== 'string' || authorizationCode.length === 0) {
      return json({ error: 'Bad Request: missing authorization_code.' }, 400)
    }

    const clientSecret = await buildClientSecret(
      teamId!,
      keyId!,
      clientId!,
      privateKey!,
    )

    // 3. /auth/revoke only accepts a token Apple issued, so the single-use
    //    authorization code is first exchanged for the refresh token. Revoking
    //    the refresh token invalidates the whole grant, which is what drops the
    //    app from the user's "Sign in with Apple" list.
    const tokenResponse = await fetch(`${APPLE_AUTH_HOST}/auth/token`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        client_id: clientId!,
        client_secret: clientSecret,
        code: authorizationCode,
        grant_type: 'authorization_code',
      }),
    })

    const tokenBody = await tokenResponse.json().catch(() => ({}))
    if (!tokenResponse.ok) {
      console.error(
        `[Revoke Apple] Code exchange failed for user ${user.id}: ` +
        `${tokenResponse.status} ${JSON.stringify(tokenBody)}`,
      )
      return json(
        { error: `Apple rejected the authorization code: ${tokenBody.error ?? tokenResponse.status}` },
        502,
      )
    }

    const refreshToken = tokenBody.refresh_token
    if (typeof refreshToken !== 'string' || refreshToken.length === 0) {
      console.error(`[Revoke Apple] No refresh_token in Apple's response for user ${user.id}`)
      return json({ error: 'Apple returned no refresh token to revoke.' }, 502)
    }

    const revokeResponse = await fetch(`${APPLE_AUTH_HOST}/auth/revoke`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        client_id: clientId!,
        client_secret: clientSecret,
        token: refreshToken,
        token_type_hint: 'refresh_token',
      }),
    })

    if (!revokeResponse.ok) {
      const revokeBody = await revokeResponse.text()
      console.error(
        `[Revoke Apple] Revocation failed for user ${user.id}: ` +
        `${revokeResponse.status} ${revokeBody}`,
      )
      return json(
        { error: `Apple rejected the revocation: ${revokeResponse.status}` },
        502,
      )
    }

    console.log(`[Revoke Apple] Revoked the Apple grant for user ${user.id}`)
    return json({ revoked: true }, 200)
  } catch (error) {
    console.error('[Revoke Apple] Unexpected error', error)
    return json({ error: 'Critical server error.' }, 500)
  }
})
