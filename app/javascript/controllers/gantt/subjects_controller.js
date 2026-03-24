import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.#rows().forEach((row) => {
      if (row.querySelector(".gantt__expander")) {
        row.dataset.expanded = row.dataset.expanded || "true"
      }
    })
    this.#applyVisibility()
  }

  toggleRow(event) {
    const row = event.currentTarget.closest(".gantt__row")
    const button = event.currentTarget
    const expanded = row.dataset.expanded !== "false"

    row.dataset.expanded = expanded ? "false" : "true"
    button.setAttribute("aria-expanded", expanded ? "false" : "true")
    this.#applyVisibility()

    row.dispatchEvent(new CustomEvent("gantt:row-toggled", { bubbles: true }))
  }

  #applyVisibility() {
    const state = new Map()
    const timelineRows = this.#timelineRowsByKey()

    this.#rows().forEach((row) => {
      const rowKey = row.dataset.rowKey
      const parentKey = row.dataset.parentRowKey
      const parentState = parentKey ? state.get(parentKey) : null
      const visible = !parentState || (parentState.visible && parentState.expanded)
      const expanded = row.dataset.expanded !== "false"

      row.classList.toggle("is-hidden", !visible)
      timelineRows.get(rowKey)?.classList.toggle("is-hidden", !visible)
      state.set(rowKey, { visible, expanded })
    })
  }

  #rows() {
    return Array.from(this.element.querySelectorAll(".gantt__row"))
  }

  #timelineRowsByKey() {
    return new Map(
      Array.from(document.querySelectorAll(".gantt__timeline-row")).map((row) => [row.dataset.rowKey, row])
    )
  }
}
