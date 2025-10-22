import { Controller } from "@hotwired/stimulus"

const RELATION_COLORS = {
  blocks: "#fa5252",
  precedes: "#228be6"
}

export default class extends Controller {
  static targets = ["resizer"]

  static values = {
    subjectWidth: { type: Number, default: 320 },
    minWidth: { type: Number, default: 200 },
    maxWidth: { type: Number, default: 640 }
  }

  connect() {
    this.$ = window.jQuery
    this.collapsedKeys = new Set()
    this.rows = Array.from(this.element.querySelectorAll(".gantt-grid__row"))
    this.rowMap = new Map()

    this.rows.forEach((row) => {
      const key = row.dataset.gridKey
      if (key) {
        this.rowMap.set(key, row)
      }
    })

    this.updateWidth(this.subjectWidthValue)
    this.createRelationsLayer()
    this.applyVisibility()
    requestAnimationFrame(() => this.drawRelations())
  }

  disconnect() {
    this.stopResize()
    if (this.relationsLayer) {
      this.relationsLayer.remove()
      this.relationsLayer = null
    }
  }

  toggleRow(event) {
    event.preventDefault()
    event.stopPropagation()
    const button = event.currentTarget
    const key = button.dataset.gridKey
    if (!key) return

    if (this.collapsedKeys.has(key)) {
      this.collapsedKeys.delete(key)
      button.classList.add("gantt-grid__expander--expanded")
    } else {
      this.collapsedKeys.add(key)
      button.classList.remove("gantt-grid__expander--expanded")
    }

    this.applyVisibility()
    this.drawRelations()
  }

  applyVisibility() {
    this.rows.forEach((row) => {
      const key = row.dataset.gridKey
      let parentKey = row.dataset.gridParent
      let visible = true
      while (parentKey) {
        if (this.collapsedKeys.has(parentKey)) {
          visible = false
          break
        }
        const parentRow = this.rowMap.get(parentKey)
        parentKey = parentRow ? parentRow.dataset.gridParent : null
      }
      if (!visible) {
        row.classList.add("is-hidden")
      } else {
        row.classList.remove("is-hidden")
      }
    })
  }

  createRelationsLayer() {
    const svgNS = "http://www.w3.org/2000/svg"
    this.relationsLayer = document.createElementNS(svgNS, "svg")
    this.relationsLayer.classList.add("gantt-grid__relations")

    const defs = document.createElementNS(svgNS, "defs")
    Object.entries(RELATION_COLORS).forEach(([type, color]) => {
      const marker = document.createElementNS(svgNS, "marker")
      marker.setAttribute("id", `gantt-arrow-${type}`)
      marker.setAttribute("markerWidth", "6")
      marker.setAttribute("markerHeight", "6")
      marker.setAttribute("refX", "5")
      marker.setAttribute("refY", "3")
      marker.setAttribute("orient", "auto")
      const markerPath = document.createElementNS(svgNS, "path")
      markerPath.setAttribute("d", "M0,0 L6,3 L0,6 z")
      markerPath.setAttribute("fill", color)
      marker.appendChild(markerPath)
      defs.appendChild(marker)
    })
    this.relationsLayer.appendChild(defs)
    this.element.appendChild(this.relationsLayer)
  }

