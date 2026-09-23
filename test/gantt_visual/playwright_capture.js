async (page) => {
  await page.emulateMedia({media: null})
  const control = await page.evaluate(() => ({
    origin: location.origin,
    params: Object.fromEntries(new URLSearchParams(location.search))
  }))
  const outputRoot = control.params.gantt_visual_output
  const dataUrl = control.params.gantt_visual_data
  const label = control.params.gantt_visual_label
  const filter = control.params.gantt_visual_filter
  if (!outputRoot || !dataUrl || !["expected", "actual"].includes(label)) {
    throw new Error("Navigate to a control URL containing gantt_visual_output, gantt_visual_data, and gantt_visual_label")
  }

  const origin = control.origin
  const readJson = async filename => {
    const dataPage = await page.context().newPage()
    try {
      await dataPage.goto(`${dataUrl}/${filename}`)
      return JSON.parse(await dataPage.locator("body").innerText())
    } finally {
      await dataPage.close()
    }
  }
  const saveJson = async (filename, value) => {
    const download = page.waitForEvent("download")
    await page.evaluate(({name, json}) => {
      const link = document.createElement("a")
      link.href = URL.createObjectURL(new Blob([json], {type: "application/json"}))
      link.download = name
      link.click()
      URL.revokeObjectURL(link.href)
    }, {name: filename.split("/").pop(), json: JSON.stringify(value, null, 2)})
    await (await download).saveAs(filename)
  }
  const manifest = await readJson("manifest.json")
  let cases = await readJson("cases.json")
  if (filter) cases = cases.filter(testCase => new RegExp(filter).test(testCase.id))

  const timelineSelector = ".gantt-timeline, #gantt_area"

  const waitUntilStable = async () => {
    await page.locator(timelineSelector).first().waitFor({state: "visible", timeout: 30000})
    await page.evaluate(async () => {
      await document.fonts.ready
      await Promise.all(Array.from(document.images).map(image => image.complete ? Promise.resolve() : new Promise(resolve => {
        image.addEventListener("load", resolve, {once: true})
        image.addEventListener("error", resolve, {once: true})
      })))
      await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(() => requestAnimationFrame(resolve))))
    })
  }

  const snapshot = async () => page.evaluate(() => {
    const nodes = Array.from(document.querySelectorAll(
      '[data-gantt-column="subjects"] .gantt-pane-body > form > .gantt-row, .gantt_subjects > form > div, .gantt_subjects > div'
    ))
    let project = null
    const rows = nodes.map(element => {
      let key = element.dataset.ganttRowKey
      if (!key && element.dataset.collapseExpand) {
        const value = JSON.parse(element.dataset.collapseExpand)
        key = value.obj_id || value
      }
      if (!key) return null
      const [kind, rawId] = String(key).split("-")
      const id = Number(rawId)
      if (kind === "project") project = id
      return {
        kind,
        id,
        project,
        visible: Boolean(element.offsetWidth || element.offsetHeight || element.getClientRects().length),
        top: element.getBoundingClientRect().top
      }
    }).filter(Boolean)
    return {
      rows,
      title: document.title,
      url: location.href,
      warning: Boolean(document.querySelector(".warning")),
      paths: document.querySelectorAll(".gantt-relations path, #gantt_draw_area path").length,
      today: Boolean(document.querySelector(".gantt-today, #today_line")),
      selected: Array.from(document.querySelectorAll('input[name="ids[]"]:checked')).map(element => Number(element.value)),
      menu: Boolean(document.querySelector("#context-menu a.icon-edit")),
      subjectWidth: document.querySelector('[data-gantt-column="subjects"], .gantt_subjects_column')?.getBoundingClientRect().width,
      columnWidth: document.querySelector('.gantt-column:not([data-gantt-column="subjects"]), .gantt_selected_column')?.getBoundingClientRect().width,
      timeline: (() => {
        const element = document.querySelector(".gantt-timeline, #gantt_area")
        return element ? {
          clientWidth: element.clientWidth,
          scrollWidth: element.scrollWidth,
          scrollLeft: element.scrollLeft
        } : null
      })(),
      parentMarkers: (() => {
        const area = document.querySelector(".gantt-timeline, #gantt_area")
        if (!area) return []
        const body = area.querySelector(".gantt-timeline-body")
        const legacyHeader = area.querySelector(":scope > .gantt_hdr")
        const bodyTop = body ? body.getBoundingClientRect().top : legacyHeader.getBoundingClientRect().bottom
        return Array.from(area.querySelectorAll(".gantt-task-parent.gantt-task-marker, .task.parent.marker"))
          .filter(element => element.getClientRects().length)
          .map(element => {
            const row = element.closest(".gantt-row")
            const rowTasks = row ? Array.from(row.querySelectorAll(".gantt-task")) : Array.from(area.querySelectorAll(
              `.task[data-collapse-expand='${element.dataset.collapseExpand}'][data-number-of-rows='${element.dataset.numberOfRows}']`
            ))
            const task = rowTasks.find(candidate => !candidate.classList.contains("marker") && !candidate.classList.contains("gantt-task-marker"))
            const top = Math.round(element.getBoundingClientRect().top - bodyTop)
            const taskTop = task ? Math.round(task.getBoundingClientRect().top - bodyTop) : null
            const rowIndex = row && body ? Array.from(body.querySelectorAll(":scope > form > .gantt-row")).indexOf(row) : -1
            return {
              row: rowIndex >= 0 ? String(rowIndex) : element.dataset.numberOfRows,
              edge: element.classList.contains("gantt-task-start") || element.classList.contains("starting") ? "start" : "end",
              top,
              taskTop,
              taskOffset: taskTop === null ? null : top - taskTop
            }
          })
      })(),
      errors: document.querySelector("#errorExplanation")?.textContent || null
    }
  })

  const captureTimelineEdges = async (directory, name) => {
    const area = page.locator(timelineSelector).first()
    const timeline = await area.evaluate(element => {
      return {
        hasTasks: Array.from(element.querySelectorAll(".gantt-task, .task")).some(task => task.getClientRects().length),
        original: element.scrollLeft,
        scrollable: element.scrollWidth > element.clientWidth + 1
      }
    })
    if (!timeline.scrollable || !timeline.hasTasks) return

    const screenshotAt = async (suffix, position) => {
      await area.evaluate((element, left) => { element.scrollLeft = left }, position)
      await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))))
      await page.screenshot({path: `${directory}/${name}-${suffix}.png`, fullPage: false, animations: "disabled"})
    }
    await screenshotAt("timeline-start", 0)
    await screenshotAt("timeline-end", Number.MAX_SAFE_INTEGER)
    await area.evaluate((element, left) => { element.scrollLeft = left }, timeline.original)
  }

  const capture = async (directory, name, print, printProfiles = false) => {
    await waitUntilStable()
    await page.screenshot({path: `${directory}/${name}.png`, fullPage: false, animations: "disabled"})
    await captureTimelineEdges(directory, name)
    const state = await snapshot()
    await saveJson(`${directory}/${name}.json`, state)
    if (print) {
      // A task tooltip can remain hovered after an interaction and be laid out on
      // a different printed page than its row. Move the pointer outside the
      // chart so print comparisons only contain the chart's persistent content.
      await page.mouse.move(0, 0)
      await page.waitForTimeout(50)
      const defaultOptions = {
        path: `${directory}/${name}-print.pdf`,
        format: "A4",
        landscape: true,
        printBackground: true,
        margin: {top: "0.4in", right: "0.4in", bottom: "0.4in", left: "0.4in"}
      }
      await page.pdf(defaultOptions)
      if (printProfiles) {
        const profiles = [
          ["margin-tight", {margin: {top: "0.25in", right: "0.25in", bottom: "0.25in", left: "0.25in"}}],
          ["margin-wide", {margin: {top: "0.55in", right: "0.55in", bottom: "0.55in", left: "0.55in"}}],
          ["portrait", {landscape: false}],
          ["scale-90", {scale: 0.9}],
          ["scale-110", {scale: 1.1}]
        ]
        for (const [suffix, options] of profiles) {
          await page.pdf({...defaultOptions, ...options, path: `${directory}/${name}-print-${suffix}.pdf`})
        }
      }
    }
    return state
  }

  const setOption = async (id, checked) => {
    const fieldset = page.locator("#options")
    if (await fieldset.getAttribute("class").then(value => value?.includes("collapsed"))) {
      await fieldset.locator(":scope > legend").click()
    }
    const box = page.locator(`#${id}`)
    if ((await box.isChecked()) !== checked) await box.click()
  }

  const perform = async (action, directory) => {
    const before = await snapshot()
    switch (action) {
      case "progress-off": await setOption("draw_progress_line", false); break
      case "progress-on": await setOption("draw_progress_line", true); break
      case "columns-off": await setOption("draw_selected_columns", false); break
      case "columns-on": await setOption("draw_selected_columns", true); break
      case "scroll":
      case "scroll-to-bars":
      case "scroll-to-ends": {
        await page.locator(timelineSelector).first().evaluate((element, operation) => {
          if (operation === "scroll") {
            element.scrollLeft = 250
          } else if (operation === "scroll-to-ends") {
            element.scrollLeft = Number.MAX_SAFE_INTEGER
          } else {
            const task = element.querySelector(".gantt-task, .task")
            element.scrollLeft = task ? Math.max(0, task.offsetLeft - element.clientWidth / 3) : 0
          }
        }, action)
        break
      }
      case "narrow": await page.setViewportSize({width: 1000, height: 1000}); break
      case "resize-subject":
      case "resize-column": {
        const selector = action === "resize-subject"
          ? "[data-gantt-column=subjects] .ui-resizable-e, [data-gantt--column-column-value=subjects] .ui-resizable-e"
          : ".gantt-column:not([data-gantt-column=subjects]) .ui-resizable-e, .gantt_selected_column .ui-resizable-e"
        const handle = page.locator(selector).first()
        const box = await handle.boundingBox()
        if (!box) throw new Error(`${action}: resize handle is not visible`)
        await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2)
        await page.mouse.down()
        await page.mouse.move(box.x + box.width / 2 + 60, box.y + box.height / 2)
        await page.mouse.up()
        break
      }
      case "collapse-project":
      case "expand-project":
        await page.locator('[data-gantt-column="subjects"] .gantt-row[data-gantt-row-type="project"] .expander, .gantt_subjects .project-name .expander').first().click(); break
      case "collapse-version":
      case "expand-version":
        await page.locator('[data-gantt-column="subjects"] .gantt-row[data-gantt-row-type="version"] .expander, .gantt_subjects .version-name .expander').first().click(); break
      case "collapse-parent":
      case "expand-parent":
        await page.locator(`[data-gantt-column="subjects"] .gantt-row[data-gantt-row-key="issue-${manifest.issues.parent}"] .expander, #issue-${manifest.issues.parent} .expander`).click(); break
      case "collapse-first-parent":
        await page.locator('[data-gantt-column="subjects"] .gantt-row[data-gantt-row-type="issue"].is-expanded .expander, .gantt_subjects .issue-subject.open .expander').first().click(); break
      case "next": await page.locator(".pagination .next a").click(); break
      case "previous": await page.locator(".pagination .previous a").click(); break
      case "zoom-in": await page.locator("a.icon-zoom-in").click(); break
      case "reload": await page.reload({waitUntil: "networkidle"}); break
      case "filter-all":
        await page.locator("#operators_status_id").selectOption("*")
        await page.locator("#query_form_with_buttons a.icon-checked").click()
        break
      case "tooltip":
      case "subject-menu":
      case "bar-menu":
      case "multi-select": {
        const id = manifest.issues["basic-open"]
        const subject = page.locator(`[data-gantt-column="subjects"] .gantt-row[data-gantt-row-key="issue-${id}"], #issue-${id}`).first()
        const bar = page.locator(`.gantt-timeline .gantt-row[data-gantt-row-key="issue-${id}"] .tooltip, #gantt_area .tooltip[data-collapse-expand='issue-${id}']`).first()
        await page.locator("h2").click()
        if (action === "tooltip") {
          await bar.hover()
          await bar.locator(".tip").waitFor({state: "visible"})
        } else if (action === "subject-menu" || action === "bar-menu") {
          await (action === "subject-menu" ? subject : bar).click({button: "right"})
          await page.locator("#context-menu a.icon-edit").waitFor({state: "visible"})
        } else {
          const otherId = manifest.issues["basic-long"]
          const other = page.locator(`[data-gantt-column="subjects"] .gantt-row[data-gantt-row-key="issue-${otherId}"], #issue-${otherId}`).first()
          await subject.click()
          await other.click({modifiers: ["ControlOrMeta"]})
        }
        break
      }
      case "print-return":
        await page.pdf({path: `${directory}/print-return-probe.pdf`, format: "A4", landscape: true, printBackground: true})
        break
      default: throw new Error(`Unknown action: ${action}`)
    }
    await waitUntilStable()
    const after = await snapshot()
    if (action.startsWith("collapse-") && after.rows.filter(row => row.visible).length >= before.rows.filter(row => row.visible).length) {
      throw new Error(`${action}: descendants were not hidden`)
    }
    if (action.startsWith("expand-") && !after.rows.every(row => row.visible)) throw new Error(`${action}: descendants were not restored`)
    if (action.startsWith("resize-")) {
      const field = action === "resize-subject" ? "subjectWidth" : "columnWidth"
      if (!(after[field] > before[field])) throw new Error(`${action}: width did not increase`)
    }
    if (action === "multi-select") {
      const expected = [manifest.issues["basic-open"], manifest.issues["basic-long"]].sort((a, b) => a - b)
      const actual = [...new Set(after.selected)].sort((a, b) => a - b)
      if (JSON.stringify(actual) !== JSON.stringify(expected)) throw new Error("multi-select: unexpected selected issues")
    }
  }

  const downloadExport = async (directory, name, format) => {
    const currentUrl = page.url()
    const url = currentUrl.replace(/\/gantt(\?)/, `/gantt.${format}$1`)
    const contentType = format === "pdf" ? "application/pdf" : "image/png"
    const download = page.waitForEvent("download")
    const info = await page.evaluate(async ({href, filename, contentType, format}) => {
      const response = await fetch(href)
      const body = await response.arrayBuffer()
      const link = document.createElement("a")
      link.href = URL.createObjectURL(new Blob([body], {type: contentType}))
      link.download = filename
      link.click()
      URL.revokeObjectURL(link.href)
      const bytes = new Uint8Array(body.slice(0, 8))
      const validHeader = format === "pdf"
        ? new TextDecoder().decode(bytes.slice(0, 5)) === "%PDF-"
        : [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a].every((byte, index) => bytes[index] === byte)
      return {status: response.status, type: response.headers.get("content-type"), bytes: body.byteLength,
        valid_header: validHeader}
    }, {href: url, filename: `${name}.${format}`, contentType, format})
    await (await download).saveAs(`${directory}/${name}.${format}`)
    return {
      ...info,
      url
    }
  }

  const summaries = []
  for (const testCase of cases) {
    const directory = `${outputRoot}/${label}/${testCase.id}`
    const result = {id: testCase.id, states: {}, exports: {}}
    try {
      await page.setViewportSize({width: testCase.viewport[0], height: testCase.viewport[1]})
      await page.context().clearCookies()
      await page.goto(`${origin}/login`, {waitUntil: "networkidle"})
      await page.evaluate(() => { localStorage.clear(); sessionStorage.clear() })
      if (testCase.user !== "anonymous") {
        await page.locator("#username").fill(testCase.user)
        await page.locator("#password").fill("visual-password")
        await page.locator('input[name="login"]').click()
        await page.waitForURL(url => !url.pathname.includes("/login"))
      }
      await page.goto(origin + testCase.path, {waitUntil: "networkidle"})
      const printProfiles = testCase.group === "G17"
      result.states.screen = await capture(directory, "screen", testCase.print, printProfiles)
      const ids = result.states.screen.rows.filter(row => row.kind === "issue").map(row => row.id)
      result.issue_set_matches = JSON.stringify([...ids].sort((a, b) => a - b)) === JSON.stringify([...testCase.expected_issue_ids].sort((a, b) => a - b))
      result.issue_order_matches = !testCase.expected_issue_order || JSON.stringify(ids) === JSON.stringify(testCase.expected_issue_order)
      if (testCase.exports) {
        result.exports["export.pdf"] = await downloadExport(directory, "export", "pdf")
        result.exports["export.png"] = await downloadExport(directory, "export", "png")
      }
      for (const action of testCase.actions) {
        await perform(action, directory)
        result.states[action] = await capture(directory, action, testCase.print, printProfiles)
      }
      if (testCase.group === "G14") {
        result.exports["final-export.pdf"] = await downloadExport(directory, "final-export", "pdf")
        result.exports["final-export.png"] = await downloadExport(directory, "final-export", "png")
      }
    } catch (error) {
      result.error = `${error.name}: ${error.message}`
      await page.screenshot({path: `${directory}/failure.png`, fullPage: false}).catch(() => {})
    }
    await saveJson(`${directory}/result.json`, result)
    summaries.push({id: testCase.id, error: result.error || null, semanticMatch: Boolean(result.issue_set_matches && result.issue_order_matches)})
  }
  return summaries
}
