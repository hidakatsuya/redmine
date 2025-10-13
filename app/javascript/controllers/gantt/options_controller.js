import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "relations", "progress"]

  static values = {
    unavailableColumns: Array
  }

  connect() {
    this.$ = window.jQuery
    this.chartElement = document.querySelector('.gantt-table[data-controller*="gantt--chart"]')
    this.dispatchInitialStates()
    this.disableUnavailableColumns()
  }

  toggleDisplay(event) {
    this.dispatchFromChart("toggle-display", {
      detail: { enabled: event.currentTarget.checked },
    })
  }

  toggleRelations(event) {
    this.dispatchFromChart("toggle-relations", {
      detail: { enabled: event.currentTarget.checked },
    })
  }

  toggleProgress(event) {
    this.dispatchFromChart("toggle-progress", {
      detail: { enabled: event.currentTarget.checked },
    })
  }

  dispatchInitialStates() {
    if (this.hasDisplayTarget) {
      this.dispatchFromChart("toggle-display", {
        detail: { enabled: this.displayTarget.checked },
      })
    }
    if (this.hasRelationsTarget) {
      this.dispatchFromChart("toggle-relations", {
        detail: { enabled: this.relationsTarget.checked },
      })
    }
    if (this.hasProgressTarget) {
      this.dispatchFromChart("toggle-progress", {
        detail: { enabled: this.progressTarget.checked },
      })
    }
  }

  dispatchFromChart(eventName, options = {}) {
    if (!this.chartElement) return

    const detail = options.detail || {}
    const event = new CustomEvent(`gantt--options:${eventName}`, {
      bubbles: true,
      cancelable: true,
      detail
    })
    this.chartElement.dispatchEvent(event)
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
