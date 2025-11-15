import { Controller } from "@hotwired/stimulus"
import { UiStates } from "lib/ui_states"

export default class extends Controller {
  static values = {
    minWidth: Number,
    column: String,
    // Local value
    mobileMode: { type: Boolean, default: false }
  }

  #widthState
  #$element = null

  initialize() {
    this.$ = window.jQuery
    this.#widthState = UiStates.ganttColumnWidth(this.columnValue)
  }

  connect() {
    this.#$element = this.$(this.element)

    this.#setupResizable()
    this.#initWidth()
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
    const options = {
      handles: "e",
      minWidth: this.minWidthValue,
      zIndex: 30,
      alsoResize: this.#resizeTargets.join(","),
      create: () => {
        this.#$element.find(".ui-resizable-e").css("cursor", "ew-resize")
      }
    }

    this.#$element
      .resizable(options)
      .on("resize", (event) => {
        event.stopPropagation()
        this.#dispatchResizeColumn()
      })
      .on("resizestop", () => {
        this.#saveWidthState()
      })
  }

  get #resizeTargets() {
    return [
      `.gantt_${this.columnValue}_container`,
      `.gantt_${this.columnValue}_container > .gantt_hdr`
    ]
  }

  #initWidth() {
    const width = this.#widthState.value
    if (width) {
      this.#width = width
    }
  }

  set #width(width) {
    this.$(this.#$element).width(width)
    this.#resizeTargets.forEach(target => this.$(target).width(width))
  }

  #dispatchResizeColumn() {
    if (!this.#$element) return

    this.dispatch(`resize-column-${this.columnValue}`, { detail: { width: this.#$element.width() } })
  }

  #isMobile() {
    return !!(typeof window.isMobile === "function" && window.isMobile())
  }

  #saveWidthState() {
    const width = this.#$element.width()
    this.#widthState.value = width
  }
}
