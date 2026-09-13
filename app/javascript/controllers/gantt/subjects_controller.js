import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  initialize() {
    this.$ = window.jQuery
  }

  handleEntryClick(event) {
    const iconExpander = event.currentTarget
    const $subject = this.$(iconExpander.parentElement)
    const subjectInlineStart =
      this.#readIndent($subject) + parseInt(iconExpander.offsetWidth, 10)

    let targetShown = null
    let targetTop = 0
    let totalHeight = 0
    let outOfHierarchy = false

    const willOpen = !$subject.hasClass("open")

    this.#setIconState($subject, willOpen)

    $subject.nextAll("div").each((_, element) => {
      const $element = this.$(element)
      const json = $element.data("collapse-expand")
      const numberOfRows = $element.data("number-of-rows")
      const rowsSelector = `#gantt_area form > .gantt_row[data-collapse-expand='${json.obj_id}'][data-number-of-rows='${numberOfRows}']`
      const selectedColumnsSelector = `td.gantt_selected_column div[data-collapse-expand='${json.obj_id}'][data-number-of-rows='${numberOfRows}']`

      if (outOfHierarchy || this.#readIndent($element) <= subjectInlineStart) {
        outOfHierarchy = true

        if (targetShown === null) return false

        const newTopVal = this.#readBlockStart($element) + totalHeight * (targetShown ? -1 : 1)

        this.#setBlockStart($element, newTopVal)
        this.$([rowsSelector, selectedColumnsSelector].join()).each((__, el) => {
          this.#setBlockStart(this.$(el), newTopVal)
        })

        return true
      }

      const isShown = $element.is(":visible")

      if (targetShown === null) {
        targetShown = isShown
        targetTop = this.#readBlockStart($element)
        totalHeight = 0
      }

      if (isShown === targetShown) {
        this.$(rowsSelector).each((__, row) => {
          const $row = this.$(row)

          if (!isShown && willOpen) {
            this.#setBlockStart($row, targetTop + totalHeight)
          }
          $row.toggle(willOpen)
        })

        this.$(selectedColumnsSelector).each((__, attr) => {
          const $attr = this.$(attr)

          if (!isShown && willOpen) {
            this.#setBlockStart($attr, targetTop + totalHeight)
          }
          $attr.toggle(willOpen)
        })

        if (!isShown && willOpen) {
          this.#setBlockStart($element, targetTop + totalHeight)
        }

        this.#setIconState($element, willOpen)
        $element.toggle(willOpen)
        totalHeight += parseInt(json.top_increment, 10)
      }
    })

    this.dispatch("toggle-tree", { bubbles: true })
  }

  #readIndent(el) {
    const node = el.jquery ? el[0] : el
    return parseFloat(window.getComputedStyle(node).getPropertyValue("padding-inline-start"))
  }

  #readBlockStart(el) {
    const node = el.jquery ? el[0] : el
    return parseFloat(window.getComputedStyle(node).getPropertyValue("inset-block-start"))
  }

  #setBlockStart(el, value) {
    const node = el.jquery ? el[0] : el
    const px = typeof value === "number" ? `${value}px` : value
    node.style.setProperty("inset-block-start", px)
  }

  #setIconState(element, open) {
    const $element = element.jquery ? element : this.$(element)
    const expander = $element.find(".expander")

    if (open) {
      $element.addClass("open")

      if (expander.length > 0) {
        expander.removeClass("icon-collapsed").addClass("icon-expanded")

        if (expander.find("svg").length === 1) {
          window.updateSVGIcon(expander[0], "angle-down")
        }
      }
    } else {
      $element.removeClass("open")

      if (expander.length > 0) {
        expander.removeClass("icon-expanded").addClass("icon-collapsed")

        if (expander.find("svg").length === 1) {
          window.updateSVGIcon(expander[0], "angle-right")
        }
      }
    }
  }
}
