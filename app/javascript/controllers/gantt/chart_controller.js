import { Controller } from "@hotwired/stimulus"

const RELATION_STROKE_WIDTH = 2
const SVG_NS = "http://www.w3.org/2000/svg"

export default class extends Controller {
  static targets = ["viewport", "timelineHeader", "timelineRows", "overlay", "todayLine", "sidebar"]

  static values = {
    activeColumns: Array,
    issueRelationTypes: Object,
    relations: Array,
    showSelectedColumns: Boolean,
    showRelations: Boolean,
    showProgress: Boolean
  }

  connect() {
    this.#applySelectedColumnsState()
    this.#applyActiveColumnsState()
    this.#drawOverlay()
  }

  activeColumnsValueChanged() {
    this.#applyActiveColumnsState()
    this.#drawOverlay()
  }

  showSelectedColumnsValueChanged() {
    this.#applySelectedColumnsState()
  }

  showRelationsValueChanged() {
    this.#drawOverlay()
  }

  showProgressValueChanged() {
    this.#drawOverlay()
  }

  handleOptionsDisplay(event) {
    this.showSelectedColumnsValue = !!event.detail?.enabled
  }

  handleSelectedColumnsChanged(event) {
    this.activeColumnsValue = event.detail?.columns || []
  }

  handleOptionsRelations(event) {
    this.showRelationsValue = !!event.detail?.enabled
    this.#drawOverlay()
  }

  handleOptionsProgress(event) {
    this.showProgressValue = !!event.detail?.enabled
    this.#drawOverlay()
  }

  handleLayoutInvalidated() {
    this.#drawOverlay()
  }

  handleSidebarResized() {
    this.#drawOverlay()
  }

  handleWindowResize() {
    this.#drawOverlay()
  }

  handleScroll() {
    this.#drawOverlay()
  }

  hoverRow(event) {
    this.#setHoveredRow(event.currentTarget.dataset.rowKey, true)
  }

  unhoverRow(event) {
    this.#setHoveredRow(event.currentTarget.dataset.rowKey, false)
  }

