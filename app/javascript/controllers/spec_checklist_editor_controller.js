import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "divisionSelect",
    "searchInput",
    "specList",
    "specOption",
    "emptyState",
    "editor",
    "currentSpecHeading",
    "currentSpecDescription",
    "questionCount",
    "questions",
    "saveButton",
    "status"
  ]

  connect() {
    this.csrfToken = document.querySelector('meta[name="csrf-token"]')?.content || ""
    this.specs = this.loadSpecs()
    this.specMap = new Map(this.specs.map((spec) => [spec.id, spec]))
    this.currentSpec = null
    this.questions = []
    this.isDirty = false
    this.isSaving = false
  }

  disconnect() {
    this.specs = []
    this.specMap = new Map()
    this.currentSpec = null
    this.questions = []
    this.isDirty = false
    this.isSaving = false
  }

  loadSpecs() {
    const node = document.getElementById("spec-checklist-editor-data")
    if (!node) return []

    try {
      return JSON.parse(node.textContent || "[]")
    } catch (error) {
      console.error("Spec checklist editor: unable to parse spec data", error)
      return []
    }
  }

  filterList() {
    const term = (this.hasSearchInputTarget ? this.searchInputTarget.value : "").toLowerCase().trim()
    const division = this.hasDivisionSelectTarget ? this.divisionSelectTarget.value : ""

    this.specOptionTargets.forEach((button) => {
      const matchesDivision = division === "" || (button.dataset.division || "") === division
      const haystack = (button.dataset.search || "").toLowerCase()
      const matchesTerm = term === "" || haystack.includes(term)
      button.classList.toggle("is-hidden", !(matchesDivision && matchesTerm))
    })
  }

  selectSpec(event) {
    const button = event.currentTarget
    const id = Number.parseInt(button.dataset.specId, 10)
    if (!id) return

    // Warn if there are unsaved changes
    if (this.isDirty) {
      if (!confirm("You have unsaved changes. Discard them and switch specs?")) {
        return
      }
    }

    this.specOptionTargets.forEach((option) => {
      option.classList.toggle("is-selected", option === button)
    })

    const spec = this.specMap.get(id)
    if (!spec) return

    this.currentSpec = this.deepClone(spec)
    this.questions = this.normalizeQuestions(this.currentSpec.checklist_questions || [])
    this.showEditor()
    this.renderQuestions()
    this.currentSpecHeadingTarget.textContent = `${spec.code} · ${spec.description}`
    this.currentSpecDescriptionTarget.textContent = spec.division || ""
    this.updateQuestionCount()
    this.markSaved("Loaded checklist.")
  }

  addQuestion() {
    if (!this.currentSpec) return
    this.questions.push(this.blankQuestion(this.questions.length))
    this.renderQuestions()
    this.updateQuestionCount()
    this.markDirty("New question added.")
  }

  removeQuestion(event) {
    const index = Number.parseInt(event.currentTarget.dataset.index, 10)
    if (Number.isNaN(index)) return
    this.questions.splice(index, 1)
    this.renderQuestions()
    this.updateQuestionCount()
    this.markDirty("Question removed.")
  }

  handleFieldChange(event) {
    const index = Number.parseInt(event.currentTarget.dataset.index, 10)
    const field = event.currentTarget.dataset.field
    if (Number.isNaN(index) || !field || !this.questions[index]) return

    let value
    if (event.currentTarget.type === "checkbox") {
      value = event.currentTarget.checked
    } else if (field === "options") {
      value = event.currentTarget.value
        .split(/\r?\n/)
        .map((opt) => opt.trim())
        .filter((opt) => opt.length > 0)
    } else if (field.startsWith("validation.")) {
      value = event.currentTarget.value
      const [, key] = field.split(".")
      this.questions[index].validation = this.questions[index].validation || {}
      if (value === "") {
        delete this.questions[index].validation[key]
      } else {
        this.questions[index].validation[key] = this.castValue(value)
      }
      this.markDirty()
      return
    } else {
      value = event.currentTarget.value
    }

    if (field === "kind") {
      this.questions[index].kind = value
      if (["radio", "checkbox", "select"].includes(value)) {
        this.questions[index].options = this.questions[index].options?.length ? this.questions[index].options : this.defaultOptions()
      } else {
        delete this.questions[index].options
      }
      if (value !== "number") {
        delete this.questions[index].validation?.min
        delete this.questions[index].validation?.max
        delete this.questions[index].validation?.step
      }
      if (!this.questions[index].validation) this.questions[index].validation = {}
      this.renderQuestions()
    } else if (field === "options") {
      this.questions[index].options = value
    } else if (field === "required") {
      this.questions[index].required = !!value
    } else {
      this.questions[index][field] = value
    }

    this.markDirty()
  }

  saveChanges() {
    if (!this.currentSpec || this.isSaving) return

    const payload = {
      spec_item: {
        checklist_questions: this.questions.map((question, idx) => this.prepareQuestionForSave(question, idx))
      }
    }

    this.isSaving = true
    this.saveButtonTarget.disabled = true
    const originalLabel = this.saveButtonTarget.textContent
    this.saveButtonTarget.textContent = "Saving..."
    this.statusTarget.textContent = "Saving changes..."

    fetch(`/spec_items/${this.currentSpec.id}`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.csrfToken
      },
      body: JSON.stringify(payload)
    })
      .then((response) => {
        if (!response.ok) throw response
        return response.json()
      })
      .then((data) => {
        if (data.status !== "ok") throw data
        this.specMap.set(data.spec_item.id, data.spec_item)
        this.currentSpec = this.deepClone(data.spec_item)
        this.questions = this.normalizeQuestions(this.currentSpec.checklist_questions || [])
        this.renderQuestions()
        this.updateQuestionCount()
        this.markSaved("Checklist updated.")
      })
      .catch(async (error) => {
        let message = "Unable to save changes."
        try {
          if (error instanceof Response) {
            const data = await error.json()
            if (Array.isArray(data.errors)) {
              message = data.errors.join(", ")
            } else if (data.message) {
              message = data.message
            }
          } else if (error?.errors) {
            message = Array.isArray(error.errors) ? error.errors.join(", ") : String(error.errors)
          }
        } catch (e) {
          console.error("Error parsing response:", e)
        }
        console.error("Save failed:", error)
        this.statusTarget.textContent = message
        this.saveButtonTarget.disabled = false
      })
      .finally(() => {
        this.isSaving = false
        this.saveButtonTarget.textContent = originalLabel
      })
  }

  showEditor() {
    this.emptyStateTarget.classList.add("d-none")
    this.editorTarget.classList.remove("d-none")
  }

  renderQuestions() {
    if (!this.questions.length) {
      this.questionsTarget.innerHTML = '<p class="spec-question-empty">No checklist questions yet.</p>'
      return
    }

    this.questionsTarget.innerHTML = this.questions
      .map((question, index) => this.questionCardMarkup(question, index))
      .join("\n")
  }

  questionCardMarkup(question, index) {
    const kindOptions = this.kindChoices()
      .map(({ value, label }) => `<option value="${value}" ${question.kind === value ? "selected" : ""}>${label}</option>`)
      .join("")

    const requiredChecked = question.required ? "checked" : ""
    const optionsField = this.optionsFieldMarkup(question, index)
    const validationFields = this.validationFieldsMarkup(question, index)

    return `
      <article class="spec-question-card" data-index="${index}">
        <header class="spec-question-card__header">
          <div>
            <span class="pill-badge">Q${index + 1}</span>
            <span class="spec-question-card__type">${this.escapeHtml(question.kind)}</span>
          </div>
          <div class="spec-question-card__tools">
            <button type="button" class="link-muted" data-action="spec-checklist-editor#duplicateQuestion" data-index="${index}">Duplicate</button>
            <button type="button" class="link-danger" data-action="spec-checklist-editor#removeQuestion" data-index="${index}">Remove</button>
          </div>
        </header>
        <div class="spec-question-card__body">
          <label class="spec-question-label">Prompt</label>
          <input type="text" class="spec-question-input" value="${this.escapeHtml(question.prompt)}" data-field="prompt" data-index="${index}" data-action="input->spec-checklist-editor#handleFieldChange">

          <div class="spec-question-row">
            <div>
              <label class="spec-question-label">Answer Type</label>
              <select class="spec-question-input" data-field="kind" data-index="${index}" data-action="change->spec-checklist-editor#handleFieldChange">
                ${kindOptions}
              </select>
            </div>
            <div class="spec-question-required">
              <label>
                <input type="checkbox" ${requiredChecked} data-field="required" data-index="${index}" data-action="change->spec-checklist-editor#handleFieldChange">
                Required
              </label>
            </div>
          </div>

          <div class="spec-question-row">
            <div>
              <label class="spec-question-label">Placeholder</label>
              <input type="text" class="spec-question-input" value="${this.escapeHtml(question.placeholder || "")}" data-field="placeholder" data-index="${index}" data-action="input->spec-checklist-editor#handleFieldChange">
            </div>
            <div>
              <label class="spec-question-label">Default Value</label>
              <input type="text" class="spec-question-input" value="${this.escapeHtml(question.default_value || "")}" data-field="default_value" data-index="${index}" data-action="input->spec-checklist-editor#handleFieldChange">
            </div>
          </div>

          <label class="spec-question-label">Helper Text</label>
          <textarea class="spec-question-input" rows="2" data-field="help_text" data-index="${index}" data-action="input->spec-checklist-editor#handleFieldChange">${this.escapeHtml(question.help_text || "")}</textarea>
          ${optionsField}
          ${validationFields}
        </div>
      </article>
    `
  }

  optionsFieldMarkup(question, index) {
    if (!["radio", "checkbox", "select"].includes(question.kind)) return ""
    const optionsValue = (question.options || this.defaultOptions()).join("\n")
    return `
      <label class="spec-question-label">Options (one per line)</label>
      <textarea class="spec-question-input" rows="3" data-field="options" data-index="${index}" data-action="input->spec-checklist-editor#handleFieldChange">${this.escapeHtml(optionsValue)}</textarea>
    `
  }

  validationFieldsMarkup(question, index) {
    const isNumber = question.kind === "number"
    const isText = question.kind === "text" || question.kind === "textarea"
    const min = question.validation?.min ?? ""
    const max = question.validation?.max ?? ""
    const step = question.validation?.step ?? ""
    const pattern = question.validation?.pattern ?? ""

    const numberFields = `
      <div class="spec-question-row">
        <div>
          <label class="spec-question-label">Min</label>
          <input type="number" class="spec-question-input" value="${min}" ${isNumber ? "" : "disabled"} data-field="validation.min" data-index="${index}" data-action="input->spec-checklist-editor#handleFieldChange">
        </div>
        <div>
          <label class="spec-question-label">Max</label>
          <input type="number" class="spec-question-input" value="${max}" ${isNumber ? "" : "disabled"} data-field="validation.max" data-index="${index}" data-action="input->spec-checklist-editor#handleFieldChange">
        </div>
        <div>
          <label class="spec-question-label">Step</label>
          <input type="number" class="spec-question-input" value="${step}" ${isNumber ? "" : "disabled"} data-field="validation.step" data-index="${index}" data-action="input->spec-checklist-editor#handleFieldChange">
        </div>
      </div>
    `

    const patternField = `
      <label class="spec-question-label">Pattern (regex)</label>
      <input type="text" class="spec-question-input" value="${this.escapeHtml(pattern)}" ${isText ? "" : "disabled"} data-field="validation.pattern" data-index="${index}" data-action="input->spec-checklist-editor#handleFieldChange">
    `

    return `${numberFields}${patternField}`
  }

  prepareQuestionForSave(question, index) {
    const cloned = this.deepClone(question)
    cloned.id = cloned.id || this.generateQuestionId(cloned.prompt || "question", index)
    cloned.prompt = (cloned.prompt || "").trim()
    cloned.kind = cloned.kind || "radio"
    cloned.required = !!cloned.required

    if (["radio", "checkbox", "select"].includes(cloned.kind)) {
      cloned.options = (cloned.options && cloned.options.length ? cloned.options : this.defaultOptions())
    } else {
      delete cloned.options
    }

    if (cloned.kind === "number") {
      cloned.validation = this.pickPresent(cloned.validation, ["min", "max", "step"])
    } else if (cloned.kind === "text" || cloned.kind === "textarea") {
      const pattern = cloned.validation?.pattern
      cloned.validation = pattern ? { pattern } : undefined
    } else {
      delete cloned.validation
    }

    if (cloned.validation && Object.keys(cloned.validation).length === 0) {
      delete cloned.validation
    }

    return cloned
  }

  duplicateQuestion(event) {
    const index = Number.parseInt(event.currentTarget.dataset.index, 10)
    if (Number.isNaN(index) || !this.questions[index]) return
    const copy = this.deepClone(this.questions[index])
    copy.id = null
    this.questions.splice(index + 1, 0, copy)
    this.renderQuestions()
    this.updateQuestionCount()
    this.markDirty("Question duplicated.")
  }

  markDirty(message = "Unsaved changes.") {
    this.isDirty = true
    this.saveButtonTarget.disabled = false
    this.statusTarget.textContent = message
  }

  markSaved(message) {
    this.isDirty = false
    this.saveButtonTarget.disabled = true
    this.statusTarget.textContent = message
  }

  updateQuestionCount() {
    if (!this.hasQuestionCountTarget) return
    const count = this.questions.length
    this.questionCountTarget.textContent = `${count} ${count === 1 ? "question" : "questions"}`
  }

  normalizeQuestions(questions) {
    if (!Array.isArray(questions)) return []
    return questions.map((question, index) => this.normalizeQuestion(question, index))
  }

  normalizeQuestion(question, index) {
    const normalized = this.deepClone(question || {})
    normalized.prompt = (normalized.prompt || "Untitled question").toString()
    normalized.kind = (normalized.kind || "radio").toString()
    normalized.required = !!normalized.required
    normalized.placeholder = normalized.placeholder || ""
    normalized.help_text = normalized.help_text || ""
    normalized.default_value = normalized.default_value || ""
    normalized.options = normalized.options || (["radio", "checkbox", "select"].includes(normalized.kind) ? this.defaultOptions() : undefined)
    normalized.validation = normalized.validation || {}
    normalized.id = normalized.id || this.generateQuestionId(normalized.prompt, index)
    return normalized
  }

  blankQuestion(index) {
    return {
      id: null,
      prompt: `New checklist question ${index + 1}`,
      kind: "radio",
      required: false,
      options: this.defaultOptions(),
      placeholder: "",
      help_text: "",
      default_value: "",
      validation: {}
    }
  }

  pickPresent(source, keys) {
    if (!source) return undefined
    const bucket = {}
    keys.forEach((key) => {
      if (source[key] !== undefined && source[key] !== "") {
        bucket[key] = source[key]
      }
    })
    return Object.keys(bucket).length ? bucket : undefined
  }

  defaultOptions() {
    return ["Yes", "No", "N/A"]
  }

  kindChoices() {
    return [
      { value: "radio", label: "Radio (Yes / No / N/A)" },
      { value: "checkbox", label: "Checkboxes" },
      { value: "select", label: "Dropdown / Select" },
      { value: "text", label: "Short Text" },
      { value: "textarea", label: "Long Text" },
      { value: "number", label: "Number" },
      { value: "date", label: "Date Picker" }
    ]
  }

  deepClone(value) {
    return JSON.parse(JSON.stringify(value))
  }

  escapeHtml(value) {
    const div = document.createElement("div")
    div.textContent = value ?? ""
    return div.innerHTML
  }

  generateQuestionId(prompt, index) {
    const slug = prompt.toString().toLowerCase().replace(/[^a-z0-9\s]/g, "").trim().replace(/\s+/g, "_") || "question"
    return `${slug}_${index + 1}`
  }

  castValue(value) {
    if (value === "") return ""
    const num = Number(value)
    return Number.isNaN(num) ? value : num
  }
}
