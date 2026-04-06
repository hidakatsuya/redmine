import { Controller } from '@hotwired/stimulus'

class CommonMarkTableFormatter {
  format(rows) {
    if (rows.length === 0) return null

    const output = []
    output.push(this.#formatRow(rows[0]))

    const separator = rows[0].map(() => '---').join(' | ')
    output.push(`| ${separator} |`)

    for (let i = 1; i < rows.length; i++) {
      output.push(this.#formatRow(rows[i]))
    }

    return output.join('\n')
  }

  #formatRow(row) {
    return `| ${row.map(cell => this.#formatTableCell(cell)).join(' | ')} |`
  }

  #formatTableCell(cell) {
    return cell
      .replaceAll('|', '\\|')
      .replace(/\r\n?|\n/g, '<br>')
  }
}

class TextileTableFormatter {
  format(rows) {
    if (rows.length === 0) return null

    const output = []
    output.push(`|_. ${rows[0].map(cell => this.#formatTableCell(cell)).join(' |_. ')} |`)

    for (let i = 1; i < rows.length; i++) {
      output.push(`| ${rows[i].map(cell => this.#formatTableCell(cell)).join(' | ')} |`)
    }

    return output.join('\n')
  }

  #formatTableCell(cell) {
    return cell
      .replaceAll('|', '&#124;')
      .replace(/\r\n?/g, '\n')
  }
}

export default class extends Controller {
  handlePaste(event) {
    const formatter = this.#tableFormatterFor(event)
    if (!formatter) return

    const rows = this.#extractTableFromClipboard(event)
    if (!rows) return

    const table = formatter.format(rows)
    if (!table) return

    event.preventDefault()
    this.#insertTextAtCursor(event.currentTarget, table)
  }

  #tableFormatterFor(event) {
    const format = event.params?.textFormatting ||
      event.currentTarget.dataset.tablePasteTextFormattingParam

    switch (format) {
      case 'common_mark':
        return new CommonMarkTableFormatter()
      case 'textile':
        return new TextileTableFormatter()
      default:
        return null
    }
  }

  #extractTableFromClipboard(event) {
    const clipboardData = event.clipboardData || window.clipboardData
    if (!clipboardData) return null

    const htmlData = clipboardData.getData('text/html')
    if (!htmlData) return null

    return this.#extractTableFromHtml(htmlData)
  }

  #extractTableFromHtml(html) {
    const temp = document.createElement('div')
    temp.innerHTML = html.replace(/\r?\n/g, '')

    const table = temp.querySelector('table')
    if (!table) return null

    const rows = []
    table.querySelectorAll('tr').forEach(tr => {
      const cells = []
      tr.querySelectorAll('td, th').forEach(cell => {
        cells.push(this.#extractCellText(cell).trim())
      })
      if (cells.length > 0) {
        rows.push(cells)
      }
    })

    return this.#normalizeRows(rows)
  }

  #normalizeRows(rows) {
    if (rows.length === 0) return null

    const maxColumns = rows.reduce((currentMax, row) => Math.max(currentMax, row.length), 0)
    if (maxColumns < 2) return null

    rows.forEach(row => {
      while (row.length < maxColumns) {
        row.push('')
      }
    })

    return rows
  }

  #extractCellText(cell) {
    const clone = cell.cloneNode(true)

    clone.querySelectorAll('br').forEach(br => {
      br.replaceWith('\n')
    })

    return clone.textContent
  }

  #insertTextAtCursor(input, text) {
    const { selectionStart, selectionEnd } = input

    const replacement = `${text}\n\n`

    input.setRangeText(replacement, selectionStart, selectionEnd, 'end')
    const newCursorPos = selectionStart + replacement.length
    input.setSelectionRange(newCursorPos, newCursorPos)

    input.dispatchEvent(new Event('input', { bubbles: true }))
  }
}
