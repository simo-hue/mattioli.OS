#!/usr/bin/env python3
"""
Reusable per-cluster slang migrator (Phases 9+). Encapsulates the learnings:
- multi-line + trailing-comma aware scoping
- auto English camelCase keys (from the English value) for literals
- value pulled from the slang JSON if present, else the untouched ARB
- placeholder methods: single-param -> named-arg call sites; multi-param -> DEFERRED
- namespace-name collision with an existing flat key -> safely overwritten (flat
  keys are never referenced by slang code; value survives in the ARB)
- unused `core/localization.dart` import removed after migration
- exclusivity: strings used outside the cluster are DEFERRED (shared -> handled by
  their own namespace / the `common` phase)
- MISSING (no shim case) and dynamic `translate(var)` are DEFERRED and reported

Usage:  python3 tool/migrate_cluster.py <namespace> <file1.dart> [file2.dart ...]
"""
import re, glob, json, keyword, os, sys

NS = sys.argv[1]
CLUSTER = sys.argv[2:]
cset = set(CLUSTER)

LOCS = ['en', 'it', 'es', 'de']
pairs = dict(re.findall(r"case\s+'((?:[^'\\]|\\.)*)':\s*\n\s*return\s+([a-zA-Z0-9_]+);",
                        open('lib/core/localization.dart', encoding='utf-8').read()))
arb = {l: json.load(open(f'lib/l10n/app_{l}.arb', encoding='utf-8')) for l in LOCS}
sj = {l: json.load(open(f'lib/i18n/{l}.i18n.json', encoding='utf-8')) for l in LOCS}
allf = [x for x in glob.glob('lib/**/*.dart', recursive=True) if not x.endswith('.g.dart')]

DKW = set(keyword.kwlist) | {'is','in','as','if','do','class','enum','extends','new','this',
    'true','false','null','var','final','const','switch','case','return','for','while',
    'default','void','rethrow','assert','break','continue','super','with'}

def camel(t, mw=6):
    w = re.findall(r"[A-Za-z0-9]+", t)[:mw]
    if not w:
        return 'k'
    o = w[0].lower() + ''.join(x.capitalize() for x in w[1:])
    if o[0].isdigit():
        o = 'k' + o
    if o in DKW:
        o += 'Txt'
    return o

def val(loc, ck):
    return sj[loc].pop(ck) if ck in sj[loc] else arb[loc].get(ck)

def used_outside(lit):
    pat = r"translate\(\s*'" + re.escape(lit) + r"'"
    return any(re.search(pat, open(x, encoding='utf-8').read()) for x in allf if x not in cset)

LIT_RE = r"context\.l10n\.translate\(\s*'((?:[^'\\]|\\.)*)'\s*,?\s*\)"

# ---- collect ----
lits, getters = set(), set()
for f in CLUSTER:
    s = open(f, encoding='utf-8').read()
    lits |= set(re.findall(LIT_RE, s))
    getters |= {g for g in re.findall(r"context\.l10n\.([a-z][a-zA-Z0-9]+)", s) if g != 'translate'}

deferred = {'shared': [], 'missing': [], 'multiMethod': [], 'dynamicGetter': []}

# literals -> path
used = set()
get_plain, get_method = {}, {}
for g in getters:
    if g in ('localeName', 'language'):
        deferred['dynamicGetter'].append(g); continue
    meta = arb['en'].get('@' + g)
    ph = meta.get('placeholders') if isinstance(meta, dict) else None
    if ph and len(ph) > 1:
        deferred['multiMethod'].append(g); continue
    if ph:
        get_method[g] = list(ph)[0]
    else:
        get_plain[g] = g
used |= set(get_plain) | set(get_method)

lit2path = {}
for l in sorted(lits):
    if used_outside(l):
        deferred['shared'].append(l); continue
    if l not in pairs:
        deferred['missing'].append(l); continue
    env = arb['en'].get(pairs[l], l) or l
    if '{' in env:
        deferred['missing'].append(l); continue   # would become a method; handle manually
    base = camel(env); p = base; i = 2
    while p in used:
        p = f"{base}{i}"; i += 1
    used.add(p); lit2path[l] = p

def setn(r, path, v):
    *m, last = path.split('.')
    for x in m:
        r = r.setdefault(x, {})
    r[last] = v

# ---- JSON ----
for loc in LOCS:
    node = sj[loc].get(NS)
    node = node if isinstance(node, dict) else {}   # collision-safe
    for l, p in lit2path.items():
        setn(node, p, val(loc, pairs[l]))
    for g in list(get_plain) + list(get_method):
        v = val(loc, g)
        if v is not None:
            setn(node, g, v)
    sj[loc][NS] = node
    json.dump(sj[loc], open(f'lib/i18n/{loc}.i18n.json', 'w', encoding='utf-8'),
              ensure_ascii=False, indent=2)
    open(f'lib/i18n/{loc}.i18n.json', 'a').write('\n')

# ---- call sites ----
total = 0
for f in CLUSTER:
    s = open(f, encoding='utf-8').read(); n = 0
    for l, p in lit2path.items():
        s, c = re.subn(r"context\.l10n\.translate\(\s*'" + re.escape(l) + r"'\s*,?\s*\)",
                       f"context.t.{NS}.{p}", s); n += c
    for g in get_plain:
        o = f"context.l10n.{g}"; n += s.count(o); s = s.replace(o, f"context.t.{NS}.{g}")
    for g, pname in get_method.items():
        s, c = re.subn(r"context\.l10n\." + g + r"\(", f"context.t.{NS}.{g}({pname}: ", s); n += c
    if 'i18n/translations.g.dart' not in s:
        lines = s.split('\n')
        idx = max(i for i, ln in enumerate(lines) if ln.startswith('import '))
        rel = os.path.relpath('lib/i18n/translations.g.dart', os.path.dirname(f))
        lines.insert(idx + 1, f"import '{rel}';"); s = '\n'.join(lines)
    if 'core/localization.dart' in s and not re.search(r'\bl10n\b|AppLocalizations', s):
        s = re.sub(r"import '[^']*core/localization\.dart';\n", "", s)
    open(f, 'w', encoding='utf-8').write(s); total += n
    bal = (s.count('(') - s.count(')'), s.count('{') - s.count('}'))
    print(f"  {f.split('/')[-1]}: {n}" + (f"  IMBALANCE {bal}" if bal != (0, 0) else ""))

print(f"\nNS={NS}: migrated {total} sites | literal keys {len(lit2path)} | "
      f"plain getters {len(get_plain)} | single-method getters {len(get_method)}")
for k, v in deferred.items():
    if v:
        print(f"  DEFERRED {k} ({len(v)}): {sorted(set(v))[:12]}{' …' if len(set(v))>12 else ''}")
