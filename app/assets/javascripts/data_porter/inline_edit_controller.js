import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["cell", "errors", "summary"]
  static values = { updateUrl: String }

  edit(event) {
    var cell = event.currentTarget
    if (cell.querySelector(".dp-inline-input")) return

    var value = cell.dataset.value || ""
    cell.dataset.originalValue = value
    cell.textContent = ""

    var input = document.createElement("input")
    input.type = "text"
    input.className = "dp-inline-input"
    input.value = value
    input.dataset.lineNumber = cell.dataset.lineNumber
    input.dataset.column = cell.dataset.column

    input.addEventListener("blur", this.save.bind(this))
    input.addEventListener("keydown", this.handleKey.bind(this))
    cell.appendChild(input)
    input.focus()
    input.select()
  }

  handleKey(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      event.target.blur()
    } else if (event.key === "Escape") {
      event.preventDefault()
      this.cancel(event.target)
    } else if (event.key === "Tab") {
      event.preventDefault()
      var cell = event.target.closest("[data-column]")
      event.target.blur()
      this.moveToNext(cell, event.shiftKey)
    }
  }

  cancel(input) {
    var cell = input.closest("[data-column]")
    var original = cell.dataset.originalValue || ""
    cell.textContent = original
    delete cell.dataset.originalValue
  }

  save(event) {
    var input = event.target
    var cell = input.closest("[data-column]")
    if (!cell) return

    var newValue = input.value
    var original = cell.dataset.originalValue

    if (newValue === original) {
      cell.textContent = original
      delete cell.dataset.originalValue
      return
    }

    cell.textContent = newValue
    cell.classList.add("dp-cell--saving")
    delete cell.dataset.originalValue

    this.patch(cell, {
      line_number: parseInt(cell.dataset.lineNumber, 10),
      column: cell.dataset.column,
      value: newValue
    })
  }

  async patch(cell, body) {
    try {
      var csrfMeta = document.querySelector("meta[name='csrf-token']")
      var headers = {
        "Content-Type": "application/json",
        "Accept": "application/json"
      }
      if (csrfMeta) headers["X-CSRF-Token"] = csrfMeta.content

      var response = await fetch(this.updateUrlValue, {
        method: "PATCH",
        headers: headers,
        body: JSON.stringify(body)
      })

      if (!response.ok) throw new Error("Request failed")

      var data = await response.json()
      this.applyResponse(cell, data)
    } catch (e) {
      cell.classList.remove("dp-cell--saving")
      cell.classList.add("dp-cell--error")
      setTimeout(function() { cell.classList.remove("dp-cell--error") }, 2000)
    }
  }

  applyResponse(cell, data) {
    cell.classList.remove("dp-cell--saving")
    cell.classList.add("dp-cell--success")
    setTimeout(function() { cell.classList.remove("dp-cell--success") }, 600)

    cell.textContent = data.value
    cell.dataset.value = data.value

    var lineNumber = cell.dataset.lineNumber
    this.updateRowStatus(lineNumber, data.status)
    this.updateErrors(lineNumber, data.errors)
    this.updateSummary(data.report)
  }

  updateRowStatus(lineNumber, status) {
    var row = this.element.querySelector("tr[data-line-number='" + lineNumber + "']")
    if (!row) return

    row.className = row.className.replace(/dp-row--\w+/, "dp-row--" + status)
    var statusCell = row.children[1]
    if (statusCell) statusCell.textContent = status
  }

  updateErrors(lineNumber, errors) {
    var errorsCell = this.errorsTargets.find(function(el) {
      return el.dataset.lineNumber === String(lineNumber)
    })
    if (errorsCell) errorsCell.textContent = (errors || []).join(", ")
  }

  updateSummary(report) {
    if (!report) return

    this.summaryTargets.forEach(function(el) {
      var key = el.dataset.countKey
      if (key && report[key] !== undefined) {
        el.textContent = String(report[key])
      }
    })
  }

  moveToNext(currentCell, reverse) {
    var cells = Array.from(this.cellTargets)
    var index = cells.indexOf(currentCell)
    if (index === -1) return

    var next = reverse ? index - 1 : index + 1
    if (next >= 0 && next < cells.length) {
      cells[next].click()
    }
  }
}
