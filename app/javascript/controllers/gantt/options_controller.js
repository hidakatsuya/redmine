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
      detail: { enabled: event.currentTarget.checked },
      bubbles: true
    })
  }

  toggleRelations(event) {
    this.dispatch("toggle-relations", {
      detail: { enabled: event.currentTarget.checked },
      bubbles: true
    })
  }

  toggleProgress(event) {
    this.dispatch("toggle-progress", {
      detail: { enabled: event.currentTarget.checked },
      bubbles: true
    })
  }

  dispatchInitialStates() {
    if (this.hasDisplayTarget) {
      this.dispatch("toggle-display", {
        detail: { enabled: this.displayTarget.checked },
        bubbles: true
      })
    }
    if (this.hasRelationsTarget) {
      this.dispatch("toggle-relations", {
        detail: { enabled: this.relationsTarget.checked },
        bubbles: true
      })
    }
    if (this.hasProgressTarget) {
      this.dispatch("toggle-progress", {
        detail: { enabled: this.progressTarget.checked },
        bubbles: true
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
