import { Controller } from "@hotwired/stimulus"

// PoC: keep a separate header outside the chart's overflow containers.
export default class extends Controller {
  static targets = ["timeline", "timelineCanvas", "timelineHeader", "column", "columnHeader"]

  #overlay = null
  #background = null
  #columns = []
  #timelineCopy = null
  #canvasCopy = null
  #content = null
  #frame = null
  #wheelListener = null

  connect() {
    this.#content = this.element.closest("#content")
    this.#createOverlay()
    // The body-level copy is outside this controller's scope.
    this.#wheelListener = this.#handleWheel.bind(this)
    this.#timelineCopy.addEventListener("wheel", this.#wheelListener, { passive: false })
    this.scheduleUpdate()
  }

  #createOverlay() {
    this.#background = document.createElement("div")
    this.#background.className = "gantt-sticky-header-background"
    this.#background.hidden = true
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
    document.body.append(this.#background, this.#overlay)
    this.#columns.forEach(({ source, copy }) => {
      window.jQuery(copy).resizable({
        handles: "e",
        minWidth: Number(source.getAttribute("data-gantt--column-min-width-value")),
        zIndex: 30,
        resize: (_event, ui) => {
          this.dispatch("resize-column", { target: source, detail: { width: ui.size.width } })
          copy.style.removeProperty("width")
        }
      })
    })
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
    if (this.#frame) cancelAnimationFrame(this.#frame)
    this.#columns.forEach(({ copy }) => window.jQuery(copy).resizable("destroy"))
    this.#overlay?.remove()
    this.#background?.remove()
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

  #shouldShowFixedHeader(chart, header, fixedTop, visibleWidth) {
    return header.top < fixedTop && chart.bottom > fixedTop && visibleWidth > 0
  }

  #update() {
    if (typeof window.isMobile === "function" && window.isMobile()) {
      this.#overlay.hidden = true
      this.#background.hidden = true
      return
    }

    const chart = this.element.getBoundingClientRect()
    const header = this.timelineHeaderTarget.getBoundingClientRect()
    const content = this.#content.getBoundingClientRect()
    const canvas = this.timelineCanvasTarget.getBoundingClientRect()
    const overlayStyle = getComputedStyle(this.#overlay)
    const gap = parseFloat(overlayStyle.getPropertyValue("--gantt-sticky-gap"))
    const left = Math.max(0, chart.left, content.left)
    const chartRight = Math.min(document.documentElement.clientWidth, chart.right, content.right)
    const right = Math.min(chartRight, canvas.right)
    if (!this.#shouldShowFixedHeader(chart, header, gap, right - left)) {
      this.#overlay.hidden = true
      this.#background.hidden = true
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
    this.#overlay.style.top = `${Math.min(0, chart.bottom - header.height - gap)}px`
    this.#overlay.style.width = `${right - left}px`
    this.#overlay.style.height = `${header.height + gap}px`
    this.#background.hidden = false
    this.#background.style.left = this.#overlay.style.left
    this.#background.style.top = this.#overlay.style.top
    this.#background.style.width = `${chartRight - left}px`
    this.#background.style.height = this.#overlay.style.height

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
