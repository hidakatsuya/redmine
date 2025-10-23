import { Controller } from "@hotwired/stimulus"

const RELATION_CONFIG = {
  blocks: { color: "#fa5252", margin: 16 },
  precedes: { color: "#228be6", margin: 20 }
}

export default class extends Controller {
  static targets = ["body", "resizer"]

  static values = {
    subjectWidth: { type: Number, default: 320 },
    minWidth: { type: Number, default: 200 },
    maxWidth: { type: Number, default: 640 }
  }

  connect() {
    this.collapsedKeys = new Set()
    this.header = this.element.querySelector(".gantt-grid__header")
    this.body = this.hasBodyTarget ? this.bodyTarget : this.element.querySelector(".gantt-grid__body")
    this.rows = Array.from(this.body.querySelectorAll(".gantt-grid__row"))
    this.rowMap = new Map()

    this.rows.forEach((row) => {
      const key = row.dataset.gridKey
      if (key) {
        this.rowMap.set(key, row)
      }
    })

    this.createRelationsLayer()
    this.applyVisibility()
    this.updateWidth(this.subjectWidthValue || this.currentSubjectWidth())
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
    requestAnimationFrame(() => this.drawRelations())
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

  drawRelations() {
    if (!this.relationsLayer) return

    const timelineWidth = this.timelineWidth()
    if (!timelineWidth) return

    const headerHeight = this.header ? this.header.offsetHeight : 0
    const bodyHeight = this.body ? this.body.offsetHeight : 0
    const chartOffset = this.chartOffset()

    this.relationsLayer.setAttribute("width", timelineWidth)
    this.relationsLayer.setAttribute("height", bodyHeight)
    this.relationsLayer.setAttribute("viewBox", `0 0 ${timelineWidth} ${bodyHeight}`)
    this.relationsLayer.style.width = `${timelineWidth}px`
    this.relationsLayer.style.height = `${bodyHeight}px`
    this.relationsLayer.style.left = `${chartOffset}px`
    this.relationsLayer.style.top = `${headerHeight}px`

    const existingPaths = Array.from(this.relationsLayer.querySelectorAll("path.relation-path"))
    existingPaths.forEach((path) => path.remove())

    if (this.element.classList.contains("gantt-grid--hide-relations")) {
      return
    }

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

      const barElement = row.querySelector(".gantt-grid__bar")
      if (!barElement) return
      const barStart = parseFloat(row.dataset.gridBarStartPx || "0")
      const barWidth = parseFloat(row.dataset.gridBarWidthPx || "0")
      if (barWidth <= 0) return
      const startX = barStart + barWidth
      const startY = row.offsetTop - headerHeight + row.offsetHeight / 2
      const barHeight = barElement.offsetHeight || row.offsetHeight / 2

      relations.forEach((relation) => {
        const targetRow = this.rowMap.get(relation.to_key || relation.toKey)
        if (!targetRow || targetRow.classList.contains("is-hidden")) return

        const targetBar = targetRow.querySelector(".gantt-grid__bar")
        if (!targetBar) return
        const targetStart = parseFloat(targetRow.dataset.gridBarStartPx || "0")
        const targetWidth = parseFloat(targetRow.dataset.gridBarWidthPx || "0")
        const targetX = targetStart
        const targetY = targetRow.offsetTop - headerHeight + targetRow.offsetHeight / 2

        const relationConfig = RELATION_CONFIG[relation.type] || { color: "#888", margin: 16 }
        const margin = relationConfig.margin || 0
        const color = relationConfig.color || "#888"

        const startOffsetX = Math.min(startX + margin, timelineWidth)
        const targetOffsetX = Math.max(targetX - margin, 0)

        const pathSegments = ["M", startX, startY, "L", startOffsetX, startY]

        if (startOffsetX < targetOffsetX) {
          pathSegments.push("L", startOffsetX, targetY, "L", targetX, targetY)
        } else {
          const direction = startY > targetY ? 1 : -1
          const middleY = targetY + barHeight * direction
          pathSegments.push(
            "L",
            startOffsetX,
            middleY,
            "L",
            targetOffsetX,
            middleY,
            "L",
            targetOffsetX,
            targetY,
            "L",
            targetX,
            targetY
          )
        }

        const path = document.createElementNS(svgNS, "path")
        path.classList.add("relation-path")
        path.setAttribute("d", pathSegments.join(" "))
        path.setAttribute("stroke", color)
        path.setAttribute("stroke-width", "1.6")
        path.setAttribute("fill", "none")
        if (RELATION_CONFIG[relation.type]) {
          path.setAttribute("marker-end", `url(#gantt-arrow-${relation.type})`)
        }
        this.relationsLayer.appendChild(path)
      })
    })
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

  startResize(event) {
    if (!this.hasResizerTarget) return
    event.preventDefault()
    this.startX = this.pointerX(event)
    this.startWidth = this.subjectWidthValue || this.currentSubjectWidth()

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
    requestAnimationFrame(() => this.drawRelations())
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
    requestAnimationFrame(() => this.drawRelations())
  }

  createRelationsLayer() {
    if (this.relationsLayer) return

    const svgNS = "http://www.w3.org/2000/svg"
    this.relationsLayer = document.createElementNS(svgNS, "svg")
    this.relationsLayer.classList.add("gantt-grid__relations")

    const defs = document.createElementNS(svgNS, "defs")
    Object.entries(RELATION_CONFIG).forEach(([type, config]) => {
      const color = config.color
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

  timelineWidth() {
    const value = getComputedStyle(this.element).getPropertyValue("--timeline-width")
    return parseFloat(value) || 0
  }

  chartOffset() {
    const style = getComputedStyle(this.element)
    const widths = ["--subject-width"]
    if (!this.element.classList.contains("gantt-grid--hide-meta")) {
      widths.push("--status-width", "--priority-width", "--assignee-width")
    }
    return widths.reduce((total, name) => total + (parseFloat(style.getPropertyValue(name)) || 0), 0)
  }

  currentSubjectWidth() {
    const style = getComputedStyle(this.element)
    return parseFloat(style.getPropertyValue("--subject-width")) || this.subjectWidthValue
  }
}
