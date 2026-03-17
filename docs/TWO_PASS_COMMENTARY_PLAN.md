# Two-Pass AI Commentary Generation — Implementation Plan

## Background / Problem Statement

The current AI commentary generation is a single LLM call that asks the model to do two
cognitively distinct things simultaneously:

1. **Analyze** a large, multi-section JSON payload (bid items, QA entries, spec checklists,
   compliance flags, workforce, equipment, weather) and decide what is important.
2. **Write** a professional narrative in a very specific construction-inspection style.

The result is output that is too generic and occasionally too verbose — the model lacks the
focused context it needs to write with the specificity we want (e.g., correctly describing
tack-coat application rate, roller types, compaction sequencing, etc.).

The `work_summary` intent is being retired as a user-facing feature. Rather than removing it,
we repurpose it as an internal first pass — an outline extraction step — before the writing
step. This mirrors the existing map-reduce pattern already used for the weekly work summary.

---

## Architecture: Two-Pass Pipeline

```
User clicks "Generate Commentary"
          │
          ▼
ReportAiGenerateJob (intent: 'commentary')
          │
          ├─ Pass 1: commentary_outline
          │    └─ Full report payload → LLM → Structured facts outline
          │         (saved to report.ai_work_summary for transparency)
          │
          └─ Pass 2: commentary  (receives outline + original commentary)
               └─ Outline + inspector notes → LLM → Final prose commentary
                    (saved to report.ai_generated_commentary)
```

### Why This Helps

By splitting the two responsibilities, each pass can be optimized independently:

- **Pass 1 (Outline)** gets all the raw data and focuses purely on extraction and triage:
  what bid items were placed, what quantities, what QA results, what checklist answers
  indicate specific activities, which FAA spec items are in play, any compliance issues.
- **Pass 2 (Write)** receives a clean, pre-digested outline and focuses entirely on tone,
  style, and structure. The model is free to write well because it is not also parsing data.

This is identical in concept to the `weekly_work_summary_map` → `weekly_work_summary`
chunked generation already implemented in `AzureGenerator`.

---

## Implementation Steps

### Phase 1 — Repurpose `work_summary` as the outline extraction pass

**1. Add `commentary_outline` intent to `PromptTemplates`**

Add `COMMENTARY_OUTLINE_SYSTEM_PROMPT` and `COMMENTARY_OUTLINE_USER_PROMPT` constants.

The outline system prompt instructs the model to:
- Extract bid items placed (code, description, quantity, location)
- Summarize QA results by category (what was tested, pass/fail/OOT)
- Surface checklist answers that indicate specific activities
  (e.g. "Surface cleaned before tack: Yes", "Nozzles inspected: Yes")
- Flag compliance status, deficiencies, and safety incidents
- List which FAA spec items are involved (P-401, P-603, P-152, etc.) so Pass 2
  can select the right style examples
- Output in structured format (bold category headers + bullets) — **no prose**

The outline user prompt receives the same rich data payload the current commentary
prompt receives (QA entries, spec checklists, bid item checklists, compliance fields).

**2. Refocus `COMMENTARY_SYSTEM_PROMPT` and `COMMENTARY_USER_PROMPT`**

- System prompt becomes purely about writing style and voice.
- Expand the spec-item examples section from 3 examples to 5–8+, organized by
  category (tack coat, paving, compaction, grading, drainage, etc.). These are the
  primary driver of output specificity.
- User prompt is simplified: it receives the **outline from Pass 1** plus the
  **original inspector commentary** — no raw QA entries, checklists, or compliance
  fields. Those are already captured in the outline.

**3. Update `for_intent` switch and `ALL_INTENTS` in `Generator`**

Add `'commentary_outline'` to the known intents. The `work_summary` intent can remain
registered for backwards compatibility but should not be user-facing.

---

### Phase 2 — Prompt engineering

**4. New outline extraction prompt** (`commentary_outline`)

```
System:
  You are an assistant that extracts and organizes key facts from construction
  inspection daily reports for use by a subsequent AI writing pass.

  Your output should be:
  - Grouped under bold category headers (e.g., **Bid Items Placed:**, **QA / Testing:**)
  - Concise bullet points — one key fact per line
  - Include quantities, locations, and pass/fail results wherever present
  - Identify which FAA spec items are in scope (P-401, P-603, P-152, etc.)
  - Flag any compliance issues, deficiencies, or safety incidents
  - Note checklist answers that indicate process compliance
    (e.g., "Surface swept before tack: Yes", "Tack rate verified: Yes")
  - Do NOT write prose or paragraphs — structured facts only
  - Do NOT speculate or add information not present in the data
```

**5. Updated writing prompt** (`commentary`)

Key changes from the current prompt:
- Receives the outline rather than raw data fields
- More and better-organized spec-item examples covering common FAA items
- Explicit instruction: do not add detail not present in the outline
- Explicit instruction: prefer specific technical language over generic descriptions

**6. Spec-item example library** (to be added to writing system prompt)

Start with examples for the most common spec items and grow over time. Each example
follows the input → output pattern already established in the current prompt:

