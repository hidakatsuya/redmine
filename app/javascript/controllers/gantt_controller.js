import { Controller } from "@hotwired/stimulus"

const RELATION_STROKE_WIDTH = 2

export default class extends Controller {
  static targets = [
    "form",
    "ganttArea",
    "drawArea",
    "relationsToggle",
    "progressToggle",
    "selectedColumnsToggle",
    "subjectsContainer"
  ]

  connect() {
    this.$ = window.jQuery
    this.drawPaper = null
    this.drawTop = 0
    this.drawRight = 0
    this.drawLeft = 0
    this.initialized = false
    this.issueRelationType = this.readJSONValue("issueRelationType", {})
    this.unavailableColumns = this.readJSONValue("unavailableColumns", [])

    this.handleEntryClick = this.handleEntryClick.bind(this)

    this.initializeWhenReady()
  }

  disconnect() {
    if (this.resizeHandler) {
      window.removeEventListener("resize", this.resizeHandler)
      this.resizeHandler = null
    }
    this.detachExpanderListeners()
    if (this.drawPaper) {
      this.drawPaper.remove()
      this.drawPaper = null
    }
  }

  initializeWhenReady() {
    if (!this.$) {
      return
    }

    const start = () => this.initialize()
    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", start, { once: true })
    } else {
      start()
    }
  }

  initialize() {
    if (this.initialized) {
      return
    }
    if (!window.Raphael) {
      window.setTimeout(() => this.initialize(), 50)
      return
    }
    this.disableUnavailableColumns()
    this.drawGanttHandler()
    this.resizableSubjectColumn()
    this.drawSelectedColumns()
    this.attachExpanderListeners()
    this.resizeHandler = () => {
      this.drawGanttHandler()
      this.resizableSubjectColumn()
    }
    window.addEventListener("resize", this.resizeHandler)
    this.initialized = true
  }

  toggleChanged() {
    this.drawGanttHandler()
    this.resizableSubjectColumn()
  }

  drawGanttHandler() {
    if (!this.$ || !this.hasDrawAreaTarget || !window.Raphael) {
      return
    }
    const folder = this.drawAreaTarget
    if (this.drawPaper) {
      this.drawPaper.clear()
    } else {
      this.drawPaper = window.Raphael(folder)
    }
    this.setDrawArea()
    this.drawSelectedColumns()
    if (this.hasProgressToggleTarget && this.progressToggleTarget.checked) {
      try {
        this.drawGanttProgressLines()
      } catch (error) {
        console.error("drawGanttProgressLines failed", error)
      }
    }
    if (this.hasRelationsToggleTarget && this.relationsToggleTarget.checked) {
      this.drawRelations()
    }
    const content = document.getElementById("content")
    if (content) {
      content.classList.add("gantt_content")
    }
  }

  setDrawArea() {
    const $drawArea = this.$(this.drawAreaTarget)
    const $ganttArea = this.hasGanttAreaTarget ? this.$(this.ganttAreaTarget) : null
    this.drawTop = $drawArea.position().top
    this.drawRight = $drawArea.width()
    this.drawLeft = $ganttArea ? $ganttArea.scrollLeft() : 0
  }

  drawSelectedColumns() {
    if (!this.$) {
      return
    }
    const $selectedColumns = this.$("td.gantt_selected_column")
    const $subjectsContainer = this.hasSubjectsContainerTarget ? this.$(this.subjectsContainerTarget) : null

    const isMobileDevice = typeof window.isMobile === "function" && window.isMobile()

    if (this.hasSelectedColumnsToggleTarget && this.selectedColumnsToggleTarget.checked) {
      if (isMobileDevice) {
        $selectedColumns.hide()
      } else {
        if ($subjectsContainer) {
          $subjectsContainer.addClass("draw_selected_columns")
        }
        $selectedColumns.each((_, element) => {
          const $element = this.$(element)
          $element.show()
          const columnName = $element.attr("id")
          try {
            $element.resizable("destroy")
          } catch (error) {
            // resizable was not initialised yet
          }
          $element
            .resizable({
              zIndex: 30,
              alsoResize: `.gantt_${columnName}_container, .gantt_${columnName}_container > .gantt_hdr`,
              minWidth: 20,
              handles: "e",
              create() {
                window.jQuery(".ui-resizable-e").css("cursor", "ew-resize")
              }
            })
            .on("resize", (event) => {
              event.stopPropagation()
            })
        })
      }
    } else {
      $selectedColumns.each((_, element) => {
        this.$(element).hide()
      })
      if ($subjectsContainer) {
        $subjectsContainer.removeClass("draw_selected_columns")
      }
    }
  }

  resizableSubjectColumn() {
    if (!this.$) {
      return
    }
    const $subjectsColumn = this.$("td.gantt_subjects_column")
    this.$(".issue-subject, .project-name, .version-name").each((_, element) => {
      const $element = this.$(element)
      $element.width($subjectsColumn.width() - $element.position().left)
    })

    $subjectsColumn
      .resizable({
        alsoResize: ".gantt_subjects_container, .gantt_subjects_container>.gantt_hdr, .project-name, .issue-subject, .version-name",
        minWidth: 100,
        handles: "e",
        zIndex: 30,
        create() {
          window.jQuery(".ui-resizable-e").css("cursor", "ew-resize")
        }
      })
      .on("resize", (event) => {
        event.stopPropagation()
      })

    const isMobileDevice = typeof window.isMobile === "function" && window.isMobile()
    if (isMobileDevice) {
      $subjectsColumn.resizable("disable")
    } else {
      $subjectsColumn.resizable("enable")
    }
  }

  getRelationsArray() {
    if (!this.$) {
      return []
    }
    const relations = []
    this.$("div.task_todo[data-rels]").each((_, element) => {
      const $element = this.$(element)
      if (!$element.is(":visible")) {
        return true
      }
      const elementId = $element.attr("id")
      if (!elementId) {
        return
      }
      const issueId = elementId.replace("task-todo-issue-", "")
      const dataRels = $element.data("rels") || {}
      Object.keys(dataRels).forEach((relTypeKey) => {
        this.$.each(dataRels[relTypeKey], (_, relatedIssue) => {
          relations.push({ issue_from: issueId, issue_to: relatedIssue, rel_type: relTypeKey })
        })
      })
    })
    return relations
  }

  drawRelations() {
    if (!this.$ || !this.drawPaper) {
      return
    }
    const relations = this.getRelationsArray()
    relations.forEach((relation) => {
      const issueFrom = this.$(`#task-todo-issue-${relation.issue_from}`)
      const issueTo = this.$(`#task-todo-issue-${relation.issue_to}`)
      if (issueFrom.length === 0 || issueTo.length === 0) {
        return
      }
      const issueHeight = issueFrom.height()
      const issueFromTop = issueFrom.position().top + issueHeight / 2 - this.drawTop
      const issueFromRight = issueFrom.position().left + issueFrom.width()
      const issueToTop = issueTo.position().top + issueHeight / 2 - this.drawTop
      const issueToLeft = issueTo.position().left
      const relationConfig = this.issueRelationType?.[relation.rel_type] || {}
      const color = relationConfig.color || "#000"
      const landscapeMargin = relationConfig.landscape_margin || 0
      const issueFromRightRel = issueFromRight + landscapeMargin
      const issueToLeftRel = issueToLeft - landscapeMargin

      this.drawPaper
        .path([
          "M",
          issueFromRight + this.drawLeft,
          issueFromTop,
          "L",
          issueFromRightRel + this.drawLeft,
          issueFromTop
        ])
        .attr({ stroke: color, "stroke-width": RELATION_STROKE_WIDTH })

      if (issueFromRightRel < issueToLeftRel) {
        this.drawPaper
          .path([
            "M",
            issueFromRightRel + this.drawLeft,
            issueFromTop,
            "L",
            issueFromRightRel + this.drawLeft,
            issueToTop
          ])
          .attr({ stroke: color, "stroke-width": RELATION_STROKE_WIDTH })
        this.drawPaper
          .path([
            "M",
            issueFromRightRel + this.drawLeft,
            issueToTop,
            "L",
            issueToLeft + this.drawLeft,
            issueToTop
          ])
          .attr({ stroke: color, "stroke-width": RELATION_STROKE_WIDTH })
      } else {
        const issueMiddleTop = issueToTop + issueHeight * (issueFromTop > issueToTop ? 1 : -1)
        this.drawPaper
          .path([
            "M",
            issueFromRightRel + this.drawLeft,
            issueFromTop,
            "L",
            issueFromRightRel + this.drawLeft,
            issueMiddleTop
          ])
          .attr({ stroke: color, "stroke-width": RELATION_STROKE_WIDTH })
        this.drawPaper
          .path([
            "M",
            issueFromRightRel + this.drawLeft,
            issueMiddleTop,
            "L",
            issueToLeftRel + this.drawLeft,
            issueMiddleTop
          ])
          .attr({ stroke: color, "stroke-width": RELATION_STROKE_WIDTH })
        this.drawPaper
          .path([
            "M",
            issueToLeftRel + this.drawLeft,
            issueMiddleTop,
            "L",
            issueToLeftRel + this.drawLeft,
            issueToTop
          ])
          .attr({ stroke: color, "stroke-width": RELATION_STROKE_WIDTH })
        this.drawPaper
          .path([
            "M",
            issueToLeftRel + this.drawLeft,
            issueToTop,
            "L",
            issueToLeft + this.drawLeft,
            issueToTop
          ])
          .attr({ stroke: color, "stroke-width": RELATION_STROKE_WIDTH })
      }
      this.drawPaper
        .path([
          "M",
          issueToLeft + this.drawLeft,
          issueToTop,
          "l",
          -4 * RELATION_STROKE_WIDTH,
          -2 * RELATION_STROKE_WIDTH,
          "l",
          0,
          4 * RELATION_STROKE_WIDTH,
          "z"
        ])
        .attr({
          stroke: "none",
          fill: color,
          "stroke-linecap": "butt",
          "stroke-linejoin": "miter"
        })
    })
  }

  getProgressLinesArray() {
    if (!this.$) {
      return []
    }
    const progressLines = []
    const todayLeft = this.$("#today_line").position().left
    progressLines.push({ left: todayLeft, top: 0 })
    this.$("div.issue-subject, div.version-name").each((_, element) => {
      const $element = this.$(element)
      if (!$element.is(":visible")) {
        return true
      }
      const topPosition = $element.position().top - this.drawTop
      const elementHeight = $element.height() / 9
      const elementTopUpper = topPosition - elementHeight
      const elementTopCenter = topPosition + elementHeight * 3
      const elementTopLower = topPosition + elementHeight * 8
      const issueClosed = $element.children("span").hasClass("issue-closed")
      const versionClosed = $element.children("span").hasClass("version-closed")
      if (issueClosed || versionClosed) {
        progressLines.push({ left: todayLeft, top: elementTopCenter })
      } else {
        const issueDone = this.$(`#task-done-${$element.attr("id")}`)
        const isBehindStart = $element.children("span").hasClass("behind-start-date")
        const isOverEnd = $element.children("span").hasClass("over-end-date")
        if (isOverEnd) {
          progressLines.push({ left: this.drawRight, top: elementTopUpper, is_right_edge: true })
          progressLines.push({
            left: this.drawRight,
            top: elementTopLower,
            is_right_edge: true,
            none_stroke: true
          })
        } else if (issueDone.length > 0) {
          const doneLeft = issueDone.first().position().left + issueDone.first().width()
          progressLines.push({ left: doneLeft, top: elementTopCenter })
        } else if (isBehindStart) {
          progressLines.push({ left: 0, top: elementTopUpper, is_left_edge: true })
          progressLines.push({
            left: 0,
            top: elementTopLower,
            is_left_edge: true,
            none_stroke: true
          })
        } else {
          let todoLeft = todayLeft
          const issueTodo = this.$(`#task-todo-${$element.attr("id")}`)
          if (issueTodo.length > 0) {
            todoLeft = issueTodo.first().position().left
          }
          progressLines.push({ left: Math.min(todayLeft, todoLeft), top: elementTopCenter })
        }
      }
    })
    return progressLines
  }

  drawGanttProgressLines() {
    if (!this.drawPaper) {
      return
    }
    const progressLines = this.getProgressLinesArray()
    const color = this.$("#today_line").css("border-left-color") || "#ff0000"
    for (let index = 1; index < progressLines.length; index += 1) {
      const current = progressLines[index]
      const previous = progressLines[index - 1]
      if (
        !current.none_stroke &&
        !(
          (previous.is_right_edge && current.is_right_edge) ||
          (previous.is_left_edge && current.is_left_edge)
        )
      ) {
        const x1 = previous.left === 0 ? 0 : previous.left + this.drawLeft
        const x2 = current.left === 0 ? 0 : current.left + this.drawLeft
        this.drawPaper
          .path(["M", x1, previous.top, "L", x2, current.top])
          .attr({ stroke: color, "stroke-width": 2 })
      }
    }
  }

  handleEntryClick(event) {
    if (!this.$) {
      return
    }
    const iconExpander = event.currentTarget
    const $subject = this.$(iconExpander.parentElement)
    const subjectLeft =
      parseInt($subject.css("left"), 10) + parseInt(iconExpander.offsetWidth, 10)
    let targetShown = null
    let targetTop = 0
    let totalHeight = 0
    let outOfHierarchy = false

    const toggleIcon = (element) => {
      const $element = this.$(element)
      const expander = $element.find(".expander")
      if ($element.hasClass("open")) {
        expander.switchClass("icon-expanded", "icon-collapsed")
        $element.removeClass("open")
        if (expander.find("svg").length === 1) {
          window.updateSVGIcon(expander[0], "angle-right")
        }
      } else {
        expander.switchClass("icon-collapsed", "icon-expanded")
        $element.addClass("open")
        if (expander.find("svg").length === 1) {
          window.updateSVGIcon(expander[0], "angle-down")
        }
      }
    }

    toggleIcon($subject)

    $subject.nextAll("div").each((_, element) => {
      const $element = this.$(element)
      const json = $element.data("collapse-expand")
      const numberOfRows = $element.data("number-of-rows")
      const barsSelector = `#gantt_area form > div[data-collapse-expand='${json.obj_id}'][data-number-of-rows='${numberOfRows}']`
      const selectedColumnsSelector = `td.gantt_selected_column div[data-collapse-expand='${json.obj_id}'][data-number-of-rows='${numberOfRows}']`
      if (outOfHierarchy || parseInt($element.css("left"), 10) <= subjectLeft) {
        outOfHierarchy = true
        if (targetShown === null) {
          return false
        }
        const newTopVal =
          parseInt($element.css("top"), 10) + totalHeight * (targetShown ? -1 : 1)
        $element.css("top", newTopVal)
        this.$([barsSelector, selectedColumnsSelector].join()).each((__, el) => {
          this.$(el).css("top", newTopVal)
        })
        return true
      }

      const isShown = $element.is(":visible")
      if (targetShown === null) {
        targetShown = isShown
        targetTop = parseInt($element.css("top"), 10)
        totalHeight = 0
      }
      if (isShown === targetShown) {
        this.$(barsSelector).each((__, task) => {
          const $task = this.$(task)
          if (!isShown) {
            $task.css("top", targetTop + totalHeight)
          }
          if (!$task.hasClass("tooltip")) {
            $task.toggle(!isShown)
          }
        })
        this.$(selectedColumnsSelector).each((__, attr) => {
          const $attr = this.$(attr)
          if (!isShown) {
            $attr.css("top", targetTop + totalHeight)
          }
          $attr.toggle(!isShown)
        })
        if (!isShown) {
          $element.css("top", targetTop + totalHeight)
        }
        toggleIcon($element)
        $element.toggle(!isShown)
        totalHeight += parseInt(json.top_increment, 10)
      }
    })
    this.drawGanttHandler()
  }

  disableUnavailableColumns() {
    if (!this.$ || !Array.isArray(this.unavailableColumns)) {
      return
    }
    this.unavailableColumns.forEach((column) => {
      this.$("#available_c, #selected_c").children(`[value='${column}']`).prop("disabled", true)
    })
  }

  attachExpanderListeners() {
    if (!this.$) {
      return
    }
    this.detachExpanderListeners()
    this.$("div.gantt_subjects .expander").on("click", this.handleEntryClick)
  }

  detachExpanderListeners() {
    if (!this.$) {
      return
    }
    this.$("div.gantt_subjects .expander").off("click", this.handleEntryClick)
  }

  readJSONValue(name, fallback) {
    const datasetKey = `gantt${name.charAt(0).toUpperCase()}${name.slice(1)}`
    const raw = this.element.dataset[datasetKey]
    if (!raw) {
      return fallback
    }
    try {
      return JSON.parse(raw)
    } catch (error) {
      console.warn(`gantt_controller: failed to parse ${name}`, error)
      return fallback
    }
  }
}
