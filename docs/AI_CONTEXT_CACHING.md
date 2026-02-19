# AI Context Library + Caching (Plain-Language Plan)

## Goal
Make AI-generated work summaries and commentaries consistently match FAA/spec language and your preferred report-writing style **without** having to paste the same reference material into the prompt every time.

This is accomplished by keeping a small “reference library” inside the app and automatically attaching only the **few most relevant** excerpts to each AI request.

## The Core Idea (How it Works)
Right now, the AI only knows what you send in the single request (report data + prompt text).

With a context library:
1. The app quickly pulls a **small handful** of relevant reference snippets (think: “sticky notes”) from a stored library of FAA/spec notes and writing examples.
2. Those snippets are included in the AI request.
3. The AI writes using the snippets as “house reference,” so the tone and phrasing stays consistent.

Key point: we are **not** sending the entire FAA library every time—only a few short excerpts.

## Why This Usually Won’t Slow Generation
AI generation time is typically dominated by the external AI call (network + model processing), which often takes multiple seconds.

The “find a few snippets” step is designed to be fast because:
- It uses a search index (like a normal search bar), not a full scan.
- It returns a fixed, small amount of text (example: 2–5 excerpts).

In practice, the lookup is usually “blink-speed” compared to the AI call.

## What the App Searches Against
Your context library can include:
- FAA/spec guidance text (your Markdown/plain-text notes)
- Short style rules (required phrasing, banned wording, preferred structure)
- A small set of writing samples (“gold standard” paragraphs)

Optional later: relevant excerpts from prior finalized reports (if you want the AI to mirror your historical voice even more closely).

## How the App Decides Which Snippets to Attach
It doesn’t have to be fancy to be useful.

The app can use obvious signals already present in the report:
- Spec codes/divisions involved (from spec checklists / bid items)
- Keywords from inspector commentary (e.g., tack coat, compaction, grade checks)
- Work categories (paving, grading, striping, lighting, drainage)

Then it attaches the top few best-matching excerpts.

## Caching (So Repeat Generations Are Even Faster)
Caching means: if you click “Generate” multiple times for the same report, the app doesn’t redo the “find snippets” step unless the report meaningfully changed.

A simple caching strategy:
- Build a “context fingerprint” from the fields that matter (commentary text, bid items, spec checklist codes, etc.)
- If the fingerprint is unchanged, reuse the previously selected snippets

Benefits:
- Faster repeat runs
- More consistent output (the references don’t shuffle between runs)

## Keeping the Prompt Small (The Context Budget)
To prevent large prompts (which can slow responses and increase cost), we enforce a strict context limit:
- Only include the top N excerpts (example: 3)
- Each excerpt is short (example: a paragraph or two)
- Total “reference” text stays under a set size

This is the most important performance control.

## Rollout Path (Start Simple, Improve if Needed)
**Phase 1 (MVP): keyword-based retrieval + caching**
- Works well when you have a curated FAA/spec note library with clear headings and keywords.
- Minimal infrastructure change.

**Phase 2 (Upgrade, only if needed): semantic retrieval**
- Better when different terms mean the same thing (e.g., “tack coat” vs “bond coat”).
- Improves matching quality when wording varies.

## Guardrails (So It Doesn’t “Make Up” Specs)
Add simple rules to the AI instructions:
- Use the attached FAA excerpts as references.
- Do not invent spec requirements that are not present in the report data or attached excerpts.
- If the report lacks needed detail, say so plainly instead of guessing.

## Operational Notes
- Your FAA notes live inside the app (as a maintained library).
- Updates are controlled: editing the library updates future generations.
- This approach avoids “prompt sprawl” (copy/paste walls of text) and keeps outputs consistent over time.

## Privacy / Sharing
Because this uses your internal FAA/spec notes, the AI request will include only the small selected excerpts for that report.

If later you decide certain sources should never be shared externally, the library can label them as “not allowed for AI injection” and those will be excluded.
