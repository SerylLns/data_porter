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
    pair.appendChild(this.buildKeyInput())
    pair.appendChild(this.buildValueSelect(columns))
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

  buildKeyInput() {
    const input = document.createElement("input")
    input.type = "text"
    input.name = "mapping_template[mapping_keys][]"
    input.placeholder = "File header"
    input.className = "dp-select"
    input.style.flex = "1"
    return input
  }

  buildValueSelect(columns) {
    const select = document.createElement("select")
    select.name = "mapping_template[mapping_values][]"
    select.className = "dp-select"
    select.style.flex = "1"
    select.dataset.dataPorterTemplateFormTarget = "fieldSelect"

    const blank = document.createElement("option")
    blank.value = ""
    blank.textContent = "Select a field..."
    select.appendChild(blank)

    columns.forEach(([label, name]) => {
      const opt = document.createElement("option")
      opt.value = name
      opt.textContent = label
      select.appendChild(opt)
    })

    return select
  }
}
