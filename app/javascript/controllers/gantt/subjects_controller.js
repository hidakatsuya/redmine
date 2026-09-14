import { Controller } from "@hotwired/stimulus"

// Folds the subject tree using display row keys, including version and project parents.
export default class extends Controller {
  static targets = ["row"]

  connect() {
    this.rowTargets.forEach((row) => {
      row.dataset.expanded ||= "true"
    })
    this.#applyVisibility()
  }

  toggleRow(event) {
    const row = event.currentTarget.closest(".gantt__row")
    const expanded = row.dataset.expanded !== "false"

    row.dataset.expanded = expanded ? "false" : "true"
    event.currentTarget.setAttribute("aria-expanded", expanded ? "false" : "true")
    this.#applyVisibility()
    this.dispatch("row-toggled", { prefix: "gantt", bubbles: true })
  }

  // Dataset emits parents before descendants, so visibility can flow down the tree.
  #applyVisibility() {
    const state = new Map()

    this.rowTargets.forEach((row) => {
      const parentState = row.dataset.parentRowKey ? state.get(row.dataset.parentRowKey) : null
      const visible = !parentState || (parentState.visible && parentState.expanded)
      const expanded = row.dataset.expanded !== "false"

      row.classList.toggle("is-hidden", !visible)
      state.set(row.dataset.rowKey, { visible, expanded })
    })
  }
}