| Spec Item | Input phrase | Expected output style |
|-----------|-------------|----------------------|
| P-603 Tack | "tack clean, correct rate" | describe surface prep, nozzle check, rate verification per FAA specs |
| P-401 Paving | "mat placed, no issues" | describe lift placement, temperature, method of spread |
| P-401 Compaction | "no issues with compaction" | describe roller types, sequencing, temperature cutoff |
| P-152 Earthwork | "grades checked" | describe grade-checking method, survey equipment, field verification |
| P-501 Concrete | "forms set, pour completed" | describe form inspection, pour method, curing |
| Drainage | "pipe installed" | describe pipe type, bedding, alignment checks |

**The most impactful short-term action is collecting approved commentaries from
inspectors, tagged by spec code.** These become seed data for RAG retrieval later.

---

### Phase 3 — Wire up the pipeline

**7. Update `AzureGenerator`**

Add a `generate_commentary_with_outline!(payload)` private method, modeled after the
existing `generate_chunked_work_summary(payload)`:

```ruby
def generate_commentary_with_outline!(payload)
  # Pass 1 — extraction
  Rails.logger.info("[ReportAi::AzureGenerator] Commentary Pass 1: extracting outline")
  sys1 = PromptTemplates.system_prompt(intent: 'commentary_outline')
  usr1 = PromptTemplates.render_user_prompt(intent: 'commentary_outline', payload: payload)
  outline_response = call_azure_api([
    { role: 'system', content: sys1 },
    { role: 'user',   content: usr1 }
  ])
  outline = extract_content(outline_response)

  # Pass 2 — writing
  Rails.logger.info("[ReportAi::AzureGenerator] Commentary Pass 2: writing commentary")
  outline_payload = payload.merge(commentary_outline: outline)
  sys2 = PromptTemplates.system_prompt(intent: 'commentary')
  usr2 = PromptTemplates.render_user_prompt(intent: 'commentary', payload: outline_payload)
  writing_response = call_azure_api([
    { role: 'system', content: sys2 },
    { role: 'user',   content: usr2 }
  ])
  final = extract_content(writing_response)

  { outline: outline, commentary: final }
end
```

Route to this method from `generate!` when `intent == 'commentary'`.

**8. Update `ReportAiGenerateJob`**

When intent is `commentary`, the job:

```ruby
result = generator.generate!(payload: payload, intent: 'commentary')
# result is now { outline:, commentary: }

report.update_columns(
  ai_status: 'success',
  ai_generated_at: Time.current,
  ai_work_summary: result[:outline],          # repurposed column
  ai_generated_commentary: result[:commentary],
  ai_error: nil
)
```

This is atomic — if either pass fails, the whole job fails and neither field is updated.

**9. Update `FakeGenerator`**

Return a plausible fake outline string for `'commentary_outline'` and the existing fake
commentary for `'commentary'`. Ensure `generate!` for `'commentary'` returns
`{ outline:, commentary: }` in the fake implementation to match the real generator.

---

### Phase 4 — UI adjustments

**10. Remove the "Generate Work Summary" button**

The `work_summary` intent is no longer user-facing. The "Generate Commentary" button
now triggers the full two-pass pipeline.

Update `ai_generation_controller.js`:
- Remove or hide `workSummaryBtn` target and the `generateWorkSummary` handler
- The commentary button now triggers `triggerGeneration('commentary')` as before
- Optionally add a collapsible "View Outline" section populated from `ai_work_summary`
  so inspectors (and developers) can see what Pass 1 extracted

**11. Update `ReportsController`**

- `generate_work_summary` action can be removed or return a `410 Gone` / redirect
  if the route is still registered
- `ai_status` endpoint already returns `ai_work_summary` — no changes needed there

---

## Broadcasting Status Updates

### The Problem

Two sequential API calls roughly double the generation time (~20–40 seconds vs ~10–20
seconds currently). The existing polling loop shows a static "⏳ AI generation in
progress..." message for the entire duration. Users may assume it has stalled and click
the button again or abandon the page.

### Approach: `ai_stage` Column + Polling

The current system uses HTTP polling every 5 seconds (see
`ai_generation_controller.js` → `startPolling()` / `checkStatus()`). The simplest
enhancement — without introducing ActionCable to this flow — is to add an `ai_stage`
string column to the `reports` table and update it mid-job. The polling endpoint already
returns all relevant report fields, so it just needs to include the new field.

This avoids adding WebSocket infrastructure to the AI generation path and keeps the
polling approach consistent.

#### Migration

```ruby
# db/migrate/YYYYMMDDHHMMSS_add_ai_stage_to_reports.rb
class AddAiStageToReports < ActiveRecord::Migration[7.1]
  def change
    add_column :reports, :ai_stage, :string
  end
end
```

#### Job updates (`ReportAiGenerateJob`)

```ruby
# At job start
report.update_columns(ai_status: 'running', ai_stage: 'outline', ai_error: nil)

# After Pass 1 completes
report.update_columns(ai_stage: 'writing')

# On success
report.update_columns(
  ai_status: 'success',
  ai_stage: nil,
  ai_generated_at: Time.current,
  ai_work_summary: result[:outline],
  ai_generated_commentary: result[:commentary],
  ai_error: nil
)

# On failure
report.update_columns(ai_status: 'failed', ai_stage: nil, ai_error: error_message)
```

