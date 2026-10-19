// Check rendered geometry against fixture relationships and visible task boxes.
// This intentionally does not reproduce the controller's routing algorithm.
function validateLineGeometry(g, spec) {
  const errors = []
  const near = (a, b, tolerance = 2) => Math.hypot(a.x - b.x, a.y - b.y) <= tolerance + 0.01
  const middle = box => (box.top + box.bottom) / 2
  const visible = issue => g.tasks[issue.id]?.visible
  const included = spec.includedIssueIds || Object.values(spec.issues).map(issue => issue.id)
  const byId = Object.fromEntries(Object.values(spec.issues).map(issue => [issue.id, issue]))
  for (const id of included) {
    let parent = byId[id].parent, hidden = false
    while (parent) {
      if (parent === spec.collapsedParent) hidden = true
      parent = byId[parent]?.parent
    }
    if (Boolean(g.tasks[id]?.visible) === hidden) errors.push(`issue ${id}: visibility does not match fixture tree state`)
  }
  const expectedRelations = spec.relations.filter(relation => visible({id: relation.from}) && visible({id: relation.to}))
  const unmatched = [...g.relations]
  const relations = []
  for (const relation of expectedRelations) {
    const from = g.tasks[relation.from], to = g.tasks[relation.to]
    // Identify endpoints by their rows first, so a misplaced center is reported explicitly.
    const index = unmatched.findIndex(line => line.type === relation.type &&
      line.start.y >= from.row.top && line.start.y < from.row.bottom &&
      line.tip.y >= to.row.top && line.tip.y < to.row.bottom)
    if (index < 0) {
      errors.push(`missing relation ${relation.from} -> ${relation.to} (${relation.type})`)
      continue
    }
    const line = unmatched.splice(index, 1)[0]
    const start = {x: from.bar.right, y: middle(from.bar)}
    const tip = {x: to.bar.left, y: middle(to.bar)}
    // Two pixels allow the existing border/stroke overlap, not a row-sized displacement.
    if (Math.abs(line.start.x - start.x) > 2.01 || Math.abs(line.start.y - start.y) > 2.01) {
      errors.push(`relation ${relation.from} -> ${relation.to}: start misses source bar center`)
    }
    if (Math.abs(line.tip.x - tip.x) > 2.01 || Math.abs(line.tip.y - tip.y) > 2.01) {
      errors.push(`relation ${relation.from} -> ${relation.to}: arrow misses target bar center`)
    }
    for (let i = 1; i < line.segments.length; i++) {
      if (!near(line.segments[i - 1].end, line.segments[i].start, 0.1)) errors.push('disconnected relation segments')
    }
    if (!near(line.segments.at(-1).end, line.tip, 0.1)) errors.push('arrow detached from relation')
    relations.push({from: relation.from, to: relation.to, type: relation.type, start: line.start, tip: line.tip, expectedStart: start, expectedTip: tip,
      sourceBarHeight: from.bar.bottom - from.bar.top, targetBarHeight: to.bar.bottom - to.bar.top})
  }
  if (unmatched.length) errors.push(`${unmatched.length} unexpected relation(s), possibly attached to hidden rows`)
  const issues = Object.values(spec.issues).filter(visible).sort((a, b) => g.tasks[a.id].row.top - g.tasks[b.id].row.top)
  if (g.progress.length !== issues.length) errors.push(`progress anchors: ${g.progress.length}, expected ${issues.length}`)
  const anchors = []
  issues.forEach((issue, index) => {
    const task = g.tasks[issue.id], point = g.progress[index]?.end
    if (!point) return
    const durationDays = (Date.parse(issue.due) - Date.parse(issue.start)) / 86400000 + 1
    const expectedDoneX = task.bar.left + Math.floor(durationDays * spec.pixelsPerDay * issue.progress / 100)
    if (issue.progress > 0 && !task.done) errors.push(`issue ${issue.id}: missing completed portion`)
    if (task.done && Math.abs(task.done.right - expectedDoneX) > 2.01) errors.push(`issue ${issue.id}: completed portion does not match fixture progress`)
    const expectedX = issue.closed ? g.todayX : issue.progress > 0 ? expectedDoneX : Math.min(g.todayX, task.bar.left)
    if (Math.abs(point.x - expectedX) > 2.01) errors.push(`issue ${issue.id}: progress anchor misses expected progress/today position`)
    if (point.y < task.row.top || point.y >= task.row.bottom) errors.push(`issue ${issue.id}: progress anchor belongs to another row`)
    if (index && !near(g.progress[index - 1].end, g.progress[index].start, 0.1)) errors.push('disconnected progress line')
    anchors.push({issue: issue.id, point, expectedX})
  })
  if (g.progress.length && Math.abs(g.progress[0].start.x - g.todayX) > 1) errors.push('progress line does not start on today line')
  for (const issue of issues) {
    const task = g.tasks[issue.id]
    if (Math.abs(task.row.top - task.subject.top) > 0.5) errors.push(`issue ${issue.id}: subject and timeline rows misaligned`)
    const days = date => (Date.parse(date) - Date.parse(spec.date_from)) / 86400000
    const expectedLeft = g.bodyLeft + days(issue.start) * spec.pixelsPerDay
    const expectedWidth = (days(issue.due) - days(issue.start) + 1) * spec.pixelsPerDay
    if (Math.abs(task.bar.left - expectedLeft) > 0.5 || Math.abs(task.bar.right - task.bar.left - expectedWidth) > 0.5) {
      errors.push(`issue ${issue.id}: task bar does not match fixture dates`)
    }
  }
  if (!g.visibleRelations || !g.visibleArrows || !g.visibleProgress) errors.push('capture does not show a relation, arrowhead and progress line')
  return {errors, relations, anchors, visibleRelations: g.visibleRelations, visibleArrows: g.visibleArrows,
    visibleProgress: g.visibleProgress, checkedIssues: issues.length}
}

