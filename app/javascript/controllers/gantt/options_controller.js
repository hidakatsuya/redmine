import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "relations", "progress"]

  static values = {
    unavailableColumns: Array
  }

  initialize() {
    this.$ = window.jQuery
  }

  connect() {
    this.#dispatchInitialStates()
    this.#disableUnavailableColumns()
    this.#observeSelectedColumns()
    this.#dispatchSelectedColumns()
  }

  disconnect() {
    this.columnsObserver?.disconnect()
  }

  toggleDisplay(event) {
    this.dispatch("toggle-display", {
      detail: { enabled: event.currentTarget.checked }
    })
  }

  toggleRelations(event) {
    this.dispatch("toggle-relations", {
      detail: { enabled: event.currentTarget.checked }
    })
  }

  toggleProgress(event) {
    this.dispatch("toggle-progress", {
      detail: { enabled: event.currentTarget.checked }
    })
  }

  #dispatchInitialStates() {
    if (this.hasDisplayTarget) {
      this.dispatch("toggle-display", {
        detail: { enabled: this.displayTarget.checked }
      })
    }
    if (this.hasRelationsTarget) {
      this.dispatch("toggle-relations", {
        detail: { enabled: this.relationsTarget.checked }
      })
    }
    if (this.hasProgressTarget) {
      this.dispatch("toggle-progress", {
        detail: { enabled: this.progressTarget.checked }
      })
    }
  }

  #observeSelectedColumns() {
    const selectedColumns = this.#selectedColumnsElement()
    if (!selectedColumns) return

    this.columnsObserver = new MutationObserver(() => this.#dispatchSelectedColumns())
    this.columnsObserver.observe(selectedColumns, { childList: true })
    selectedColumns.addEventListener("change", () => this.#dispatchSelectedColumns())
  }

  #dispatchSelectedColumns() {
    const selectedColumns = this.#selectedColumnsElement()
    if (!selectedColumns) return

    this.dispatch("selected-columns-changed", {
      detail: {
        columns: Array.from(selectedColumns.options).filter((option) => !option.disabled).map((option) => option.value)
      }
    })
  }

  #disableUnavailableColumns() {
    if (!Array.isArray(this.unavailableColumnsValue)) {
      return
    }
    this.unavailableColumnsValue.forEach((column) => {
      this.$("#available_c, #selected_c").children(`[value='${column}']`).prop("disabled", true)
    })
  }

  #selectedColumnsElement() {
    return this.element.querySelector("#selected_c")
  }
}
