export const meta = {
  name: 'bug-hunt',
  description: 'Light bug hunt: one finder per lens (Opus) + one refuter/validator per finding (Fable, effort high), with dedup, triage and counts. Does NOT write files: it returns the data; the top-level command writes the report.',
  phases: [
    { title: 'Find', detail: 'one Opus finder per selected lens and per functional flow' },
    { title: 'Verify', detail: 'one Fable refuter/validator per finding (after dedup)' },
  ],
}

// ---- input (from the command's args) ----
// explicit empty array = "flows-only" mode (0 lenses): respect it. Default 2 lenses only if lenses is absent.
const lenses = (args && Array.isArray(args.lenses)) ? args.lenses : ['correctness', 'robustness']
const targetFiles = (args && Array.isArray(args.targetFiles)) ? args.targetFiles : []
const targetLabel = (args && args.targetLabel) || (targetFiles.length ? targetFiles.join(', ') : '(whole project)')
const exposureModel = (args && args.exposureModel) || 'unknown'
const requirementsSource = (args && args.requirementsSource) || null
const maxPerLens = (args && Number.isInteger(args.maxPerLens)) ? args.maxPerLens : 12
// functional flows (expected-result method): [{ label, spec }]
const functionalFlows = (args && Array.isArray(args.functionalFlows)) ? args.functionalFlows : []

// "bug" lenses (adversarial refutation) vs "non-bug" lenses (validate the observation)
const BUG_LENSES = ['security', 'permissions', 'data', 'robustness', 'correctness']
function modeFor(lens) {
  if (typeof lens === 'string' && lens.indexOf('flow:') === 0) return 'bug' // functional flows are bug mode (expected-vs-obtained)
  return BUG_LENSES.indexOf(lens) >= 0 ? 'bug' : 'validation'
}

const FINDINGS_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        properties: {
          area: { type: 'string' },
          file: { type: 'string' },
          lines: { type: 'string' },
          scenario: { type: 'string' },
          impact: { type: 'string', enum: ['A', 'B-public', 'B-technical', 'C'] },
          note: { type: 'string' },
          // structured fields ONLY for functional-flow findings (expected-result method)
          object: { type: 'string' },
          preconditions: { type: 'string' },
          sequence: { type: 'string' },
          expected: { type: 'string' },
          obtained: { type: 'string' },
        },
        required: ['area', 'file', 'lines', 'scenario', 'impact'],
      },
    },
  },
  required: ['findings'],
}

const VERDICT_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    status: { type: 'string', enum: ['CONFIRMED', 'REFUTED', 'VALID', 'INVALID'] },
    rationale: { type: 'string' },
    evidence: { type: 'string' },
  },
  required: ['status', 'rationale'],
}

function finderPrompt(lens) {
  const target = targetFiles.length
    ? `Target (read these WHOLE files with your Read/Grep/Glob):\n${targetFiles.map(f => '- ' + f).join('\n')}`
    : 'Target: the WHOLE project (start from the main source files; use Grep/Glob to orient yourself).'
  const reqLine = lens === 'requirements'
    ? (requirementsSource
        ? `Requirements source to compare against:\n${requirementsSource}`
        : 'WARNING: no requirements source provided → do NOT invent requirements, return findings: [] and stop.')
    : ''
  return [
    `You are the bug-hunt finder. ASSIGNED LENS: **${lens}**.`,
    `Project exposure model: **${exposureModel}** (use it to estimate impact sensibly for THIS kind of codebase).`,
    target,
    reqLine,
    `Search ONLY with the "${lens}" lens. Cite REAL lines (open them before citing). At most ${maxPerLens} findings, keep the strongest. If there is nothing real, return findings: []. Follow your format Area·File:lines·Scenario·Impact.`,
  ].filter(Boolean).join('\n\n')
}

function functionalFinderPrompt(flow) {
  const label = (flow && flow.label) || '(flow)'
  const spec = (flow && flow.spec) || ''
  const target = targetFiles.length
    ? `Target (read these WHOLE files with your Read/Grep/Glob):\n${targetFiles.map(f => '- ' + f).join('\n')}`
    : 'Target: the WHOLE project (start from the main source files; use Grep/Glob to orient yourself).'
  return [
    `You are the bug-hunt finder. ASSIGNED FUNCTIONAL FLOW: **${label}**. Use the EXPECTED-RESULT METHOD.`,
    `Project exposure model: **${exposureModel}** (use it to estimate impact).`,
    target,
    spec
      ? `Expected anchored to intent (the flow's spec/source):\n${spec}`
      : `WARNING: no spec for this flow → derive the expected from design-logs/README/spec; if you can only get it from the code under test, mark it "(assumed, unverified)" inside the expected field and don't treat it as certain.`,
    `Proceed BY TEST: object → preconditions → sequence → EXPECTED (from intent, NEVER from the behavior of the code under test) → OBTAINED (from the real code, traced). Report a bug ONLY if EXPECTED ≠ OBTAINED, with real file:lines of the divergence point. Fill the structured fields object/preconditions/sequence/expected/obtained. Cite REAL lines. At most ${maxPerLens} findings; if expected and obtained match, return findings: [].`,
  ].filter(Boolean).join('\n\n')
}

