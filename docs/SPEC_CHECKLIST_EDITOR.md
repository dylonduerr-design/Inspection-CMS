# Spec Checklist Editor

A quick guide to editing specification-level checklist questions in the Projects Directory.

## Where it lives
- Open **Projects Directory** (`/projects`).
- Switch to the **Spec Checklist Editor** tab.
- Pick a spec from the left; changes save globally for that spec and immediately flow to any bid item that **does not** have its own checklist override.

## Quick start
1) Select a spec chip on the left (filter by division or search).
2) Review the questions on the right.
3) Add, edit, duplicate, or remove questions.
4) Click **Save Changes** to persist.

## Field reference (right panel)
- **Prompt** – The question text shown to inspectors.
- **Answer Type** – Input control to render:
  - **Radio (Yes / No / N/A)** – Single-choice; defaults to Yes/No/N/A options.
  - **Checkboxes** – Multi-select; supply one option per line.
  - **Short Text** – One-line text input.
  - **Long Text** – Multi-line textarea.
  - **Number** – Numeric input; min/max/step are enforced by the browser.
- **Required** – If checked, the question must be answered.
- **Placeholder** – Light hint shown inside text/number fields.
- **Default Value** – Pre-populates the field (radio/checkbox defaults select matching option text; text/number defaults fill the input).
- **Helper Text** – Small explanatory copy shown under the prompt.
- **Options (one per line)** – Only for Radio/Checkbox. One option per line; leave blank to fall back to Yes/No/N/A.
- **Min / Max / Step** – Only for Number. Browser-level constraints; `step` controls increment.
- **Pattern (regex)** – Only for Short/Long Text. A regex pattern string (e.g., `^[A-Za-z0-9\- ]+$`).
- **Duplicate / Remove** – Per-question actions in the card header.

## How saving works
- Saves via `PATCH /spec_items/:id` and replaces the spec’s `checklist_questions` JSON.
- Bid items inheriting from the spec will pick up the change automatically unless they have their own `checklist_questions` override.
- IDs are auto-generated from the prompt if not supplied; options are normalized and empty validation blocks are dropped.

## Tips & constraints
- Use meaningful prompts; IDs derive from prompts and are used as answer keys.
- For checkboxes, each option becomes a selectable value; multiple can be chosen.
- For number fields, use `step` for decimals (e.g., `0.25`).
- For text patterns, stick to anchored regexes to avoid unexpected matches.
- If you have unsaved edits and switch specs, the editor will ask before discarding changes.

## Troubleshooting
- **Can’t save / stale errors**: Ensure required fields are filled; check regex validity. The status line under the question list shows save errors returned by the server.
- **Changes not appearing in reports**: Confirm the affected bid item does **not** have its own checklist override. If it does, edit the bid item’s checklist directly.
- **Theme readability**: The editor uses design tokens for light/dark; if you see low-contrast text, refresh after theme toggle.
