import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["targetSelect", "sourceSelect", "fileField", "fileInput", "dropzone", "fileName", "modal"]
  static values = { sources: Object }

  connect() {
    this.filterSources()
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
