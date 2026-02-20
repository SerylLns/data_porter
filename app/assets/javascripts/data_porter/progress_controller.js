import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["bar", "text", "label"]
  static values = { id: Number, url: String, labels: Object }

  connect() {
    this.poll()
  }

  poll() {
    this.timer = setInterval(() => this.fetchStatus(), 1000)
  }

  async fetchStatus() {
    try {
      const response = await fetch(this.urlValue)
      const data = await response.json()
      this.updateLabel(data.status)
      if (data.progress && data.progress.percentage !== undefined) {
        this.barTarget.style.width = data.progress.percentage + "%"
        this.textTarget.textContent = data.progress.percentage + "%"
      }
      if (!["pending", "importing", "parsing", "dry_running", "extracting_headers"].includes(data.status)) {
        clearInterval(this.timer)
        this.barTarget.style.width = "100%"
        this.textTarget.textContent = "100%"
        setTimeout(() => Turbo.visit(window.location.href, { action: "replace" }), 500)
      }
    } catch (e) {}
  }

  updateLabel(status) {
    if (!this.hasLabelTarget) return
    var labels = this.hasLabelsValue ? this.labelsValue : {}
    this.labelTarget.textContent = labels[status] || labels["processing"] || status
  }

  disconnect() {
    if (this.timer) clearInterval(this.timer)
  }
}