  #applySelectedColumnsState() {
    this.element.classList.toggle("is-showing-columns", this.showSelectedColumnsValue)
    this.#syncColumnMetrics()
  }

  #applyActiveColumnsState() {
    const activeColumns = new Set(this.activeColumnsValue)

    this.element.querySelectorAll("[data-column-name]").forEach((element) => {
      element.classList.toggle("is-active-column", activeColumns.has(element.dataset.columnName))
    })

    this.#syncColumnMetrics()
  }

  #syncColumnMetrics() {
    const activeCount = this.showSelectedColumnsValue ? this.activeColumnsValue.length : 0
    this.element.style.setProperty("--gantt-active-columns-count", String(activeCount))
    this.element.style.setProperty("--gantt-columns-width", `${activeCount * 96}px`)
  }

  #drawOverlay() {
    const overlay = this.overlayTarget
    const width = Math.max(this.timelineRowsTarget.scrollWidth, 1)
    const height = Math.max(this.timelineRowsTarget.scrollHeight, 1)
    overlay.replaceChildren()

    const svg = document.createElementNS(SVG_NS, "svg")
    svg.setAttribute("width", String(width))
    svg.setAttribute("height", String(height))
    svg.setAttribute("viewBox", `0 0 ${width} ${height}`)
    svg.setAttribute("aria-hidden", "true")
    overlay.appendChild(svg)

    if (this.showProgressValue) {
      this.#drawProgressLine(svg, width)
    }

    if (this.showRelationsValue) {
      this.#drawRelations(svg)
    }
  }

  #drawRelations(svg) {
    const overlayRect = this.overlayTarget.getBoundingClientRect()

    this.relationsValue.forEach((relation) => {
      const fromAnchor = this.#anchorForRow(relation.from_row_key, "end")
      const toAnchor = this.#anchorForRow(relation.to_row_key, "start")

      if (!fromAnchor || !toAnchor) return

      const fromRect = fromAnchor.getBoundingClientRect()
      const toRect = toAnchor.getBoundingClientRect()
      const fromX = fromRect.left - overlayRect.left
      const fromY = fromRect.top - overlayRect.top
      const toX = toRect.left - overlayRect.left
      const toY = toRect.top - overlayRect.top
      const relationConfig = this.issueRelationTypesValue[relation.type] || {}
      const margin = relationConfig.landscape_margin || 0
      const color = relationConfig.color || "#000"
      const viaX = fromX + margin
      const targetViaX = toX - margin

      this.#drawPath(svg, ["M", fromX, fromY, "L", viaX, fromY], color)

      if (viaX < targetViaX) {
        this.#drawPath(svg, ["M", viaX, fromY, "L", viaX, toY, "L", toX, toY], color)
      } else {
        const midY = toY + (fromY > toY ? 10 : -10)
        this.#drawPath(svg, ["M", viaX, fromY, "L", viaX, midY, "L", targetViaX, midY, "L", targetViaX, toY, "L", toX, toY], color)
      }

      const arrow = document.createElementNS(SVG_NS, "path")
      arrow.setAttribute("d", ["M", toX, toY, "l", -8, -4, "l", 0, 8, "z"].join(" "))
      arrow.setAttribute("fill", color)
      arrow.setAttribute("stroke", "none")
      svg.appendChild(arrow)
    })
  }

  #drawProgressLine(svg, width) {
    if (!this.hasTodayLineTarget) return

    const overlayRect = this.overlayTarget.getBoundingClientRect()
    const todayRect = this.todayLineTarget.getBoundingClientRect()
    const todayX = todayRect.left - overlayRect.left
    const color = getComputedStyle(this.todayLineTarget).borderInlineStartColor || "#ff0000"
    const points = [{ left: todayX, top: 0 }]

    this.#visibleTimelineRows().forEach((row) => {
      const state = row.dataset.progressState
      if (!state || row.dataset.kind === "project") return

      const rowRect = row.getBoundingClientRect()
      const rowTop = rowRect.top - overlayRect.top
      const topUpper = rowTop + 6
      const topCenter = rowTop + rowRect.height / 2
      const topLower = rowTop + rowRect.height - 6

      if (state === "closed") {
        points.push({ left: todayX, top: topCenter })
        return
      }

      if (state === "over-end") {
        points.push({ left: width, top: topUpper, rightEdge: true })
        points.push({ left: width, top: topLower, rightEdge: true, skipStroke: true })
        return
      }

      if (state === "behind-start") {
        points.push({ left: 0, top: topUpper, leftEdge: true })
        points.push({ left: 0, top: topLower, leftEdge: true, skipStroke: true })
        return
      }

      const doneBar = row.querySelector(".task_done")
      if (doneBar) {
        const doneRect = doneBar.getBoundingClientRect()
        points.push({ left: doneRect.right - overlayRect.left, top: topCenter })
        return
      }

      const todoBar = row.querySelector(".task_todo")
      const todoLeft = todoBar ? todoBar.getBoundingClientRect().left - overlayRect.left : todayX
      points.push({ left: Math.min(todayX, todoLeft), top: topCenter })
    })

    for (let index = 1; index < points.length; index += 1) {
      const previous = points[index - 1]
      const current = points[index]

      if (
        current.skipStroke ||
        (previous.rightEdge && current.rightEdge) ||
        (previous.leftEdge && current.leftEdge)
      ) {
        continue
      }

      this.#drawPath(svg, ["M", previous.left, previous.top, "L", current.left, current.top], color)
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

  #anchorForRow(rowKey, side) {
    const selector = `[data-row-key="${rowKey}"] [data-gantt-role="${side}-anchor"]`
    const anchor = this.timelineRowsTarget.querySelector(selector)

    if (!anchor) return null

    const row = anchor.closest(".gantt__timeline-row")
    return row && row.classList.contains("is-hidden") ? null : anchor
  }

  #visibleTimelineRows() {
    return Array.from(this.timelineRowsTarget.querySelectorAll(".gantt__timeline-row")).filter((row) => !row.classList.contains("is-hidden"))
  }

  #setHoveredRow(rowKey, hovered) {
    if (!rowKey) return

    this.element.querySelectorAll(`[data-row-key="${rowKey}"]`).forEach((element) => {
      if (element.classList.contains("gantt__row") || element.classList.contains("gantt__timeline-row")) {
        element.classList.toggle("is-hovered", hovered)
      }
    })
  }
}
