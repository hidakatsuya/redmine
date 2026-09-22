"""Build explicit cases from seed identifiers, never from the Gantt implementation."""
import json
import os
from pathlib import Path
from urllib.parse import urlencode

root = Path(os.environ.get('GANTT_VISUAL_ROOT', 'tmp/gantt_visual'))
m = json.loads((root / 'manifest.json').read_text())
cases = []

def add(id, project='basic', *, year=2026, month=6, months=6, zoom=3,
        user='admin', actions=(), exports=True, columns=False, progress=False,
        limit=None, empty=False, open_only=False, saved=False, title=None):
    names = ['hierarchy', 'child', 'grandchild', 'private'] if project == 'hierarchy' else (
        ['hierarchy', 'shared'] if project == 'shared-both' else [project])
    project_ids = [m['projects'][n] for n in names]
    keys = [k for k, p in m['issue_projects'].items() if p in project_ids]
    if user != 'admin' and not user.startswith('visual-'):
        keys = [k for k in keys if k != 'private-project-task' and (user != 'anonymous' or k != 'basic-private')]
    if open_only:
        keys = [k for k in keys if k not in ['basic-closed', 'closed-version']]
    if empty:
        keys = []
    params = [('year', year), ('month', month), ('months', months), ('zoom', zoom)]
    if saved:
        params += [('query_id', m['queries'][project])]
    else:
        params += [('set_filter', '1'), ('f[]', 'project_id'), ('op[project_id]', '=')]
        params += [('v[project_id][]', str(p)) for p in project_ids]
        if open_only:
            params += [('f[]', 'status_id'), ('op[status_id]', 'o')]
        if empty:
            params += [('f[]', 'issue_id'), ('op[issue_id]', '='), ('v[issue_id][]', '999999')]
        params += [('draw_selected_columns', '1' if columns else '0'), ('draw_progress_line', '1' if progress else '0')]
        params += [('c[]', c) for c in ['subject', 'status', 'priority', 'assigned_to', 'updated_on', f"cf_{m['custom_field']}"]]
    # Independently specified basic row order, including the version after unversioned issues.
    order = ['basic-open', 'basic-closed', 'basic-long', 'basic-private', 'basic-version'] if project == 'basic' else None
    if limit is not None and project == 'basic':
        logical = ['project', 'basic-open', 'basic-closed', 'basic-long', 'basic-private', 'version', 'basic-version']
        keys = [k for k in logical[:limit] if k in m['issues']]
    cases.append(dict(id=id, title=title or id, group=id[:3], project=project, user=user, path='/issues/gantt?' + urlencode(params),
                      expected_issue_ids=[m['issues'][k] for k in keys],
                      expected_issue_order=[m['issues'][k] for k in order if k in keys] if order else None,
                      actions=list(actions), exports=exports, print=id[:3] != 'G19', limit=limit, viewport=[1335, 1000]))

add('G01-basic', open_only=True, title='Basic hierarchy, order, bars, text, borders, and spacing')
for z in [1, 2, 3, 4]:
    add(f'G02-zoom-{z}', zoom=z, actions=['scroll-to-bars', 'scroll-to-ends'] if z == 4 else [],
        title=f'Zoom level {z}: headers, bars, labels, and horizontal scrolling')
add('G03-one-month', 'dates', month=8, months=1, title='One-month date range and boundary placement')
add('G03-year', 'dates', month=12, months=6, title='Date range crossing a year boundary')
add('G03-twelve', 'dates', months=12, zoom=1, title='Twelve-month overview at minimum zoom')
add('G03-leap', 'dates', year=2024, month=2, months=1, zoom=4, title='Leap-year February at maximum zoom')
add('G04-hierarchy', 'hierarchy', title='Nested projects, parent issues, and indentation')
add('G05-shared', 'shared-both', title='Shared versions across projects')
add('G06-missing', 'dates', title='Issues with missing start or due dates')
add('G07-clipped', 'dates', months=1, zoom=4, title='Bars clipped by the visible date range')
add('G08-progress', 'progress', month=8, months=2, zoom=4, title='Progress percentages and completed bar segments')
add('G09-relations', 'shared-both', exports=False, title='Issue relation lines and arrows')
add('G09-filtered', 'shared', exports=False, title='Relation lines when related rows are filtered out')
add('G10-inside', progress=True, actions=['progress-off', 'progress-on'], exports=False,
    title='Progress line inside the displayed date range')
add('G10-before', year=2027, progress=True, exports=False, title='Progress line before the displayed date range')
add('G10-after', year=2025, progress=True, exports=False, title='Progress line after the displayed date range')
add('G11-columns', columns=True, actions=['columns-off', 'columns-on'], exports=False,
    title='Additional columns and visibility toggle')
add('G12-layout', columns=True, actions=['scroll', 'resize-subject', 'resize-column', 'narrow'], exports=False,
    title='Horizontal scrolling, column resizing, and narrow viewport')
add('G13-project', 'hierarchy', actions=['collapse-project', 'expand-project'], exports=False,
    title='Collapse and expand a project row')
add('G13-version', actions=['collapse-version', 'expand-version'], exports=False,
    title='Collapse and expand a version row')
add('G13-parent', 'hierarchy', actions=['collapse-parent', 'expand-parent'], exports=False,
    title='Collapse and expand a parent issue row')
add('G14-saved', saved=True, actions=['next', 'previous', 'zoom-in', 'reload'],
    title='Saved query across navigation, zoom, and reload')
add('G14-filter', open_only=True, actions=['filter-all'], title='Filter change and row-set update')
add('G15-empty', empty=True, title='Empty result set')
for n in [1, 6, 7, 8]:
    add(f'G15-limit-{n}', limit=n, title=f'Row truncation at a limit of {n}')
for user in ['anonymous', 'jsmith', 'admin']:
    add(f'G16-{user}', 'hierarchy', user=user, title=f'Visibility and permissions for {user}')
add('G16-private-issue', user='anonymous', title='Private issue visibility for an anonymous user')
add('G17-pages', 'bulk', zoom=2, title='Multi-page printing with 100 issues')
add('G17-columns', 'bulk', zoom=2, columns=True, title='Multi-page printing with an additional column')
add('G17-collapse', 'bulk', zoom=2, actions=['collapse-first-parent'], title='Multi-page printing after collapsing rows')
add('G18-ja', user='visual-ja', title='Japanese locale and exported text')
add('G18-ar', user='visual-ar', title='Arabic locale and RTL layout')
add('G19-context', actions=['tooltip', 'subject-menu', 'bar-menu', 'multi-select'], exports=False,
    title='Tooltip, context menus, and multi-selection')
add('G20-print-return', actions=['print-return', 'collapse-project', 'expand-project', 'resize-subject'], exports=False,
    title='Return from printing, then collapse, expand, and resize')
(root / 'cases.json').write_text(json.dumps(cases, ensure_ascii=False, indent=2))
for label in ['expected', 'actual']:
    for test_case in cases:
        (root / label / test_case['id']).mkdir(parents=True, exist_ok=True)
print(f'{len(cases)} cases')
