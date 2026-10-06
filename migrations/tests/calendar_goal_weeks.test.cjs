// Disposable Postgres regression test (no live database or credentials).
// npm install --prefix /tmp/evolve-pg-test @electric-sql/pglite
// NODE_PATH=/tmp/evolve-pg-test/node_modules node migrations/tests/calendar_goal_weeks.test.cjs
const { PGlite } = require('@electric-sql/pglite');
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const assert = require('node:assert/strict');
const shift = (d, n) => new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate() + n));
const key = d => d.toISOString().slice(0, 10);
function expected(year, month, week) {
  const owner = new Date(Date.UTC(year, month - 1 + (week >= 5 ? 1 : 0), 1));
  const index = week >= 5 ? 1 : week;
  const previousLast = shift(owner, -1);
  const start = index === 1 && previousLast.getUTCDate() > 28
    ? new Date(Date.UTC(previousLast.getUTCFullYear(), previousLast.getUTCMonth(), 29))
    : shift(owner, (index - 1) * 7);
  const end = shift(owner, index * 7 - 1);
  // Count dates in each real week; insertion order makes ties choose earlier.
  const counts = new Map();
  for (let day = start; day <= end; day = shift(day, 1)) {
    const monday = key(shift(day, -((day.getUTCDay() + 6) % 7)));
    counts.set(monday, (counts.get(monday) || 0) + 1);
  }
  return [...counts].sort((a, b) => b[1] - a[1])[0][0];
}
(async () => {
  const db = new PGlite();
  try {
    await db.exec(`CREATE TYPE public.long_term_goal_type AS ENUM ('annual','monthly','weekly','quarterly','lifetime');
      CREATE TABLE public.long_term_goals (
        id text PRIMARY KEY, user_id text DEFAULT 'u', title text DEFAULT 'Keep title',
        type public.long_term_goal_type, year integer, month integer, week_number integer, quarter integer,
        status text DEFAULT 'completed', target_amount numeric DEFAULT 42,
        progress_amount numeric DEFAULT 17, linked_goal_id text DEFAULT 'habit');`);
    const fixtures = [];
    for (let y = 2020; y <= 2030; y++) for (let m = 1; m <= 12; m++) for (let w = 1; w <= 6; w++) {
      fixtures.push({ id: `${y}-${m}-${w}`, year: y, month: m, week: w, monday: expected(y, m, w) });
    }
    await db.exec('INSERT INTO public.long_term_goals (id,type,year,month,week_number,quarter) VALUES ' +
      fixtures.map(f => `('${f.id}','weekly',${f.year},${f.month},${f.week},${Math.floor((f.month - 1) / 3) + 1})`).join(','));
    const migration = readFileSync(join(__dirname, '../20261005124948_calendar_goal_weeks.sql'), 'utf8');
    await db.exec(migration);
    const select = `SELECT *, week_start_date::text AS monday FROM public.long_term_goals ORDER BY id`;
    const originalRows = (await db.query(select)).rows;
    assert.equal(originalRows.find(r => r.id === '2027-1-1').quarter, 1,
      'original migration left the old quarter on an already-converted December week');
    await db.exec(migration);
    assert.deepEqual((await db.query(select)).rows, originalRows, 'original migration must be idempotent');
    const quarterMigration = readFileSync(join(__dirname, '../20261005181032_calendar_week_quarters.sql'), 'utf8');
    await db.exec(quarterMigration);
    const rows = (await db.query(select)).rows;
    const withoutQuarter = list => list.map(({ quarter, ...rest }) => rest);
    assert.deepEqual(withoutQuarter(rows), withoutQuarter(originalRows),
      'quarter repair must preserve week dates and user data');
    for (const f of fixtures) {
      const row = rows.find(r => r.id === f.id);
      assert.equal(row.monday, f.monday, f.id);
      const thursday = shift(new Date(`${f.monday}T00:00:00Z`), 3);
      assert.equal(row.year, thursday.getUTCFullYear());
      assert.equal(row.month, thursday.getUTCMonth() + 1);
      assert.equal(row.quarter, Math.floor(thursday.getUTCMonth() / 3) + 1);
      assert.equal(row.week_number, Math.floor((thursday.getUTCDate() - 1) / 7) + 1);
      assert.equal(row.status, 'completed');
      assert.equal(Number(row.target_amount), 42);
      assert.equal(Number(row.progress_amount), 17);
      assert.equal(row.linked_goal_id, 'habit');
    }
    await db.exec(quarterMigration);
    assert.deepEqual((await db.query(select)).rows, rows, 'migration must be idempotent');
    await db.exec(`INSERT INTO public.long_term_goals (id,type,year,month,week_number,week_start_date)
      VALUES ('new','weekly',2026,5,1,'2026-05-04');`);
    const get = async () => (await db.query("SELECT week_start_date::text AS monday, status, quarter FROM public.long_term_goals WHERE id='new'")).rows[0];
    assert.equal((await get()).monday, '2026-05-04', 'new week one differs from legacy week one');
    assert.equal((await get()).quarter, 2, 'new client insert derives quarter');
    await db.exec("UPDATE public.long_term_goals SET status='failed' WHERE id='new'");
    assert.equal((await get()).monday, '2026-05-04', 'status edit cannot move a week');
    await db.exec("UPDATE public.long_term_goals SET month=9,week_number=1 WHERE id='new'");
    assert.equal((await get()).monday, '2026-08-31', 'old-client reschedule uses greatest overlap');
    assert.equal((await get()).quarter, 3, 'old-client reschedule updates quarter');
    await db.exec("UPDATE public.long_term_goals SET month=5,week_number=1,week_start_date='2026-05-04' WHERE id='new'");
    assert.equal((await get()).monday, '2026-05-04', 'new-client reschedule trusts explicit Monday');
    assert.equal((await get()).quarter, 2, 'new-client reschedule updates quarter');
    await db.exec("UPDATE public.long_term_goals SET quarter=NULL WHERE id='new'");
    assert.equal((await get()).quarter, 2, 'quarter-only edits cannot desynchronize a weekly address');
    await db.exec("INSERT INTO public.long_term_goals (id,type,year,quarter) VALUES ('quarterly','quarterly',2026,4)");
    await db.exec(quarterMigration);
    assert.equal((await db.query("SELECT quarter FROM public.long_term_goals WHERE id='quarterly'")).rows[0].quarter, 4,
      'nonweekly quarters are preserved');
    await db.exec(`INSERT INTO public.long_term_goals (id,type,year,month,week_number,week_start_date)
      VALUES ('invalid-marker','weekly',2026,5,1,'2026-05-05');`);
    assert.equal((await db.query("SELECT week_start_date::text AS monday FROM public.long_term_goals WHERE id='invalid-marker'")).rows[0].monday,
      '2026-04-27', 'invalid markers fall back to legacy conversion, as in Flutter');
    // An ordinary authenticated table writer can still invoke the trigger;
    // it confers no RLS bypass and exposes no callable definer function.
    await db.exec(`CREATE ROLE authenticated; GRANT USAGE ON SCHEMA public TO authenticated;
      GRANT INSERT,SELECT,UPDATE ON public.long_term_goals TO authenticated;
      ALTER TABLE public.long_term_goals ENABLE ROW LEVEL SECURITY;
      CREATE POLICY own_goals ON public.long_term_goals TO authenticated USING(user_id='u') WITH CHECK(user_id='u');
      SET ROLE authenticated;
      INSERT INTO public.long_term_goals (id,type,year,month,week_number) VALUES ('rls','weekly',2026,9,1);
      RESET ROLE;`);
    assert.equal((await db.query("SELECT week_start_date::text AS monday FROM public.long_term_goals WHERE id='rls'")).rows[0].monday, '2026-08-31');
    console.log(`Postgres migrations: ${fixtures.length} legacy periods and quarter repairs, repeat migration, old/new edits and RLS writer passed.`);
  } finally { await db.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