function measureLineGeometry(spec) {
  const rect = element => {
    const r = element.getBoundingClientRect()
    return {left: r.left, right: r.right, top: r.top, bottom: r.bottom}
  }
  const area = document.querySelector('.gantt-timeline'), chart = document.querySelector('.gantt-chart')
  const a = rect(area), c = rect(chart)
  const clip = {left: Math.max(a.left, c.left, 0), right: Math.min(a.right, c.right, innerWidth),
    top: Math.max(a.top, 0), bottom: Math.min(a.bottom, innerHeight)}
  const inView = path => {
    const r = rect(path)
    return r.right + 1 > clip.left && r.left - 1 < clip.right && r.bottom + 1 > clip.top && r.top - 1 < clip.bottom
  }
  const point = (path, distance) => {
    const p = path.getPointAtLength(distance)
    const screen = new DOMPoint(p.x, p.y).matrixTransform(path.getScreenCTM())
    return {x: screen.x, y: screen.y}
  }
  const tasks = {}
  for (const issue of Object.values(spec.issues)) {
    const row = area.querySelector(`.gantt-row[data-gantt-row-key="issue-${issue.id}"]`)
    const subject = document.querySelector(`[data-gantt-column=subjects] .gantt-row[data-gantt-row-key="issue-${issue.id}"]`)
    if (!row || !subject || !row.getClientRects().length) { tasks[issue.id] = {visible: false}; continue }
    const bar = row.querySelector('.gantt-task-todo'), done = row.querySelector('.gantt-task-done')
    tasks[issue.id] = {visible: true, row: rect(row), subject: rect(subject), bar: rect(bar), done: done ? rect(done) : null}
  }
  const relations = [], progress = []
  let segments = []
  let visibleRelations = 0, visibleArrows = 0, visibleProgress = 0
  for (const path of area.querySelectorAll('.gantt-relations path')) {
    const color = getComputedStyle(path).stroke, fill = getComputedStyle(path).fill
    const segment = {start: point(path, 0), end: point(path, path.getTotalLength())}
    if (color === 'rgb(255, 0, 0)') {
      progress.push(segment)
      if (inView(path)) visibleProgress++
    } else if (path.getAttribute('fill') === 'none') {
      segments.push(segment)
      if (inView(path)) visibleRelations++
    } else {
      const type = fill === 'rgb(250, 82, 82)' ? 'blocks' : fill === 'rgb(34, 139, 230)' ? 'precedes' : 'unknown'
      relations.push({type, start: segments[0]?.start || segment.start, tip: segment.start, segments})
      segments = []
      if (inView(path)) visibleArrows++
    }
  }
  return {tasks, relations, progress, todayX: rect(area.querySelector('.gantt-today')).left,
    bodyLeft: rect(area.querySelector('.gantt-timeline-body')).left, visibleRelations, visibleArrows, visibleProgress}
}

if (typeof module !== 'undefined') module.exports = {validateLineGeometry}
else window.ganttLineAudit = spec => validateLineGeometry(measureLineGeometry(spec), spec)
