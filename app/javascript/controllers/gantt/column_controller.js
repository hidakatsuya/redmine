import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["handle"]
  static values = { minWidth: Number }

  #drag = null

  connect() {
    this.handleWindowResize()
  }

  disconnect() {
    this.#finishResize(true)
  }

  handleWindowResize() {
    const mobile = this.#isMobile()
    if (mobile) this.#finishResize(true)
    this.handleTarget.hidden = mobile
  }

  startResize(event) {
    if (!event.isPrimary || event.button !== 0 || this.#isMobile() || this.#drag) return
    // Only one column can own the document's selection suppression at a time.
    if (document.documentElement.classList.contains("gantt-column-resizing")) return

    event.preventDefault()
    const handle = event.currentTarget
    handle.setPointerCapture(event.pointerId)
    this.#drag = {
      handle,
      pointerId: event.pointerId,
      startX: event.clientX,
      startWidth: this.element.getBoundingClientRect().width,
      initialWidth: this.element.style.getPropertyValue("--gantt-column-width")
    }
    document.documentElement.classList.add("gantt-column-resizing")
  }

  resize(event) {
    if (!this.#drag || event.pointerId !== this.#drag.pointerId) return
    if (this.#isMobile()) {
      this.handleWindowResize()
      return
    }
    this.#applyWidth(this.#drag.startWidth + event.clientX - this.#drag.startX)
  }

  endResize(event) {
    if (!this.#drag || event.pointerId !== this.#drag.pointerId) return
    this.resize(event)
    this.#finishResize(false)
  }

  cancelResize(event) {
    if (event.pointerId === this.#drag?.pointerId) this.#finishResize(true)
  }

  #applyWidth(width) {
    width = Math.max(this.minWidthValue, width)
    this.element.style.setProperty("--gantt-column-width", `${width}px`)
    this.dispatch("resize", { detail: { width } })
  }

  #finishResize(cancelled) {
    const drag = this.#drag
    if (!drag) return
    this.#drag = null

    if (cancelled) {
      if (drag.initialWidth) {
        this.element.style.setProperty("--gantt-column-width", drag.initialWidth)
      } else {
        this.element.style.removeProperty("--gantt-column-width")
      }
      this.dispatch("resize", { detail: { width: drag.startWidth } })
    }
    document.documentElement.classList.remove("gantt-column-resizing")
    if (drag.handle.hasPointerCapture(drag.pointerId)) {
      drag.handle.releasePointerCapture(drag.pointerId)
    }

    const width = this.element.getBoundingClientRect().width
    if (!cancelled && width !== drag.startWidth) {
      this.dispatch("resize-end", { detail: { width } })
    }
  }

  #isMobile() {
    return !!(typeof window.isMobile === "function" && window.isMobile())
  }
}
