"""Build explicit cases from seed identifiers, never from the Gantt implementation."""
import json
from pathlib import Path
from urllib.parse import urlencode

root = Path('tmp/gantt_visual')
m = json.loads((root / 'manifest.json').read_text())
cases = []

def add(id, project='basic', *, year=2026, month=6, months=6, zoom=3,
        user='admin', actions=(), exports=True, columns=False, progress=False,
        limit=None, empty=False, open_only=False, saved=False):
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
    cases.append(dict(id=id, group=id[:3], project=project, user=user, path='/issues/gantt?' + urlencode(params),
                      expected_issue_ids=[m['issues'][k] for k in keys],
                      expected_issue_order=[m['issues'][k] for k in order if k in keys] if order else None,
                      actions=list(actions), exports=exports, print=id[:3] != 'G19', limit=limit, viewport=[1335, 1000]))

add('G01-basic', open_only=True)
for z in [1, 2, 3, 4]:
    add(f'G02-zoom-{z}', zoom=z, actions=['scroll-to-bars', 'scroll-to-ends'] if z == 4 else [])
add('G03-one-month', 'dates', month=8, months=1)
add('G03-year', 'dates', month=12, months=6)
add('G03-twelve', 'dates', months=12, zoom=1)
add('G03-leap', 'dates', year=2024, month=2, months=1, zoom=4)
add('G04-hierarchy', 'hierarchy')
add('G05-shared', 'shared-both')
add('G06-missing', 'dates')
add('G07-clipped', 'dates', months=1, zoom=4)
add('G08-progress', 'progress', month=8, months=2, zoom=4)
add('G09-relations', 'shared-both', exports=False)
add('G09-filtered', 'shared', exports=False)
add('G10-inside', progress=True, actions=['progress-off', 'progress-on'], exports=False)
add('G10-before', year=2027, progress=True, exports=False)
add('G10-after', year=2025, progress=True, exports=False)
add('G11-columns', columns=True, actions=['columns-off', 'columns-on'], exports=False)
add('G12-layout', columns=True, actions=['scroll', 'resize-subject', 'resize-column', 'narrow'], exports=False)
add('G13-project', 'hierarchy', actions=['collapse-project', 'expand-project'], exports=False)
add('G13-version', actions=['collapse-version', 'expand-version'], exports=False)
add('G13-parent', 'hierarchy', actions=['collapse-parent', 'expand-parent'], exports=False)
add('G14-saved', saved=True, actions=['next', 'previous', 'zoom-in', 'reload'])
add('G14-filter', open_only=True, actions=['filter-all'])
add('G15-empty', empty=True)
for n in [1, 6, 7, 8]: add(f'G15-limit-{n}', limit=n)
for user in ['anonymous', 'jsmith', 'admin']: add(f'G16-{user}', 'hierarchy', user=user)
add('G16-private-issue', user='anonymous')
add('G17-pages', 'bulk', zoom=2)
for lang in ['ja', 'ar']: add(f'G18-{lang}', user=f'visual-{lang}')
add('G19-context', actions=['tooltip', 'subject-menu', 'bar-menu', 'multi-select'], exports=False)
add('G20-print-return', actions=['print-return', 'collapse-project', 'expand-project', 'resize-subject'], exports=False)
add('G21-column-boundaries', columns=True, zoom=4, actions=['resize-subject', 'resize-subject-body', 'resize-subject-bottom', 'resize-column', 'resize-column-body', 'resize-column-bottom', 'scroll', 'columns-off', 'columns-on', 'print-return', 'narrow'])
(root / 'cases.json').write_text(json.dumps(cases, ensure_ascii=False, indent=2))
print(f'{len(cases)} cases')
