import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["header"]
  static classes = ["active"]

  #frame = null
  #resizeObserver = null

  connect() {
    this.#resizeObserver = new ResizeObserver(() => this.scheduleUpdate())
    this.#resizeObserver.observe(this.element)
    this.#resizeObserver.observe(this.element.closest("#content"))
    this.scheduleUpdate()
  }

  disconnect() {
    this.#resizeObserver?.disconnect()
    this.#resizeObserver = null
    if (this.#frame !== null) cancelAnimationFrame(this.#frame)
    this.#frame = null
    document.body.classList.remove(this.activeClass)
  }

  scheduleUpdate() {
    if (this.#frame !== null) return

    this.#frame = requestAnimationFrame(() => {
      this.#frame = null
      this.#update()
    })
  }

  #update() {
    if (typeof window.isMobile === "function" && window.isMobile()) {
      document.body.classList.remove(this.activeClass)
      return
    }

    // The chart stays in normal flow even while its original header is sticky.
    // Use it to decide when ancestor overflow can be temporarily released.
    const chart = this.element.getBoundingClientRect()
    const top = parseFloat(getComputedStyle(this.headerTarget).getPropertyValue("--gantt-sticky-top"))
    const active = chart.width > 0 && chart.top < top && chart.bottom > top
    document.body.classList.toggle(this.activeClass, active)
  }
}
