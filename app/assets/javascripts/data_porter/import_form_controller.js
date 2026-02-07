import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["targetSelect", "sourceSelect", "fileField", "fileInput", "dropzone", "fileName", "modal", "paramsContainer"]
  static values = { sources: Object, params: Object }

  connect() {
    this.filterSources()
    this.renderParams()
  }

  filterSources() {
    if (!this.hasSourceSelectTarget || !this.hasTargetSelectTarget) return
    var allowed = this.sourcesValue[this.targetSelectTarget.value]
    var options = this.sourceSelectTarget.options
    for (var i = 1; i < options.length; i++) {
      options[i].style.display = allowed && allowed.indexOf(options[i].value) === -1 ? "none" : ""
    }
    if (allowed && this.sourceSelectTarget.selectedIndex > 0 && allowed.indexOf(this.sourceSelectTarget.value) === -1) {
      this.sourceSelectTarget.selectedIndex = 0
      this.fileFieldTarget.style.display = ""
    }
    this.renderParams()
  }

  renderParams() {
    if (!this.hasParamsContainerTarget || !this.hasTargetSelectTarget) return
    this.paramsContainerTarget.innerHTML = ""
    var defs = this.paramsValue[this.targetSelectTarget.value] || []
    var self = this
    defs.forEach(function(p) { self.paramsContainerTarget.appendChild(self.buildParamField(p)) })
  }

  buildParamField(p) {
    var div = document.createElement("div")
    div.className = "dp-field"
    div.appendChild(this.buildLabel(p))
    div.appendChild(this.buildInput(p))
    return div
  }

  buildLabel(p) {
    var label = document.createElement("label")
    label.className = "dp-label"
    label.textContent = p.label + (p.required ? " *" : "")
    return label
  }

  buildInput(p) {
    if (p.type === "select" && p.collection) return this.buildSelect(p)
    return this.buildTextField(p)
  }

  buildSelect(p) {
    var select = document.createElement("select")
    select.className = "dp-select"
    select.name = "data_import[config][import_params][" + p.name + "]"
    if (p.required) select.required = true
    var blank = document.createElement("option")
    blank.value = ""
    blank.textContent = "Select..."
    select.appendChild(blank)
    p.collection.forEach(function(opt) {
      var o = document.createElement("option")
      o.textContent = opt[0]
      o.value = opt[1]
      if (p["default"] && String(opt[1]) === String(p["default"])) o.selected = true
      select.appendChild(o)
    })
    return select
  }

  buildTextField(p) {
    var input = document.createElement("input")
    input.className = "dp-input"
    input.type = p.type === "number" ? "number" : (p.type === "hidden" ? "hidden" : "text")
    input.name = "data_import[config][import_params][" + p.name + "]"
    if (p["default"]) input.value = p["default"]
    if (p.required) input.required = true
    return input
  }

  toggleFileField() {
    this.fileFieldTarget.style.display = this.sourceSelectTarget.value === "api" ? "none" : ""
  }

  handleFile() {
    if (this.fileInputTarget.files.length > 0) {
      this.fileNameTarget.textContent = this.fileInputTarget.files[0].name
      this.fileNameTarget.style.display = ""
      this.dropzoneTarget.classList.add("dp-dropzone--has-file")
    }
  }

  dragover(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.add("dp-dropzone--dragover")
  }

  dragleave() {
    this.dropzoneTarget.classList.remove("dp-dropzone--dragover")
  }

  drop(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.remove("dp-dropzone--dragover")
    if (event.dataTransfer.files.length > 0) {
      this.fileInputTarget.files = event.dataTransfer.files
      this.fileInputTarget.dispatchEvent(new Event("change"))
    }
  }

  closeModal(event) {
    if (event.key === "Escape") {
      this.modalTarget.classList.remove("dp-modal--open")
    }
  }

  openModal() {
    this.modalTarget.classList.add("dp-modal--open")
  }

  closeModalClick() {
    this.modalTarget.classList.remove("dp-modal--open")
  }
}
