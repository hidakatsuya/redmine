async (page) => {
  const control = await page.evaluate(() => {
    const url = new URL(new URLSearchParams(location.search).get('back_url') || location.href)
    return {origin: url.origin, params: Object.fromEntries(url.searchParams)}
  })
  const {data: dataUrl, output, run} = control.params
  if (!dataUrl || !output || !run) throw new Error('Expected data, output and run control parameters')
  const response = await page.request.get(`${dataUrl}/resize-manifest.json`)
  const scenarios = await response.json()
  const context = await page.context().browser().newContext({viewport: {width: 1335, height: 1000}, deviceScaleFactor: 1})
  const probe = await context.newPage()
  const results = []
  const stable = () => probe.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))))
  try {
    await probe.goto(`${control.origin}/login`)
    await probe.locator('#username').fill('admin')
    await probe.locator('#password').fill('visual-password')
    await probe.locator('input[name=login]').click()
    await probe.waitForURL(url => !url.pathname.includes('/login'))
    for (const scenario of scenarios) {
      await probe.setViewportSize({width: 1335, height: 1000})
      await probe.goto(control.origin + scenario.path, {waitUntil: 'networkidle'})
      await probe.locator('.gantt-chart').waitFor({state: 'visible'})
      await stable()
      const initial = await probe.evaluate(() => {
        const chart = document.querySelector('.gantt-chart')
        const controller = window.Stimulus.getControllerForElementAndIdentifier(chart, 'gantt--chart')
        if (!controller) throw new Error('Chart controller unavailable')
        const original = controller.handleWindowResize.bind(controller)
        window.resizeBenchmark = {samples: [], paths: Array.from(chart.querySelectorAll('.gantt-relations path'))}
        window.resizeBenchmark.geometry = window.resizeBenchmark.paths.map(path => path.getAttribute('d'))
        controller.handleWindowResize = function(...args) {
          const start = performance.now()
          try { return original(...args) }
          finally { window.resizeBenchmark.samples.push(performance.now() - start) }
        }
        return {
          issueIds: Array.from(chart.querySelectorAll('[data-gantt-column=subjects] .gantt-row[data-gantt-row-type=issue]'), row => Number(row.dataset.ganttRowKey.split('-')[1])).sort((a,b) => a-b),
          rows: chart.querySelectorAll('[data-gantt-column=subjects] .gantt-row').length,
          paths: window.resizeBenchmark.paths.length
        }
      })
      if (JSON.stringify(initial.issueIds) !== JSON.stringify([...scenario.issue_ids].sort((a,b) => a-b))) {
        throw new Error(`${scenario.id}: rendered issue set differs`)
      }
      // Warm the resize path, then measure actual viewport events in both directions.
      for (const width of [1600, 899, 1335]) {
        await probe.setViewportSize({width, height: 1000})
        await stable()
      }
      await probe.evaluate(() => { window.resizeBenchmark.samples = [] })
      const cdp = await context.newCDPSession(probe)
      await cdp.send('Performance.enable')
      const metricsBefore = (await cdp.send('Performance.getMetrics')).metrics
      const widths = Array.from({length: 20}, (_, i) => 1600 - i * 45)
      for (const width of [...widths, ...widths.slice().reverse()]) {
        await probe.setViewportSize({width, height: 1000})
        await stable()
      }
      const metricsAfter = (await cdp.send('Performance.getMetrics')).metrics
      const browserCpuMs = Object.fromEntries(['TaskDuration', 'ScriptDuration', 'LayoutDuration', 'RecalcStyleDuration'].map(name => [
        name, 1000 * (metricsAfter.find(metric => metric.name === name).value - metricsBefore.find(metric => metric.name === name).value)
      ]))
      await cdp.detach()
      const measured = await probe.evaluate(() => {
        const data = window.resizeBenchmark
        const current = Array.from(document.querySelectorAll('.gantt-relations path'))
        return {
          samples: data.samples,
          retainedPaths: data.paths.filter(path => path.isConnected).length,
          coordinatesUnchanged: JSON.stringify(data.geometry) === JSON.stringify(current.map(path => path.getAttribute('d')))
        }
      })
      if (!measured.coordinatesUnchanged || measured.samples.length < 35 || !initial.paths) {
        throw new Error(`${scenario.id}: incomplete resize measurement`)
      }
      results.push({scenario: scenario.id, ...initial, ...measured, browserCpuMs})
    }
    const result = {run, browser: context.browser().version(), samples: 'native viewport resize, synchronous chart handler, milliseconds', results}
    // Saving via the browser keeps the runner usable through Playwright MCP.
    const download = probe.waitForEvent('download')
    await probe.evaluate(({run, result}) => {
      const link = document.createElement('a')
      link.href = URL.createObjectURL(new Blob([JSON.stringify(result, null, 2)], {type: 'application/json'}))
      link.download = `${run}.json`
      link.click()
      URL.revokeObjectURL(link.href)
    }, {run, result})
    await (await download).saveAs(`${output}/${run}.json`)
    return results.map(({issueIds, samples, ...result}) => ({...result, events: samples.length, handlerMs: samples.reduce((a,b) => a+b, 0)}))
  } finally {
    await context.close()
  }
}
