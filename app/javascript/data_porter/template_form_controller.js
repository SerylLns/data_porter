import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["pairsContainer", "fieldSelect"]
  static values = { columns: Object }

  targetChanged(event) {
    const targetKey = event.target.value
    const columns = this.columnsValue[targetKey] || []
    this.fieldSelectTargets.forEach(select => this.updateOptions(select, columns))
  }

  addPair() {
    const container = this.pairsContainerTarget
    const targetKey = this.element.querySelector("[name='mapping_template[target_key]']")?.value
    const columns = targetKey ? (this.columnsValue[targetKey] || []) : []

    const pair = document.createElement("div")
    pair.className = "dp-mapping-pair"
    pair.style.cssText = "display: flex; gap: 0.5rem; margin-bottom: 0.5rem;"
    pair.innerHTML = this.pairHTML(columns)
    container.appendChild(pair)
  }

  updateOptions(select, columns) {
    const current = select.value
    select.innerHTML = '<option value="">Select a field...</option>'
    columns.forEach(([label, name]) => {
      const opt = document.createElement("option")
      opt.value = name
      opt.textContent = label
      if (name === current) opt.selected = true
      select.appendChild(opt)
    })
  }

  pairHTML(columns) {
    const options = columns.map(([label, name]) =>
      `<option value="${name}">${label}</option>`
    ).join("")

    return `<input type="text" name="mapping_template[mapping_keys][]" placeholder="File header" class="dp-select" style="flex: 1;" />` +
      `<select name="mapping_template[mapping_values][]" class="dp-select" style="flex: 1;" data-data-porter--template-form-target="fieldSelect">` +
      `<option value="">Select a field...</option>${options}</select>`
  }
}
