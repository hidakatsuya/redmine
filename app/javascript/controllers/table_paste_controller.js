import { Controller } from '@hotwired/stimulus'

class TablePasteHandler {
  constructor(inputElement, format) {
    this.input = inputElement
    this.format = format
  }

  run(event) {
    const clipboardData = event.clipboardData || window.clipboardData
    if (!clipboardData) return

    // Check if HTML data is available (from Excel, Sheets, etc.)
    const htmlData = clipboardData.getData('text/html')
    const textData = clipboardData.getData('text/plain')

    if (!htmlData && !textData) return

    let tableData = null

    // Try to extract table from HTML first
    if (htmlData) {
      tableData = this.extractTableFromHtml(htmlData)
    }

    // If no table in HTML, try to parse as TSV from plain text
    if (!tableData && textData) {
      tableData = this.extractTableFromTsv(textData)
    }

    if (!tableData || tableData.length < 1) return

    // Convert to markdown table based on format
    let markdownTable
    if (this.format === 'common_mark') {
      markdownTable = this.toCommonMarkTable(tableData)
    } else if (this.format === 'textile') {
      markdownTable = this.toTextileTable(tableData)
    } else {
      return
    }

    if (!markdownTable) return

    // Insert the table at cursor position
    event.preventDefault()
    this.insertTextAtCursor(markdownTable)
  }

  extractTableFromHtml(html) {
    // Create a temporary element to parse HTML
    const temp = document.createElement('div')
    temp.innerHTML = html

    // Find the first table
    const table = temp.querySelector('table')
    if (!table) return null

    const rows = []
    const tableRows = table.querySelectorAll('tr')

    tableRows.forEach(tr => {
      const cells = []
      tr.querySelectorAll('td, th').forEach(cell => {
        cells.push(cell.textContent.trim())
      })
      if (cells.length > 0) {
        rows.push(cells)
      }
    })

    return rows.length > 0 ? rows : null
  }

  extractTableFromTsv(text) {
    // Check if the text contains tabs (TSV format)
    if (!text.includes('\t')) return null

    const lines = text.trim().split('\n')
    if (lines.length < 1) return null

    const rows = []
    let maxColumns = 0

    lines.forEach(line => {
      const cells = line.split('\t').map(cell => cell.trim())
      rows.push(cells)
      maxColumns = Math.max(maxColumns, cells.length)
    })

    // Must have at least 2 columns to be considered a table
    if (maxColumns < 2) return null

    // Normalize row lengths
    rows.forEach(row => {
      while (row.length < maxColumns) {
        row.push('')
      }
    })

    return rows
  }

  toCommonMarkTable(data) {
    if (!data || data.length === 0) return null

    const rows = []
    
    // Add first row (header)
    rows.push('| ' + data[0].join(' | ') + ' |')
    
    // Add separator row
    const separator = data[0].map(() => '---').join(' | ')
    rows.push('| ' + separator + ' |')
    
    // Add data rows
    for (let i = 1; i < data.length; i++) {
      rows.push('| ' + data[i].join(' | ') + ' |')
    }

    return rows.join('\n')
  }

  toTextileTable(data) {
    if (!data || data.length === 0) return null

    const rows = []
    
    // Add header row with |_. prefix
    rows.push('|_. ' + data[0].join(' |_. ') + ' |')
    
    // Add data rows
    for (let i = 1; i < data.length; i++) {
      rows.push('| ' + data[i].join(' | ') + ' |')
    }

    return rows.join('\n')
  }

  insertTextAtCursor(text) {
    const { selectionStart, selectionEnd, value } = this.input
    
    // Ensure there's a newline before the table if we're not at the start
    let prefix = ''
    if (selectionStart > 0 && value[selectionStart - 1] !== '\n') {
      prefix = '\n'
    }

    // Ensure there's a newline after the table
    let suffix = '\n'

    const newValue = value.slice(0, selectionStart) + prefix + text + suffix + value.slice(selectionEnd)
    this.input.value = newValue

    // Set cursor position after the inserted table
    const newCursorPos = selectionStart + prefix.length + text.length + suffix.length
    this.input.setSelectionRange(newCursorPos, newCursorPos)

    // Trigger input event so other listeners can react
    this.input.dispatchEvent(new Event('input', { bubbles: true }))
  }
}

export default class extends Controller {
  handlePaste(event) {
    const format = event.params.textFormatting
    if (!format) return

    new TablePasteHandler(event.currentTarget, format).run(event)
  }
}
