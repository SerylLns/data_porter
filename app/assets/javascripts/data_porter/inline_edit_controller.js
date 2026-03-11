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
    cell.classList.add("dp-cell--editing")

    var isLong = value.length > 50
    var input = document.createElement(isLong ? "textarea" : "input")
    if (!isLong) input.type = "text"
    input.className = "dp-inline-input"
    input.value = value
    input.dataset.lineNumber = cell.dataset.lineNumber
    input.dataset.column = cell.dataset.column

    var self = this
    input._blurHandler = function(e) { self.save(e) }
    input._keyHandler = function(e) { self.handleKey(e, isLong) }
    input.addEventListener("blur", input._blurHandler)
    input.addEventListener("keydown", input._keyHandler)
    cell.appendChild(input)
    this.autoSize(input)
    if (isLong) this.autoHeight(input)
    input.addEventListener("input", function() {
      self.autoSize(input)
      if (isLong) self.autoHeight(input)
    })
    input.focus()
    input.select()
  }

  handleKey(event, isTextarea) {
    if (event.key === "Enter" && (!isTextarea || event.ctrlKey || event.metaKey)) {
      event.preventDefault()
      event.target.blur()
    } else if (event.key === "Escape") {
      event.preventDefault()
      this.cancel(event.target)
    } else if (event.key === "Tab") {
      event.preventDefault()
      var cell = event.target.closest("td")
      event.target.blur()
      this.moveToNext(cell, event.shiftKey)
    }
  }

  cancel(input) {
    var cell = input.closest("td")
    input.removeEventListener("blur", input._blurHandler)
    input.removeEventListener("keydown", input._keyHandler)
    cell.classList.remove("dp-cell--editing")
    var original = cell.dataset.originalValue || ""
    cell.textContent = original
    delete cell.dataset.originalValue
    cell.blur()
  }

  save(event) {
    var input = event.target
    var cell = input.closest("td")
    if (!cell) return

    input.removeEventListener("blur", input._blurHandler)
    input.removeEventListener("keydown", input._keyHandler)

    var newValue = input.value
    var original = cell.dataset.originalValue

    cell.classList.remove("dp-cell--editing")

    if (newValue === original) {
      cell.textContent = original
      delete cell.dataset.originalValue
      cell.blur()
      return
    }

    cell.textContent = newValue
    cell.classList.add("dp-cell--saving")
    delete cell.dataset.originalValue
    cell.blur()

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
    setTimeout(function() { cell.classList.remove("dp-cell--success") }, 800)

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

  autoSize(input) {
    var span = document.createElement("span")
    span.style.cssText = "position:absolute;visibility:hidden;white-space:pre;"
    var computed = window.getComputedStyle(input)
    span.style.font = computed.font
    span.style.padding = computed.padding
    span.style.border = computed.border
    span.textContent = input.value || " "
    document.body.appendChild(span)
    var cell = input.closest("td")
    var minWidth = cell ? cell.offsetWidth : 100
    var tableRight = this.element.getBoundingClientRect().right
    var cellLeft = cell.getBoundingClientRect().left
    var maxWidth = tableRight - cellLeft - 4
    var width = Math.min(Math.max(minWidth, span.offsetWidth + 4), maxWidth)
    input.style.width = width + "px"
    document.body.removeChild(span)
  }

  autoHeight(textarea) {
    textarea.style.height = "auto"
    textarea.style.height = textarea.scrollHeight + "px"
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
