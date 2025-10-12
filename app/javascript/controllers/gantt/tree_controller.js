import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.$ = window.jQuery
    this.handleEntryClick = this.handleEntryClick.bind(this)
    this.expanderElements().on("click", this.handleEntryClick)
  }

  disconnect() {
    this.expanderElements().off("click", this.handleEntryClick)
  }

  expanderElements() {
    return this.$(".expander", this.element)
  }

  handleEntryClick(event) {
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

        const newTopVal = parseInt($element.css("top"), 10) + totalHeight * (targetShown ? -1 : 1)
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
    this.dispatch("changed", { bubbles: true })
  }
}
