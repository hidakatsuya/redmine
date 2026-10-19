const {test} = require('node:test')
const assert = require('node:assert/strict')
const {validateLineGeometry} = require('./line_checks.js')

function fixture() {
  const spec = {date_from: '2026-09-01', pixelsPerDay: 10,
    issues: {a: {id: 1, start: '2026-09-03', due: '2026-09-05', progress: 0, closed: false},
      b: {id: 2, start: '2026-09-08', due: '2026-09-09', progress: 0, closed: false}},
    relations: [{from: 1, to: 2, type: 'blocks'}]}
  const start = {x: 50, y: 15}, tip = {x: 70, y: 45}
  const g = {bodyLeft: 0, todayX: 100, visibleRelations: 3, visibleArrows: 1, visibleProgress: 2,
    tasks: {
      1: {visible: true, bar: {left: 20, right: 50, top: 10, bottom: 20}, row: {top: 10, bottom: 30}, subject: {top: 10}},
      2: {visible: true, bar: {left: 70, right: 90, top: 40, bottom: 50}, row: {top: 40, bottom: 60}, subject: {top: 40}}},
    relations: [{type: 'blocks', start, tip, segments: [
      {start, end: {x: 60, y: 15}}, {start: {x: 60, y: 15}, end: {x: 60, y: 45}}, {start: {x: 60, y: 45}, end: tip}]}],
    progress: [{start: {x: 100, y: 0}, end: {x: 20, y: 16}}, {start: {x: 20, y: 16}, end: {x: 70, y: 46}}]}
  return {g, spec}
}
const audit = ({g, spec}) => validateLineGeometry(g, spec).errors
const rejects = (change, message) => {
  const f = fixture(); change(f)
  assert(audit(f).some(error => error.includes(message)), audit(f).join('\n'))
}
test('correct rows, dates, connected arrows and zero progress pass', () => assert.deepEqual(audit(fixture()), []))
test('border overlap within two pixels passes', () => {
  const f = fixture(); f.g.relations[0].start.x -= 2; f.g.relations[0].start.y -= 1
  assert.deepEqual(audit(f), [])
})
test('different source and target bar heights require the target center', () => {
  const f = fixture(); f.g.tasks[1].bar.bottom = 15; f.g.relations[0].start.y = 12.5
  assert.deepEqual(audit(f), [])
  f.g.relations[0].tip.y = 41.5
  assert(audit(f).some(error => error.includes('arrow misses target bar center')))
})
test('missing relation fails', () => rejects(f => {f.g.relations = []}, 'missing relation'))
test('relation to a hidden row fails', () => rejects(f => {f.g.tasks[2].visible = false}, 'unexpected relation'))
test('missing visible fixture row fails', () => rejects(f => {f.g.tasks[2].visible = false}, 'visibility does not match'))
test('disconnected segments fail', () => rejects(f => {f.g.relations[0].segments[1].start.x += 4}, 'disconnected relation'))
test('wrong task date geometry fails', () => rejects(f => {f.g.tasks[1].bar.left += 5}, 'fixture dates'))
test('wrong progress anchor fails', () => rejects(f => {f.g.progress[1].end.x += 5}, 'progress anchor misses'))
test('progress on another row fails', () => rejects(f => {f.g.progress[1].end.y = 85}, 'another row'))
test('invisible line capture fails', () => rejects(f => {f.g.visibleArrows = 0}, 'capture does not show'))
test('closed issue uses today rather than completion edge', () => {
  const f = fixture(); f.spec.issues.b.closed = true; f.g.progress[1].end.x = 100
  assert.deepEqual(audit(f), [])
})
test('partial progress is checked against fixture percentage', () => {
  const f = fixture(); f.spec.issues.a.progress = 50
  f.g.tasks[1].done = {right: 35}; f.g.progress[0].end.x = 35; f.g.progress[1].start.x = 35
  assert.deepEqual(audit(f), [])
  f.g.tasks[1].done.right = 30; f.g.progress[0].end.x = 30; f.g.progress[1].start.x = 30
  assert(audit(f).some(error => error.includes('fixture progress')))
})
