import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["icon"]

  connect() {
    this.applyTheme(this.currentTheme())
  }

  toggle() {
    const next = this.currentTheme() === "dark" ? "light" : "dark"
    localStorage.setItem("dp-theme", next)
    this.applyTheme(next)
  }

  currentTheme() {
    const stored = localStorage.getItem("dp-theme")
    if (stored) return stored
    return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light"
  }

  applyTheme(theme) {
    const root = this.element
    if (theme === "dark") {
      root.classList.add("dp-dark")
    } else {
      root.classList.remove("dp-dark")
    }
    if (this.hasIconTarget) {
      this.iconTarget.textContent = theme === "dark" ? "\u2600" : "\u263D"
    }
  }
}