  drawRelations() {
    if (!this.relationsLayer) return

    const chartWidth = this.chartWidth()
    const gridHeight = this.element.offsetHeight
    this.relationsLayer.setAttribute("width", chartWidth)
    this.relationsLayer.setAttribute("height", gridHeight)
    this.relationsLayer.setAttribute("viewBox", `0 0 ${chartWidth} ${gridHeight}`)

    const existingPaths = Array.from(this.relationsLayer.querySelectorAll("path.relation-path"))
    existingPaths.forEach((path) => path.remove())

    const svgNS = "http://www.w3.org/2000/svg"
    const visibleRows = this.rows.filter((row) => !row.classList.contains("is-hidden"))

    visibleRows.forEach((row) => {
      const relationsData = row.dataset.gridRelations
      if (!relationsData || relationsData === "[]") return

      let relations
      try {
        relations = JSON.parse(relationsData)
      } catch (e) {
        relations = []
      }
      if (!relations || !relations.length) return

      const barStart = parseFloat(row.dataset.gridBarStart || "0")
      const barWidth = parseFloat(row.dataset.gridBarWidth || "0")
      const startX = chartWidth * ((barStart + barWidth) / 100)
      const startY = row.offsetTop + row.offsetHeight / 2

      relations.forEach((relation) => {
        const targetRow = this.rowMap.get(relation.to_key || relation.toKey)
        if (!targetRow || targetRow.classList.contains("is-hidden")) return

        const targetStart = parseFloat(targetRow.dataset.gridBarStart || "0")
        const targetX = chartWidth * (targetStart / 100)
        const targetY = targetRow.offsetTop + targetRow.offsetHeight / 2

        const midX = Math.max(startX + 16, (startX + targetX) / 2)
        const path = document.createElementNS(svgNS, "path")
        path.classList.add("relation-path")
        path.setAttribute("d", `M ${startX} ${startY} L ${midX} ${startY} L ${midX} ${targetY} L ${targetX} ${targetY}`)
        const color = RELATION_COLORS[relation.type] || "#888"
        path.setAttribute("stroke", color)
        path.setAttribute("stroke-width", "1.6")
        path.setAttribute("fill", "none")
        const markerId = RELATION_COLORS[relation.type] ? `url(#gantt-arrow-${relation.type})` : ""
        if (markerId) {
          path.setAttribute("marker-end", markerId)
        }
        this.relationsLayer.appendChild(path)
      })
    })
  }

  chartWidth() {
    const chart = this.element.querySelector(".gantt-grid__row:not(.is-hidden) .gantt-grid__chart")
    return chart ? chart.offsetWidth : 0
  }

  startResize(event) {
    event.preventDefault()
    this.startX = this.pointerX(event)
    this.startWidth = this.subjectWidthValue

    this.boundResize = this.handlePointerMove.bind(this)
    this.boundStop = this.stopResize.bind(this)

    window.addEventListener("mousemove", this.boundResize)
    window.addEventListener("touchmove", this.boundResize, { passive: false })
    window.addEventListener("mouseup", this.boundStop)
    window.addEventListener("touchend", this.boundStop)
  }

  handlePointerMove(event) {
    if (!this.boundResize) return
    event.preventDefault()
    const delta = this.pointerX(event) - this.startX
    this.updateWidth(this.startWidth + delta)
  }

  stopResize() {
    if (!this.boundResize) return
    window.removeEventListener("mousemove", this.boundResize)
    window.removeEventListener("touchmove", this.boundResize)
    window.removeEventListener("mouseup", this.boundStop)
    window.removeEventListener("touchend", this.boundStop)
    this.boundResize = null
    this.boundStop = null
    this.drawRelations()
  }

  pointerX(event) {
    if (event.touches && event.touches.length > 0) {
      return event.touches[0].clientX
    }
    return event.clientX
  }

  updateWidth(width) {
    const min = this.minWidthValue || 200
    const max = this.maxWidthValue || 640
    const clamped = Math.max(min, Math.min(max, width))
    this.subjectWidthValue = clamped
    this.element.style.setProperty("--subject-width", `${clamped}px`)
    if (this.hasResizerTarget) {
      this.resizerTarget.style.left = `${clamped}px`
    }
    requestAnimationFrame(() => this.drawRelations())
  }

  handleWindowResize() {
    requestAnimationFrame(() => this.drawRelations())
  }

  toggleDisplay(event) {
    const enabled = event.detail ? event.detail.enabled !== false : true
    this.element.classList.toggle("gantt-grid--hide-meta", !enabled)
    requestAnimationFrame(() => this.drawRelations())
  }

  toggleRelations(event) {
    const enabled = event.detail ? event.detail.enabled !== false : true
    this.element.classList.toggle("gantt-grid--hide-relations", !enabled)
    requestAnimationFrame(() => this.drawRelations())
  }

  toggleProgress(event) {
    const enabled = event.detail ? event.detail.enabled !== false : true
    this.element.classList.toggle("gantt-grid--hide-progress", !enabled)
  }
}
