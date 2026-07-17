// Run: deno test supabase/functions/ai-coach/
//
// These cover the three things in the proxy that spend money or make legal
// claims: the input clamp, the quota windows, and the stream observer that
// proves the provider pin held.
import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts"
import { observeSseStream, quotaExceeded, totalInputChars } from "./index.ts"

const enc = new TextEncoder()
const dec = new TextDecoder()

/** Feed `chunks` through the observer; return what came out the other side. */
async function pump(chunks: string[]) {
  const { stream, observations } = observeSseStream()
  const readable = new ReadableStream<Uint8Array>({
    start(controller) {
      for (const c of chunks) controller.enqueue(enc.encode(c))
      controller.close()
    },
  })
  let out = ''
  for await (const c of readable.pipeThrough(stream)) out += dec.decode(c)
  return { out, observations }
}

const LIMITS = { max_per_10min: 20, max_per_day: 150, max_per_month: 1000 }
const NOW = 1_700_000_000_000
const agoMin = (m: number) => NOW - m * 60_000
const agoHrs = (h: number) => NOW - h * 3_600_000
const agoDays = (d: number) => NOW - d * 86_400_000

Deno.test("input clamp counts every message, which is what we pay for", () => {
  assertEquals(totalInputChars([]), 0)
  assertEquals(
    totalInputChars([
      { content: "you are a coach" }, // system prompt counts too
      { content: "hello" },
      { content: "hi" },
    ]),
    22,
  )
})

Deno.test("quota: an unused account is not limited", () => {
  assertEquals(quotaExceeded([], NOW, LIMITS), null)
})

Deno.test("quota: a burst trips the 10-minute window, not the daily one", () => {
  const burst = Array.from({ length: 20 }, (_, i) => agoMin(i % 9));
  assertEquals(quotaExceeded(burst, NOW, LIMITS), "per_10min")
})

Deno.test("quota: the 10-minute window only counts the last 10 minutes", () => {
  // 20 requests, but spread an hour apart: bursty limits must not punish a user
  // who has simply been around a while.
  const spread = Array.from({ length: 20 }, (_, i) => agoHrs(i + 1))
  assertEquals(quotaExceeded(spread, NOW, LIMITS), null)
})

Deno.test("quota: a heavy but human day is nowhere near the daily cap", () => {
  // 30 messages today is a lot of coaching. The cap is 150.
  const heavy = Array.from({ length: 30 }, (_, i) => agoMin(i * 20))
  assertEquals(quotaExceeded(heavy, NOW, LIMITS), null)
})

Deno.test("quota: the daily cap trips before the monthly one", () => {
  const today = Array.from({ length: 150 }, (_, i) => agoMin(i * 5))
  assertEquals(quotaExceeded(today, NOW, LIMITS), "per_day")
})

Deno.test("quota: the monthly cap trips on volume spread across the month", () => {
  // 1000 requests over 29 days: never enough in any hour or day to trip those,
  // but it is the month's whole budget.
  const month = Array.from({ length: 1000 }, (_, i) => agoDays(1 + (i % 29)))
  assertEquals(quotaExceeded(month, NOW, LIMITS), "per_month")
})

Deno.test("quota: limits are boundaries, so the Nth request is refused", () => {
  const nineteen = Array.from({ length: 19 }, () => agoMin(1))
  assertEquals(quotaExceeded(nineteen, NOW, LIMITS), null)
  assertEquals(quotaExceeded([...nineteen, agoMin(1)], NOW, LIMITS), "per_10min")
})

Deno.test("observer forwards every byte unchanged", async () => {
  const body = 'data: {"provider":"google-vertex","choices":[{"delta":{"content":"hi"}}]}\n\n' +
    "data: [DONE]\n\n"
  const { out } = await pump([body])
  assertEquals(out, body, "the user's stream must be byte-identical")
})

Deno.test("observer survives OPENROUTER PROCESSING keep-alive comments", async () => {
  // OpenRouter interleaves these to stop connections timing out. JSON.parse on
  // one throws, and an unhandled throw in a transform kills the user's stream —
  // their own docs warn about exactly this.
  const body = ": OPENROUTER PROCESSING\n\n" +
    ": OPENROUTER PROCESSING\n\n" +
    'data: {"provider":"google-vertex","choices":[{"delta":{"content":"hi"}}]}\n\n' +
    "data: [DONE]\n\n"
  const { out, observations } = await pump([body])
  assertEquals(out, body)
  assertEquals(observations.provider, "google-vertex")
  assertEquals(observations.errors, [])
})

Deno.test("observer reassembles JSON split across a chunk boundary", async () => {
  // TCP does not respect line boundaries. Splitting mid-payload must not lose
  // the provider — that value is our only proof the pin held.
  const chunks = [
    'data: {"provider":"goog',
    'le-vertex","choices":[{"delta":{"content":"hi"}}]}\n\n',
    "data: [DONE]\n\n",
  ]
  const { out, observations } = await pump(chunks)
  assertEquals(out, chunks.join(""))
  assertEquals(observations.provider, "google-vertex")
})

Deno.test("observer survives a payload split byte-by-byte", async () => {
  const body = 'data: {"provider":"google-vertex","choices":[]}\n\ndata: [DONE]\n\n'
  const { out, observations } = await pump([...body])
  assertEquals(out, body)
  assertEquals(observations.provider, "google-vertex")
})

Deno.test("observer catches mid-stream errors, which arrive on an HTTP 200", async () => {
  // A status check never sees these: OpenRouter returns 200 and then puts the
  // error in a normal data: event with finish_reason "error".
  const body = 'data: {"provider":"google-vertex","error":{"code":429,' +
    '"message":"Rate limit exceeded"},"choices":[{"delta":{"content":""},' +
    '"finish_reason":"error"}]}\n\n'
  const { out, observations } = await pump([body])
  assertEquals(out, body, "even an error stream is forwarded verbatim")
  assertEquals(observations.errors.length, 1)
  assertEquals((observations.errors[0] as { code: number }).code, 429)
})

Deno.test("observer reports the provider that actually served, not the one we asked for", async () => {
  // The pin-leak alarm. OpenRouter's docs leave "merged with your account-wide
  // allowed providers" undefined (union or intersection?), so the request we
  // sent is not proof. This is. The proxy pins google-ai-studio; Darkbloom is
  // the free model's OTHER server, and the one that must never silently serve —
  // it is not named in the privacy policy.
  const body = 'data: {"provider":"darkbloom","choices":[]}\n\n'
  const { observations } = await pump([body])
  assertEquals(
    observations.provider,
    "darkbloom",
    "an unpinned provider must be observable, or the leak is silent",
  )
})

Deno.test("observer does not choke on an empty stream", async () => {
  const { out, observations } = await pump([])
  assertEquals(out, "")
  assertEquals(observations.provider, null)
})

Deno.test("observer ignores malformed JSON rather than killing the stream", async () => {
  const body = "data: {not json at all\n\ndata: [DONE]\n\n"
  const { out, observations } = await pump([body])
  assertEquals(out, body)
  assertEquals(observations.provider, null)
})
