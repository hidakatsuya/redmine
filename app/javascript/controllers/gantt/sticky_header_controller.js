import { Controller } from "@hotwired/stimulus"

// PoC: keep a separate header outside the chart's overflow containers.
export default class extends Controller {
  static targets = ["timeline", "timelineCanvas", "timelineHeader", "column", "columnHeader", "start"]

  #overlay = null
  #columns = []
  #timelineCopy = null
  #canvasCopy = null
  #content = null
  #frame = null
  #wheelListener = null
  #visibilityObserver = null
  #headerPassed = false
  #chartVisible = false
  #top = 0

  connect() {
    this.#content = this.element.closest("#content")
    this.#createOverlay()
    // The body-level copy is outside this controller's scope.
    this.#wheelListener = this.#handleWheel.bind(this)
    this.#timelineCopy.addEventListener("wheel", this.#wheelListener, { passive: false })
    this.#observeVisibility()
  }

  handleWindowResize() {
    this.#observeVisibility()
    this.scheduleUpdate()
  }

  #observeVisibility() {
    this.#visibilityObserver?.disconnect()
    this.#top = parseFloat(getComputedStyle(this.#overlay).getPropertyValue("--gantt-sticky-top")) || 0
    this.#headerPassed = false
    this.#chartVisible = false
    this.#visibilityObserver = new IntersectionObserver((entries) => {
      entries.forEach((entry) => {
        if (entry.target === this.startTarget) {
          // Being outside the viewport below the chart must not activate the copy.
          this.#headerPassed = entry.boundingClientRect.bottom <= entry.rootBounds.top
        } else {
          this.#chartVisible = entry.isIntersecting
        }
      })
      this.scheduleUpdate()
    }, { rootMargin: `${-this.#top}px 0px 0px 0px`, threshold: 0 })
    this.#visibilityObserver.observe(this.startTarget)
    this.#visibilityObserver.observe(this.element)
  }

  #createOverlay() {
    this.#overlay = document.createElement("div")
    this.#overlay.className = "gantt-sticky-header"
    this.#overlay.hidden = true
    this.#overlay.style.cssText = this.element.style.cssText

    const headers = this.columnHeaderTargets
    this.#columns = this.columnTargets.map((source, index) => {
      const copy = document.createElement("div")
      copy.className = "gantt-column"
      copy.classList.toggle("gantt-selected-column", source.classList.contains("gantt-selected-column"))
      copy.dataset.ganttColumn = source.dataset.ganttColumn
      const pane = document.createElement("section")
      pane.className = "gantt-pane"
      pane.appendChild(this.#cloneHeader(headers[index]))
      copy.appendChild(pane)
      this.#overlay.appendChild(copy)
      return { source, copy }
    })

    this.#timelineCopy = document.createElement("div")
    this.#timelineCopy.className = "gantt-sticky-header-timeline"
    this.#canvasCopy = document.createElement("div")
    this.#canvasCopy.className = "gantt-timeline-canvas"
    this.#canvasCopy.appendChild(this.#cloneHeader(this.timelineHeaderTarget))
    this.#timelineCopy.appendChild(this.#canvasCopy)
    this.#overlay.appendChild(this.#timelineCopy)
    document.body.appendChild(this.#overlay)
  }

  scheduleUpdate() {
    if (this.#frame) return
    this.#frame = requestAnimationFrame(() => {
      this.#frame = null
      this.#update()
    })
  }

  #handleWheel(event) {
    const delta = event.deltaX || (event.shiftKey ? event.deltaY : 0)
    if (!delta) return
    const previous = this.timelineTarget.scrollLeft
    this.timelineTarget.scrollLeft += delta * (event.deltaMode === 1 ? 16 : event.deltaMode === 2 ? this.timelineTarget.clientWidth : 1)
    if (this.timelineTarget.scrollLeft !== previous) {
      event.preventDefault()
      this.scheduleUpdate()
    }
  }

  disconnect() {
    this.#timelineCopy?.removeEventListener("wheel", this.#wheelListener)
    this.#visibilityObserver?.disconnect()
    if (this.#frame) cancelAnimationFrame(this.#frame)
    this.#overlay?.remove()
    this.#frame = null
  }

  #cloneHeader(source) {
    const header = source.cloneNode(true)
    // The copies contain normal links, but must not duplicate document IDs.
    header.removeAttribute("id")
    header.removeAttribute("data-gantt--sticky-header-target")
    header.querySelectorAll("[id]").forEach((element) => element.removeAttribute("id"))
    return header
  }

  #update() {
    if (!this.#headerPassed || !this.#chartVisible) {
      this.#overlay.hidden = true
      return
    }

    const chart = this.element.getBoundingClientRect()
    const header = this.timelineHeaderTarget.getBoundingClientRect()
    const content = this.#content.getBoundingClientRect()
    const canvas = this.timelineCanvasTarget.getBoundingClientRect()
    const left = Math.max(0, chart.left, content.left)
    const right = Math.min(document.documentElement.clientWidth, chart.right, content.right, canvas.right)
    if (right <= left) {
      this.#overlay.hidden = true
      return
    }

    // Read source geometry before writing styles to the fixed header.
    const columnRects = this.#columns.map(({ source }) => source.getBoundingClientRect())
    const timeline = this.timelineTarget.getBoundingClientRect()
    const timelineWidth = this.timelineTarget.clientWidth
    const canvasWidth = canvas.width
    const scrollLeft = this.timelineTarget.scrollLeft
    const style = getComputedStyle(this.element)
    this.#overlay.hidden = false
    this.#overlay.style.fontSize = style.fontSize
    this.#overlay.style.fontFamily = style.fontFamily
    this.#overlay.style.setProperty("--gantt-headers-height", `${header.height}px`)
    this.#overlay.style.left = `${left}px`
    this.#overlay.style.top = `${Math.min(this.#top, chart.bottom - header.height)}px`
    this.#overlay.style.width = `${right - left}px`
    this.#overlay.style.height = `${header.height}px`

    this.#columns.forEach(({ copy }, index) => {
      const rect = columnRects[index]
      copy.hidden = rect.width === 0
      copy.style.left = `${rect.left - left}px`
      copy.style.setProperty("--gantt-column-width", `${rect.width}px`)
    })
    this.#timelineCopy.style.left = `${timeline.left - left}px`
    this.#timelineCopy.style.width = `${timelineWidth}px`
    this.#canvasCopy.style.width = `${canvasWidth}px`
    this.#canvasCopy.style.transform = `translateX(${-scrollLeft}px)`
  }
}
