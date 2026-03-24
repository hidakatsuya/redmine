import { Controller } from "@hotwired/stimulus"

const MIN_WIDTH = 240

export default class extends Controller {
  startResize(event) {
    event.preventDefault()

    this.root = this.element.closest(".gantt")
    this.startX = event.clientX
    this.startWidth = this.#subjectWidth()
    this.pointerId = event.pointerId

    this.element.setPointerCapture(this.pointerId)
    this.moveHandler = this.#handleMove.bind(this)
    this.upHandler = this.#handleUp.bind(this)

    this.element.addEventListener("pointermove", this.moveHandler)
    this.element.addEventListener("pointerup", this.upHandler)
    this.element.addEventListener("pointercancel", this.upHandler)
  }

  #handleMove(event) {
    const nextWidth = Math.max(MIN_WIDTH, this.startWidth + (event.clientX - this.startX))
    this.root.style.setProperty("--gantt-subject-width", `${nextWidth}px`)
    this.root.dispatchEvent(new CustomEvent("gantt:sidebar-resized", { bubbles: true }))
  }

  #handleUp() {
    this.element.releasePointerCapture(this.pointerId)
    this.element.removeEventListener("pointermove", this.moveHandler)
    this.element.removeEventListener("pointerup", this.upHandler)
    this.element.removeEventListener("pointercancel", this.upHandler)
  }

  #subjectWidth() {
    const style = getComputedStyle(this.root)
    const subjectWidth = parseFloat(style.getPropertyValue("--gantt-subject-width"))
    const sidebarWidth = parseFloat(style.getPropertyValue("--gantt-sidebar-width"))
    const columnsWidth = parseFloat(style.getPropertyValue("--gantt-columns-width")) || 0

    if (!Number.isNaN(subjectWidth) && subjectWidth > 0) return subjectWidth

    if (this.root.classList.contains("is-showing-columns")) {
      return Math.max(MIN_WIDTH, sidebarWidth - columnsWidth)
    }

    return Math.max(MIN_WIDTH, sidebarWidth)
  }
}
