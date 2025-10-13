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
    this.dispatch("toggle-display", {
      bubbles: true,
      cancelable: true,
      detail: { enabled: event.currentTarget.checked }
    })
  }

  toggleRelations(event) {
    this.dispatch("toggle-relations", {
      bubbles: true,
      cancelable: true,
      detail: { enabled: event.currentTarget.checked }
    })
  }

  toggleProgress(event) {
    this.dispatch("toggle-progress", {
      bubbles: true,
      cancelable: true,
      detail: { enabled: event.currentTarget.checked }
    })
  }

  dispatchInitialStates() {
    if (this.hasDisplayTarget) {
      this.dispatch("toggle-display", {
        bubbles: true,
        cancelable: true,
        detail: { enabled: this.displayTarget.checked }
      })
    }
    if (this.hasRelationsTarget) {
      this.dispatch("toggle-relations", {
        bubbles: true,
        cancelable: true,
        detail: { enabled: this.relationsTarget.checked }
      })
    }
    if (this.hasProgressTarget) {
      this.dispatch("toggle-progress", {
        bubbles: true,
        cancelable: true,
        detail: { enabled: this.progressTarget.checked }
      })
    }
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
