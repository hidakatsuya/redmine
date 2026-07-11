import { Controller } from "@hotwired/stimulus"

const MIN_WIDTH = 48

export default class extends Controller {
  static values = { index: Number }

  startResize(event) {
    event.preventDefault()
    this.startX = event.clientX
    this.startWidth = this.element.getBoundingClientRect().width
    this.pointerId = event.pointerId
    this.handle = event.currentTarget
    this.resizeHandler = this.#resize.bind(this)
    this.stopHandler = this.#stopResize.bind(this)

    this.handle.setPointerCapture(this.pointerId)
    this.handle.addEventListener("pointermove", this.resizeHandler)
    this.handle.addEventListener("pointerup", this.stopHandler)
    this.handle.addEventListener("pointercancel", this.stopHandler)
  }

  #resize(event) {
    this.dispatch("resize", {
      detail: {
        index: this.indexValue,
        width: Math.max(MIN_WIDTH, this.startWidth + event.clientX - this.startX)
      },
      bubbles: true
    })
  }

  #stopResize() {
    this.handle.releasePointerCapture(this.pointerId)
    this.handle.removeEventListener("pointermove", this.resizeHandler)
    this.handle.removeEventListener("pointerup", this.stopHandler)
    this.handle.removeEventListener("pointercancel", this.stopHandler)
  }
}