function verifyPrompt(f, mode) {
  return [
    `Judge ONE single bug-hunt finding. MODE: **${mode}**.`,
    `Finding:`,
    `- lens: ${f.lenses.join(', ')}`,
    `- area: ${f.area}`,
    `- file: ${f.file}`,
    `- lines: ${f.lines}`,
    `- scenario: ${f.scenario}`,
    `- impact (finder's estimate): ${f.impact}`,
    f.note ? `- note: ${f.note}` : '',
    (f.expected || f.obtained)
      ? `- object: ${f.object || ''}\n- preconditions: ${f.preconditions || ''}\n- sequence: ${f.sequence || ''}\n- expected: ${f.expected || ''}\n- obtained: ${f.obtained || ''}`
      : '',
    mode === 'validation' && requirementsSource ? `Requirements source (if lens=requirements):\n${requirementsSource}` : '',
    `Step zero ALWAYS: verify that ${f.file}:${f.lines} exists and says what the finding claims; if not → REFUTED/INVALID (hallucinated).`,
    mode === 'bug'
      ? ((f.expected || f.obtained)
          ? `Bug mode (FUNCTIONAL FLOW): verify on the real code that (1) the OBTAINED is true, (2) EXPECTED ≠ OBTAINED holds, (3) the EXPECTED is anchored to INTENT (design-log/spec/user), NOT the code under test restated (circular expected = REFUTED). Verdict CONFIRMED/REFUTED with the real file:line of the divergence point.`
          : `Bug mode: try to REFUTE it by reading the real code; when in doubt REFUTE. Verdict CONFIRMED/REFUTED with evidence (real file:line).`)
      : `Validation mode: VERIFY the observation (dead-code→search for uses with Grep; efficiency→is it material?; requirements→does it really violate the source?). Verdict VALID/INVALID with evidence.`,
  ].filter(Boolean).join('\n')
}

// ---- FIND: one finder per lens AND per functional flow, in parallel (barrier so we can dedup) ----
phase('Find')
log(`Hunting on ${targetLabel} — lenses: ${lenses.join(', ') || '—'} — flows: ${functionalFlows.length} — exposure: ${exposureModel}`)
const lensTasks = lenses.map((lens) => () =>
  agent(finderPrompt(lens), { label: `find:${lens}`, phase: 'Find', model: 'opus', agentType: 'keel:bug-finder', schema: FINDINGS_SCHEMA })
    .then((r) => (r && Array.isArray(r.findings) ? r.findings.map((f) => Object.assign({}, f, { lens })) : []))
)
const flowTasks = functionalFlows.map((flow) => () => {
  const lens = 'flow:' + ((flow && flow.label) || '?')
  return agent(functionalFinderPrompt(flow), { label: `find:${lens}`, phase: 'Find', model: 'opus', agentType: 'keel:bug-finder', schema: FINDINGS_SCHEMA })
    .then((r) => (r && Array.isArray(r.findings) ? r.findings.map((f) => Object.assign({}, f, { lens })) : []))
})
const perFinder = await parallel(lensTasks.concat(flowTasks))
const allFindings = perFinder.filter(Boolean).reduce((acc, arr) => acc.concat(arr), [])

// dedup by file:lines (merges lenses that hit the same spot)
const byKey = {}
for (const f of allFindings) {
  const key = (f.file || '?') + ':' + (f.lines || '?')
  if (!byKey[key]) byKey[key] = Object.assign({}, f, { lenses: [f.lens] })
  else if (byKey[key].lenses.indexOf(f.lens) < 0) byKey[key].lenses.push(f.lens)
}
const deduped = Object.keys(byKey).map((k) => byKey[k])
log(`${allFindings.length} raw → ${deduped.length} after dedup by file:lines`)

// ---- VERIFY: one refuter/validator per finding, lens-aware, in parallel ----
phase('Verify')
const verified = await parallel(deduped.map((f) => () =>
  agent(verifyPrompt(f, modeFor(f.lenses[0])), { label: `verify:${f.file}`, phase: 'Verify', model: 'fable', effort: 'high', agentType: 'keel:bug-refuter', schema: VERDICT_SCHEMA })
    .then((v) => Object.assign({}, f, { verdict: v }))
))
const results = verified.filter(Boolean)
function survives(r) { return r.verdict && (r.verdict.status === 'CONFIRMED' || r.verdict.status === 'VALID') }
const confirmed = results.filter(survives)
const rejected = results.filter((r) => !survives(r))
log(`confirmed ${confirmed.length} / rejected ${rejected.length}`)

return {
  target: targetLabel,
  exposureModel,
  lenses,
  functionalFlows: functionalFlows.map((fl) => (fl && fl.label) || '?'),
  counts: { raw: allFindings.length, deduped: deduped.length, confirmed: confirmed.length, rejected: rejected.length },
  confirmed,
  rejected,
}
