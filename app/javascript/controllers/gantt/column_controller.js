import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    minWidth: Number,
    widthStorageKey: String,
    defaultWidth: String,
    // Local value
    mobileMode: { type: Boolean, default: false }
  }

  #$element = null
  #initialWidth = null

  initialize() {
    this.$ = window.jQuery
  }

  connect() {
    this.#$element = this.$(this.element)
    this.#restoreWidth()
    this.#setupResizable()
    this.mobileModeValue = this.#isMobile()
  }

  disconnect() {
    this.#$element?.resizable("destroy")
    this.#$element = null
  }

  handleWindowResize(_event) {
    this.mobileModeValue = this.#isMobile()
  }

  mobileModeValueChanged(current, old) {
    if (current == old) return

    if (this.mobileModeValue) {
      this.#$element?.resizable("disable")
    } else {
      this.#$element?.resizable("enable")
    }
  }

  resetWidth(event) {
    const handle = this.element.querySelector(".ui-resizable-e")
    if (!handle || !handle.contains(event.target)) return

    event.preventDefault()
    this.element.style.setProperty("--gantt-column-width", this.defaultWidthValue)
    this.element.style.removeProperty("width")

    try {
      window.localStorage.removeItem(this.widthStorageKeyValue)
    } catch (_error) {
      // Storage may be unavailable; keep the column usable without persistence.
    }
  }

  #setupResizable() {
    const options = {
      handles: "e",
      minWidth: this.minWidthValue,
      disabled: this.#isMobile(),
      zIndex: 30,
      start: (_event, ui) => {
        this.#initialWidth = ui.size.width
      },
      resize: (_event, ui) => {
        this.element.style.setProperty("--gantt-column-width", `${ui.size.width}px`)
        this.element.style.removeProperty("width")
      },
      stop: (_event, ui) => {
        if (!this.mobileModeValue && this.#initialWidth !== ui.size.width) {
          this.#saveWidth(ui.size.width)
        }
        this.#initialWidth = null
      }
    }

    this.#$element.resizable(options)
  }

  #restoreWidth() {
    try {
      const storedWidth = window.localStorage.getItem(this.widthStorageKeyValue)
      if (storedWidth === null || storedWidth.trim() === "") return

      const width = Number(storedWidth)
      if (!Number.isFinite(width) || width < this.minWidthValue) return

      this.element.style.setProperty("--gantt-column-width", `${width}px`)
    } catch (_error) {
      // Storage may be unavailable; resizing still works without persistence.
    }
  }

  #saveWidth(width) {
    if (!Number.isFinite(width) || width < this.minWidthValue) return

    try {
      window.localStorage.setItem(this.widthStorageKeyValue, String(width))
    } catch (_error) {
      // Storage may be unavailable; resizing still works without persistence.
    }
  }

  #isMobile() {
    return !!(typeof window.isMobile === "function" && window.isMobile())
  }
}
