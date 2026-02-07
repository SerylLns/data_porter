import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["columnSelect", "requiredWarning", "duplicateWarning"]
  static values = { requiredColumns: Array }

  connect() {
    this.validate()
  }

  loadTemplate(event) {
    const option = event.target.selectedOptions[0]
    if (!option || !option.dataset.mapping) return

    const mapping = JSON.parse(option.dataset.mapping)
    this.columnSelectTargets.forEach(select => {
      const header = select.name.match(/\[(.+)\]/)?.[1]
      if (header && mapping[header]) {
        select.value = mapping[header]
      } else {
        select.value = ""
      }
    })
    this.validate()
  }

  onChange() {
    this.validate()
  }

  validate() {
    this.validateRequired()
    this.validateDuplicates()
  }

  validateRequired() {
    if (!this.hasRequiredWarningTarget) return

    const selected = new Set(
      this.columnSelectTargets.map(s => s.value).filter(v => v !== "")
    )

    const missing = this.requiredColumnsValue.filter(c => !selected.has(c.name))

    if (missing.length > 0) {
      const names = missing.map(c => c.label).join(", ")
      this.requiredWarningTarget.textContent = `Required fields not mapped: ${names}`
      this.requiredWarningTarget.style.display = ""
    } else {
      this.requiredWarningTarget.style.display = "none"
    }
  }

  validateDuplicates() {
    const counts = {}
    this.columnSelectTargets.forEach(select => {
      if (select.value === "") return
      counts[select.value] = (counts[select.value] || 0) + 1
    })

    const duplicates = new Set(
      Object.keys(counts).filter(k => counts[k] > 1)
    )

    this.columnSelectTargets.forEach(select => {
      const row = select.closest(".dp-mapping-row")
      if (!row) return

      if (select.value !== "" && duplicates.has(select.value)) {
        row.classList.add("dp-mapping-row--duplicate")
      } else {
        row.classList.remove("dp-mapping-row--duplicate")
      }
    })

    if (this.hasDuplicateWarningTarget) {
      if (duplicates.size > 0) {
        this.duplicateWarningTarget.textContent = `Duplicate mappings detected for: ${[...duplicates].join(", ")}`
        this.duplicateWarningTarget.style.display = ""
      } else {
        this.duplicateWarningTarget.style.display = "none"
      }
    }
  }
}
