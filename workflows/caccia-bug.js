export const meta = {
  name: 'caccia-bug',
  description: 'Caccia-bug light: un finder per lente (Opus) + un confutatore/validatore per finding (Haiku, effort high), con dedup, triage e conteggi. NON scrive file: ritorna i dati; il report lo scrive il comando top-level.',
  phases: [
    { title: 'Find', detail: 'un finder Opus per lente selezionata' },
    { title: 'Verify', detail: 'un confutatore/validatore Haiku per finding (dopo dedup)' },
  ],
}

// ---- input (da args del comando) ----
const lenses = (args && Array.isArray(args.lenses) && args.lenses.length) ? args.lenses : ['correttezza', 'robustezza']
const targetFiles = (args && Array.isArray(args.targetFiles)) ? args.targetFiles : []
const targetLabel = (args && args.targetLabel) || (targetFiles.length ? targetFiles.join(', ') : '(intero progetto)')
const exposureModel = (args && args.exposureModel) || 'sconosciuto'
const requirementsSource = (args && args.requirementsSource) || null
const maxPerLens = (args && Number.isInteger(args.maxPerLens)) ? args.maxPerLens : 12

// lenti "bug" (confutazione avversariale) vs "non-bug" (validazione dell'osservazione)
const BUG_LENSES = ['sicurezza', 'permessi', 'dati', 'robustezza', 'correttezza']
function modeFor(lens) { return BUG_LENSES.indexOf(lens) >= 0 ? 'bug' : 'validation' }

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
          impatto: { type: 'string', enum: ['A', 'B-pubblico', 'B-tecnico', 'C'] },
          nota: { type: 'string' },
        },
        required: ['area', 'file', 'lines', 'scenario', 'impatto'],
      },
    },
  },
  required: ['findings'],
}

const VERDICT_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    status: { type: 'string', enum: ['CONFERMATO', 'CONFUTATO', 'VALIDO', 'NON-VALIDO'] },
    motivazione: { type: 'string' },
    evidenza: { type: 'string' },
  },
  required: ['status', 'motivazione'],
}

function finderPrompt(lens) {
  const target = targetFiles.length
    ? `Bersaglio (leggi questi file INTERI col tuo Read/Grep/Glob):\n${targetFiles.map(f => '- ' + f).join('\n')}`
    : 'Bersaglio: INTERO progetto (parti dai file sorgente principali; usa Grep/Glob per orientarti).'
  const reqLine = lens === 'requisiti'
    ? (requirementsSource
        ? `Fonte-requisiti da usare per il confronto:\n${requirementsSource}`
        : 'ATTENZIONE: nessuna fonte-requisiti fornita → NON inventare requisiti, restituisci findings: [] e fermati.')
    : ''
  return [
    `Sei il finder della caccia-bug. LENTE ASSEGNATA: **${lens}**.`,
    `Modello di esposizione del progetto: **${exposureModel}** (usalo per stimare l'impatto in modo sensato per QUESTO tipo di codebase).`,
    target,
    reqLine,
    `Cerca SOLO con la lente "${lens}". Cita righe REALI (aprile prima di citarle). Massimo ${maxPerLens} segnalazioni, tieni le più forti. Se non c'è nulla di reale, restituisci findings: []. Segui il tuo formato Area·File:righe·Scenario·Impatto.`,
  ].filter(Boolean).join('\n\n')
}

function verifyPrompt(f, mode) {
  return [
    `Giudica UNA sola segnalazione di caccia-bug. MODO: **${mode}**.`,
    `Segnalazione:`,
    `- lente: ${f.lenses.join(', ')}`,
    `- area: ${f.area}`,
    `- file: ${f.file}`,
    `- lines: ${f.lines}`,
    `- scenario: ${f.scenario}`,
    `- impatto (stima del finder): ${f.impatto}`,
    f.nota ? `- nota: ${f.nota}` : '',
    mode === 'validation' && requirementsSource ? `Fonte-requisiti (se lente=requisiti):\n${requirementsSource}` : '',
    `Passo zero SEMPRE: verifica che ${f.file}:${f.lines} esista e dica ciò che la segnalazione afferma; se no → CONFUTATO/NON-VALIDO (allucinata).`,
    mode === 'bug'
      ? `Modo bug: prova a CONFUTARLA leggendo il codice reale; in dubbio CONFUTA. Verdetto CONFERMATO/CONFUTATO con evidenza (file:riga reale).`
      : `Modo validation: VERIFICA l'osservazione (codice-morto→cerca gli usi con Grep; efficienza→è materiale?; requisiti→viola davvero la fonte?). Verdetto VALIDO/NON-VALIDO con evidenza.`,
  ].filter(Boolean).join('\n')
}

// ---- FIND: un finder per lente, in parallelo (barrier per poter deduplicare cross-lente) ----
phase('Find')
log(`Caccia su ${targetLabel} — lenti: ${lenses.join(', ')} — esposizione: ${exposureModel}`)
const perLens = await parallel(lenses.map((lens) => () =>
  agent(finderPrompt(lens), { label: `find:${lens}`, phase: 'Find', model: 'opus', agentType: 'keel:bug-finder', schema: FINDINGS_SCHEMA })
    .then((r) => (r && Array.isArray(r.findings) ? r.findings.map((f) => Object.assign({}, f, { lens })) : []))
))
const allFindings = perLens.filter(Boolean).reduce((acc, arr) => acc.concat(arr), [])

// dedup per file:lines (fonde le lenti che trovano lo stesso punto)
const byKey = {}
for (const f of allFindings) {
  const key = (f.file || '?') + ':' + (f.lines || '?')
  if (!byKey[key]) byKey[key] = Object.assign({}, f, { lenses: [f.lens] })
  else if (byKey[key].lenses.indexOf(f.lens) < 0) byKey[key].lenses.push(f.lens)
}
const deduped = Object.keys(byKey).map((k) => byKey[k])
log(`${allFindings.length} grezze → ${deduped.length} dopo dedup per file:righe`)

// ---- VERIFY: un confutatore/validatore per finding, lens-aware, in parallelo ----
phase('Verify')
const verified = await parallel(deduped.map((f) => () =>
  agent(verifyPrompt(f, modeFor(f.lenses[0])), { label: `verify:${f.file}`, phase: 'Verify', model: 'fable', effort: 'high', agentType: 'keel:bug-refuter', schema: VERDICT_SCHEMA })
    .then((v) => Object.assign({}, f, { verdict: v }))
))
const results = verified.filter(Boolean)
function survives(r) { return r.verdict && (r.verdict.status === 'CONFERMATO' || r.verdict.status === 'VALIDO') }
const confirmed = results.filter(survives)
const rejected = results.filter((r) => !survives(r))
log(`confermati ${confirmed.length} / scartati ${rejected.length}`)

return {
  target: targetLabel,
  exposureModel,
  lenses,
  counts: { grezze: allFindings.length, deduped: deduped.length, confirmed: confirmed.length, rejected: rejected.length },
  confirmed,
  rejected,
}
