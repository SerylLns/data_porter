import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["columnSelect"]

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
  }
}
