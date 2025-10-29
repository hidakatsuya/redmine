import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    minWidth: Number,
    column: String,
    // Local value
    mobileMode: { type: Boolean, default: false }
  }

  #$element = null

  initialize() {
    this.$ = window.jQuery
  }

  connect() {
    this.#$element = this.$(this.element)

    this.#setupResizable()
    this.#initColumnWidthFromLocalStorage()
    this.#dispatchResizeColumn()
  }

  disconnect() {
    this.#$element?.resizable("destroy")
    this.#$element = null
  }

  handleWindowResize(_event) {
    this.mobileModeValue = this.#isMobile()

    this.#dispatchResizeColumn()
  }

  mobileModeValueChanged(current, old) {
    if (current == old) return

    if (this.mobileModeValue) {
      this.#$element?.resizable("disable")
    } else {
      this.#$element?.resizable("enable")
    }
  }

  #setupResizable() {
    const alsoResize = [
      `.gantt_${this.columnValue}_container`,
      `.gantt_${this.columnValue}_container > .gantt_hdr`
    ]
    const options = {
      handles: "e",
      minWidth: this.minWidthValue,
      zIndex: 30,
      alsoResize: alsoResize.join(","),
      create: () => {
        this.$(".ui-resizable-e").css("cursor", "ew-resize")
      }
    }

    this.#$element
      .resizable(options)
      .on("resize", this.#onResize.bind(this))
  }

  #onResize(event) {
    event.stopPropagation()
    this.#saveColumnWidth()
    this.#dispatchResizeColumn()
  }

  #saveColumnWidth() {
    const width = this.#$element.width()
    localStorage.setItem(this.#columnWidthStorageKey, width)
  }

  #initColumnWidthFromLocalStorage() {
    if (this.#isMobile()) return

    const width = localStorage.getItem(this.#columnWidthStorageKey)
    if (width) {
      console.log(width)
      this.#$element.width(width)
    }
  }

  get #columnWidthStorageKey() {
    return `redmine-state-gantt-column-${this.columnValue}-width`
  }

  #dispatchResizeColumn() {
    if (!this.#$element) return

    console.log("aa", this.#$element.width())
    this.dispatch(`resize-column-${this.columnValue}`, { detail: { width: this.#$element.width() } })
  }

  #isMobile() {
    return !!(typeof window.isMobile === "function" && window.isMobile())
  }
}