#### Controller update (`ReportsController#ai_status`)

Add `ai_stage` to the JSON response:

```ruby
render json: {
  status: @report.ai_status,
  ai_stage: @report.ai_stage,         # "outline" | "writing" | nil
  ai_work_summary: @report.ai_work_summary,
  ai_generated_commentary: @report.ai_generated_commentary,
  ai_generated_at: @report.ai_generated_at&.iso8601,
  ai_error: @report.ai_error
}
```

#### JS controller update (`ai_generation_controller.js`)

Replace the static "in progress" message with a stage-aware one:

```javascript
} else if (data.status === 'queued' || data.status === 'running') {
  const stageMessages = {
    outline:  '⏳ Analyzing report data...',
    writing:  '✍️  Writing commentary...',
  }
  const msg = stageMessages[data.ai_stage] || '⏳ AI generation in progress...'
  this.showStatus(msg)
  if (!this.pollInterval) {
    this.startPolling()
  }
}
```

#### Stage progression summary

| Stage value | Displayed message | When set |
|-------------|-------------------|----------|
| `"outline"` | ⏳ Analyzing report data... | Job starts, before Pass 1 |
| `"writing"` | ✍️ Writing commentary... | Pass 1 complete, before Pass 2 |
| `nil` | (cleared) | On success or failure |

### Alternative: ActionCable (Future)

The `ReportExportJob` already broadcasts real-time progress via ActionCable
(`ReportExportChannel`). If sub-second update granularity becomes important or the
polling latency feels too coarse, the AI generation flow could adopt the same pattern.
For now the polling approach is sufficient — the 5-second poll interval is short relative
to the expected pass durations (~10–20s each) and the `ai_stage` column ensures the
first status check after a pass transition will show the updated message promptly.

---

## Relevant Files

| File | Changes |
|------|---------|
| `app/services/report_ai/prompt_templates.rb` | New `commentary_outline` prompts; rewritten `commentary` prompts with more examples; new intent routing |
| `app/services/report_ai/azure_generator.rb` | `generate_commentary_with_outline!` method; route `commentary` intent through it |
| `app/services/report_ai/generator.rb` | Add `commentary_outline` to `ALL_INTENTS` |
| `app/services/report_ai/fake_generator.rb` | Fake response for `commentary_outline`; `commentary` returns `{outline:, commentary:}` |
| `app/jobs/report_ai_generate_job.rb` | Handle two-pass result hash; update `ai_stage` during execution |
| `app/controllers/reports_controller.rb` | Add `ai_stage` to `ai_status` response; retire `generate_work_summary` action |
| `app/javascript/controllers/ai_generation_controller.js` | Remove work-summary button; stage-aware status messages |
| `db/migrate/..._add_ai_stage_to_reports.rb` | Add `ai_stage` string column |

---

## Verification Checklist

- [ ] Existing test suite passes: `bundle exec rails test`
- [ ] With `FakeGenerator`: trigger commentary generation; verify both passes run and
      `ai_work_summary` (outline) and `ai_generated_commentary` (prose) are saved
- [ ] Status polling during generation shows "Analyzing report data..." then
      "Writing commentary..." before completing
- [ ] With Azure: generate commentary for a data-rich report (has bid items, QA entries,
      spec checklists); compare output specificity to current single-pass output
- [ ] Reports with minimal data (no QA, no checklists) still produce reasonable commentary
- [ ] `ai_stage` clears to `nil` on both success and failure paths

---

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Retire `ai_work_summary` column? | No — repurpose it for the outline | Avoids a migration; outline is useful for debugging and transparency |
| Status communication | `ai_stage` DB column + polling | Consistent with existing polling architecture; no new infrastructure |
| Single job or two jobs | Single job, two API calls | Keeps the pipeline atomic; failure in either pass fails cleanly |
| Intent name | `commentary_outline` (new) | Clearer than repurposing `work_summary`; `work_summary` can remain registered but retired from UI |
| Spec examples | Hardcoded in prompt now | RAG retrieval is the long-term goal; collect approved exemplars from inspectors (tagged by spec code) as seed data |

---

## Further Considerations

1. **Token cost** — Two API calls doubles the cost per commentary generation. The outline
   pass should be relatively cheap (~500–1,000 output tokens). Monitor via Azure OpenAI
   usage metrics after deployment.

2. **Spec example sourcing** — The most impactful near-term quality improvement is
   collecting real, approved commentaries from inspectors, tagged by spec code (P-401,
   P-603, P-152, etc.). Even 2–3 high-quality examples per item will noticeably improve
   output specificity. These become the seed data for eventual RAG retrieval.

3. **RAG path** — Once a library of exemplar commentaries exists per spec code, the
   outline pass can identify which spec items are in scope, and the writing pass can
   retrieve the relevant examples dynamically instead of including all of them in the
   system prompt. This is the natural evolution of the spec-example library.
