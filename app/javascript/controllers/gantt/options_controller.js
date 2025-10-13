import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "relations", "progress"]

  static values = {
    unavailableColumns: Array
  }

  connect() {
    this.$ = window.jQuery
    this.dispatchInitialStates()
    this.disableUnavailableColumns()
  }

  toggleDisplay(event) {
    this.dispatchToWindow("toggle-display", { enabled: event.currentTarget.checked })
  }

  toggleRelations(event) {
    this.dispatchToWindow("toggle-relations", { enabled: event.currentTarget.checked })
  }

  toggleProgress(event) {
    this.dispatchToWindow("toggle-progress", { enabled: event.currentTarget.checked })
  }

  dispatchInitialStates() {
    if (this.hasDisplayTarget) {
      this.dispatchToWindow("toggle-display", { enabled: this.displayTarget.checked })
    }
    if (this.hasRelationsTarget) {
      this.dispatchToWindow("toggle-relations", { enabled: this.relationsTarget.checked })
    }
    if (this.hasProgressTarget) {
      this.dispatchToWindow("toggle-progress", { enabled: this.progressTarget.checked })
    }
  }

  dispatchToWindow(eventName, detail = {}) {
    window.dispatchEvent(
      new CustomEvent(`gantt--options:${eventName}`, {
        bubbles: true,
        cancelable: true,
        detail
      })
    )
  }

  disableUnavailableColumns() {
    if (!this.$ || !Array.isArray(this.unavailableColumnsValue)) {
      return
    }
    this.unavailableColumnsValue.forEach((column) => {
      this.$("#available_c, #selected_c").children(`[value='${column}']`).prop("disabled", true)
    })
  }
}
