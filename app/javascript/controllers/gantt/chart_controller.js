import { Controller } from "@hotwired/stimulus"

const RELATION_STROKE_WIDTH = 2
const SVG_NS = "http://www.w3.org/2000/svg"

// Coordinates layout changes and draws cross-row SVG lines over the timeline.
export default class extends Controller {
  static targets = [
    "body",
    "doneBar",
    "overlay",
    "row",
    "svgLayer",
    "todayLine",
    "todoBar",
    "viewport"
  ]

  static values = {
    columnWidths: Array,
    issueRelationTypes: Object,
    relations: Array,
    showSelectedColumns: Boolean,
    showRelations: Boolean,
    showProgress: Boolean
  }

  connect() {
    this.resizeObserver = new ResizeObserver(() => this.#scheduleOverlayDraw())
    this.resizeObserver.observe(this.bodyTarget)
    this.#applySelectedColumnsState()
    this.#scheduleOverlayDraw()
  }

  disconnect() {
    this.resizeObserver?.disconnect()
    if (this.animationFrame) cancelAnimationFrame(this.animationFrame)
  }

  showSelectedColumnsValueChanged() {
    this.#applySelectedColumnsState()
    this.#scheduleOverlayDraw()
  }

  showRelationsValueChanged() {
    this.#scheduleOverlayDraw()
  }

  showProgressValueChanged() {
    this.#scheduleOverlayDraw()
  }

  handleOptionsDisplay(event) {
    this.showSelectedColumnsValue = !!event.detail?.enabled
  }

  handleColumnResize(event) {
    const index = Number(event.detail?.index)
    const width = Number(event.detail?.width)
    if (!Number.isInteger(index) || !Number.isFinite(width)) return

    const widths = [...this.columnWidthsValue]
    widths[index] = width
    this.columnWidthsValue = widths
    this.element.style.setProperty("--gantt-selected-columns-template", widths.map((value) => `${value}px`).join(" "))
    this.element.style.setProperty("--gantt-selected-columns-width", `${widths.reduce((sum, value) => sum + value, 0)}px`)
    this.#scheduleOverlayDraw()
  }

  handleOptionsRelations(event) {
    this.showRelationsValue = !!event.detail?.enabled
  }

  handleOptionsProgress(event) {
    this.showProgressValue = !!event.detail?.enabled
  }

  handleLayoutInvalidated() {
    this.#scheduleOverlayDraw()
  }

  handleSidebarResized() {
    this.#scheduleOverlayDraw()
  }

  handleWindowResize() {
    this.#scheduleOverlayDraw()
  }

  handleBeforePrint() {
    if (this.animationFrame) cancelAnimationFrame(this.animationFrame)
    this.animationFrame = null
    const padding = parseFloat(getComputedStyle(this.bodyTarget).paddingBlockStart)
    let height = 0
    this.rowTargets.forEach((row) => {
      if (this.#isHidden(row)) return
      row.style.setProperty("--gantt-print-top", `${padding + height}px`)
      height += row.offsetHeight
    })
    // Flow pagination can move rows independently of the single SVG overlay.
    // Print both on one continuous coordinate plane, as the legacy chart did.
    this.element.classList.add("is-printing")
    this.#drawOverlay()
  }

  handleAfterPrint() {
    this.element.classList.remove("is-printing")
    this.#scheduleOverlayDraw()
  }

  #applySelectedColumnsState() {
    this.element.classList.toggle("is-showing-columns", this.showSelectedColumnsValue)
  }

  #scheduleOverlayDraw() {
    if (this.animationFrame) return

    this.animationFrame = requestAnimationFrame(() => {
      this.animationFrame = null
      this.#drawOverlay()
    })
  }

  #drawOverlay() {
    const width = Math.max(this.overlayTarget.clientWidth, 1)
    const height = Math.max(this.bodyTarget.scrollHeight, 1)
    const svg = document.createElementNS(SVG_NS, "svg")

    svg.setAttribute("width", String(width))
    svg.setAttribute("height", String(height))
    svg.setAttribute("viewBox", `0 0 ${width} ${height}`)
    svg.setAttribute("aria-hidden", "true")
    this.svgLayerTarget.replaceChildren(svg)

