import { Controller } from "@hotwired/stimulus"

// PoC: keep a separate header outside the chart's overflow containers.
export default class extends Controller {
  connect() {
    this.timeline = this.element.querySelector(".gantt-timeline")
    this.sourceHeader = this.timeline.querySelector(".gantt-timeline-canvas > header")
    this.overlay = document.createElement("div")
    this.overlay.className = "gantt-sticky-header"
    this.overlay.hidden = true
    this.overlay.style.cssText = this.element.style.cssText

    this.columns = Array.from(this.element.querySelectorAll(":scope > .gantt-column"), (source) => {
      const copy = document.createElement("div")
      copy.className = "gantt-column"
      copy.classList.toggle("gantt-selected-column", source.classList.contains("gantt-selected-column"))
      copy.dataset.ganttColumn = source.dataset.ganttColumn
      const pane = document.createElement("section")
      pane.className = "gantt-pane"
      pane.appendChild(this.cloneHeader(source.querySelector(".gantt-pane > header")))
      copy.appendChild(pane)
      this.overlay.appendChild(copy)
      return { source, copy }
    })

    this.timelineCopy = document.createElement("div")
    this.timelineCopy.className = "gantt-sticky-header-timeline"
    this.canvasCopy = document.createElement("div")
    this.canvasCopy.className = "gantt-timeline-canvas"
    this.canvasCopy.appendChild(this.cloneHeader(this.sourceHeader))
    this.timelineCopy.appendChild(this.canvasCopy)
    this.overlay.appendChild(this.timelineCopy)
    document.body.appendChild(this.overlay)

    this.scheduleUpdate = () => {
      if (this.frame) return
      this.frame = requestAnimationFrame(() => {
        this.frame = null
        this.update()
      })
    }
    this.handleWheel = (event) => {
      const delta = event.deltaX || (event.shiftKey ? event.deltaY : 0)
      if (!delta) return
      const previous = this.timeline.scrollLeft
      this.timeline.scrollLeft += delta * (event.deltaMode === 1 ? 16 : event.deltaMode === 2 ? this.timeline.clientWidth : 1)
      if (this.timeline.scrollLeft !== previous) {
        event.preventDefault()
        this.scheduleUpdate()
      }
    }

    // Capture also picks up horizontal scrolling of #content and the timeline.
    document.addEventListener("scroll", this.scheduleUpdate, true)
    window.addEventListener("resize", this.scheduleUpdate)
    this.timelineCopy.addEventListener("wheel", this.handleWheel, { passive: false })
    this.resizeObserver = new ResizeObserver(this.scheduleUpdate)
    const observedElements = [this.element, this.timeline, this.sourceHeader, ...this.columns.map(({ source }) => source)]
    observedElements.forEach((element) => {
      this.resizeObserver.observe(element)
    })
    this.scheduleUpdate()
  }

  disconnect() {
    document.removeEventListener("scroll", this.scheduleUpdate, true)
    window.removeEventListener("resize", this.scheduleUpdate)
    this.resizeObserver?.disconnect()
    if (this.frame) cancelAnimationFrame(this.frame)
    this.frame = null
    this.overlay?.remove()
  }

  cloneHeader(source) {
    const header = source.cloneNode(true)
    // The copies contain normal links, but must not duplicate document IDs.
    header.removeAttribute("id")
    header.querySelectorAll("[id]").forEach((element) => element.removeAttribute("id"))
    return header
  }

  update() {
    const chart = this.element.getBoundingClientRect()
    const header = this.sourceHeader.getBoundingClientRect()
    const content = this.element.closest("#content").getBoundingClientRect()
    const left = Math.max(0, chart.left, content.left)
    const right = Math.min(document.documentElement.clientWidth, chart.right, content.right)
    const visible = header.top < 0 && chart.bottom > 0 && right > left
    if (!visible) {
      this.overlay.hidden = true
      return
    }

    // Read source geometry before writing styles to the fixed header.
    const columnRects = this.columns.map(({ source }) => source.getBoundingClientRect())
    const timeline = this.timeline.getBoundingClientRect()
    const timelineWidth = this.timeline.clientWidth
    const canvasWidth = this.timeline.firstElementChild.getBoundingClientRect().width
    const scrollLeft = this.timeline.scrollLeft
    const style = getComputedStyle(this.element)
    this.overlay.hidden = false
    this.overlay.style.fontSize = style.fontSize
    this.overlay.style.fontFamily = style.fontFamily
    this.overlay.style.setProperty("--gantt-headers-height", `${header.height}px`)
    this.overlay.style.left = `${left}px`
    this.overlay.style.top = `${Math.min(0, chart.bottom - header.height)}px`
    this.overlay.style.width = `${right - left}px`
    this.overlay.style.height = `${header.height}px`

    this.columns.forEach(({ copy }, index) => {
      const rect = columnRects[index]
      copy.hidden = rect.width === 0
      copy.style.left = `${rect.left - left}px`
      copy.style.setProperty("--gantt-column-width", `${rect.width}px`)
    })
    this.timelineCopy.style.left = `${timeline.left - left}px`
    this.timelineCopy.style.width = `${timelineWidth}px`
    this.canvasCopy.style.width = `${canvasWidth}px`
    this.canvasCopy.style.transform = `translateX(${-scrollLeft}px)`
  }
}