    if (this.showProgressValue) this.#drawProgressLine(svg, width)
    if (this.showRelationsValue) this.#drawRelations(svg)
  }

  // Arrows join the source bar end to the target bar start, routing around nearby bars.
  #drawRelations(svg) {
    const bars = this.#elementsByRowKey(this.todoBarTargets)

    this.relationsValue.forEach((relation) => {
      const fromAnchor = bars.get(relation.from_row_key)
      const toAnchor = bars.get(relation.to_row_key)

      if (!fromAnchor || !toAnchor || this.#isHidden(fromAnchor) || this.#isHidden(toAnchor)) return

      const from = this.#pointInOverlay(fromAnchor, "end")
      const to = this.#pointInOverlay(toAnchor, "start")
      const config = this.issueRelationTypesValue[relation.type] || {}
      const margin = config.landscape_margin || 0
      const color = config.color || "#000"
      const viaX = from.x + margin
      const targetViaX = to.x - margin

      this.#drawPath(svg, ["M", from.x, from.y, "L", viaX, from.y], color)
      if (viaX < targetViaX) {
        this.#drawPath(svg, ["M", viaX, from.y, "L", viaX, to.y, "L", to.x, to.y], color)
      } else {
        const midY = to.y + from.height * (from.y > to.y ? 1 : -1)
        this.#drawPath(svg, ["M", viaX, from.y, "L", viaX, midY, "L", targetViaX, midY, "L", targetViaX, to.y, "L", to.x, to.y], color)
      }

      const arrow = document.createElementNS(SVG_NS, "path")
      arrow.setAttribute("d", ["M", to.x, to.y, "l", -8, -4, "l", 0, 8, "z"].join(" "))
      arrow.setAttribute("fill", color)
      arrow.setAttribute("stroke", "none")
      svg.appendChild(arrow)
    })
  }

  // The zigzag progress line connects each row's completion point around the today line.
  #drawProgressLine(svg, width) {
    if (!this.hasTodayLineTarget) return

    const todayX = this.#pointInOverlay(this.todayLineTarget).x
    const color = getComputedStyle(this.todayLineTarget).borderInlineStartColor || "#ff0000"
    const doneBars = this.#elementsByRowKey(this.doneBarTargets)
    const todoBars = this.#elementsByRowKey(this.todoBarTargets)
    const points = [{ left: todayX, top: 0 }]

    this.rowTargets.forEach((row) => {
      if (row.classList.contains("is-hidden") || row.dataset.kind === "project") return

      const state = row.dataset.progressState
      if (!state) return

      const rowRect = row.getBoundingClientRect()
      const overlayRect = this.overlayTarget.getBoundingClientRect()
      const top = rowRect.top - overlayRect.top
      const center = top + rowRect.height / 2

      if (state === "closed") {
        points.push({ left: todayX, top: center })
      } else if (state === "over-end") {
        points.push({ left: width, top: top + 6, edge: "right" })
        points.push({ left: width, top: top + rowRect.height - 6, edge: "right", skip: true })
      } else if (state === "behind-start") {
        points.push({ left: 0, top: top + 6, edge: "left" })
        points.push({ left: 0, top: top + rowRect.height - 6, edge: "left", skip: true })
      } else if (doneBars.has(row.dataset.rowKey)) {
        const rect = doneBars.get(row.dataset.rowKey).getBoundingClientRect()
        points.push({ left: rect.right - overlayRect.left, top: center })
      } else {
        const todoBar = todoBars.get(row.dataset.rowKey)
        const todoLeft = todoBar ? todoBar.getBoundingClientRect().left - overlayRect.left : todayX
        points.push({ left: Math.min(todayX, todoLeft), top: center })
      }
    })

    for (let index = 1; index < points.length; index += 1) {
      const previous = points[index - 1]
      const current = points[index]
      if (current.skip || (previous.edge && previous.edge === current.edge)) continue

      this.#drawPath(svg, ["M", previous.left, previous.top, "L", current.left, current.top], color)
    }
  }

  #elementsByRowKey(elements) {
    return new Map(elements.map((element) => [element.dataset.rowKey, element]))
  }

  #isHidden(element) {
    return element.closest(".gantt__row")?.classList.contains("is-hidden")
  }

  #pointInOverlay(element, side) {
    const rect = element.getBoundingClientRect()
    const overlayRect = this.overlayTarget.getBoundingClientRect()
    const style = getComputedStyle(element)
    // Legacy relation anchors used the bar's content dimensions, excluding borders.
    const width = rect.width - parseFloat(style.borderLeftWidth) - parseFloat(style.borderRightWidth)
    const height = rect.height - parseFloat(style.borderTopWidth) - parseFloat(style.borderBottomWidth)
    return {
      x: rect.left - overlayRect.left + (side === "end" ? width : 0),
      y: rect.top - overlayRect.top + (side ? height / 2 : 0),
      height
    }
  }

  #drawPath(svg, parts, color) {
    const path = document.createElementNS(SVG_NS, "path")
    path.setAttribute("d", parts.join(" "))
    path.setAttribute("stroke", color)
    path.setAttribute("stroke-width", String(RELATION_STROKE_WIDTH))
    path.setAttribute("fill", "none")
    svg.appendChild(path)
  }
}
