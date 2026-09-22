"""Rasterize every PDF page and report strict pixel differences, never hide missing output."""
import argparse
import html
import json
import re
from pathlib import Path
from urllib.parse import urlparse, parse_qs
from PIL import Image, ImageChops
from pypdf import PdfReader

parser = argparse.ArgumentParser()
parser.add_argument('--root', type=Path, default=Path('tmp/gantt_visual'))
parser.add_argument('--filter', type=re.compile)
a = parser.parse_args()
root = a.root
cases = json.loads((root / 'cases.json').read_text())
if a.filter:
    cases = [case for case in cases if a.filter.search(case['id'])]
manifest = json.loads((root / 'manifest.json').read_text())
results = []
for case in cases:
    cid = case['id']
    directories = [root / label / cid for label in ['expected', 'actual']]
    entry = dict(id=cid, failures=[], limitations=[], images=[], pdfs={}, pdf_geometry={}, text_checks={}, print_pages={})
    states = []
    for label, directory in zip(['expected', 'actual'], directories):
        resultfile = directory / 'result.json'
        if not resultfile.exists():
            entry['failures'].append(f'{label}: capture missing')
            states.append({})
            continue
        state = json.loads(resultfile.read_text())
        states.append(state)
        for name in ['issue_set_matches', 'issue_order_matches']:
            if not state.get(name): entry['failures'].append(f'{label}: {name}')
        if state.get('error'): entry['failures'].append(f"{label}: {state['error']}")
        if cid == 'G14-saved':
            for step, month, zoom in [('next', 12, 3), ('previous', 6, 3), ('zoom-in', 6, 4), ('reload', 6, 4)]:
                query = parse_qs(urlparse(state['states'].get(step, {}).get('url', '')).query)
                expected_query = {'year': '2026', 'month': str(month), 'zoom': str(zoom), 'query_id': str(manifest['queries']['basic'])}
                if any(query.get(k) != [v] for k, v in expected_query.items()):
                    entry['failures'].append(f'{label}: {step}: query not preserved')
        if cid == 'G14-filter':
            after_ids = {r['id'] for r in state['states'].get('filter-all', {}).get('rows', []) if r['kind'] == 'issue'}
            expected_ids = {manifest['issues'][k] for k in ['basic-open', 'basic-closed', 'basic-long', 'basic-private', 'basic-version']}
            if after_ids != expected_ids: entry['failures'].append(f'{label}: filter did not reveal all issues')
        for filename, info in state['exports'].items():
            fmt = filename.split('.')[-1]
            if info.get('valid_header') is False or info['status'] != 200 or info['type'] != f"{'application' if fmt == 'pdf' else 'image'}/{fmt}":
                entry['failures'].append(f'{label}: export {fmt}: {info}')
        entry['pdfs'][label] = {}
        entry['pdf_geometry'][label] = {}
        for pdf in sorted(directory.glob('*.pdf')):
            try:
                reader = PdfReader(pdf)
                pages = len(reader.pages)
                entry['pdf_geometry'][label][pdf.name] = [
                    [float(page.mediabox.width), float(page.mediabox.height)] for page in reader.pages
                ]
                extracted_text = '\n'.join(p.extract_text() for p in reader.pages)
                if case['group'] == 'G17':
                    names = re.findall(r'bulk-\d{3}', extracted_text)
                    entry['text_checks'].setdefault(label, {})[pdf.name] = names
                    if label == 'actual' and '-print' in pdf.name:
                        print_state = pdf.name.split('-print', 1)[0]
                        visible_issues = sum(
                            row['kind'] == 'issue' and row['visible']
                            for row in state['states'].get(print_state, {}).get('rows', [])
                        )
                        if len(names) != len(set(names)):
                            entry['failures'].append(f'{label}: {pdf.name}: duplicated bulk subjects')
                        if len(set(names)) != visible_issues:
                            entry['failures'].append(
                                f'{label}: {pdf.name}: contains {len(set(names))}/{visible_issues} visible bulk subjects'
                            )
                        for page_number, page in enumerate(reader.pages, start=1):
                            page_text = page.extract_text() or ''
                            subject_count = len(re.findall(r'bulk-\d{3}', page_text))
                            label_count = len(re.findall(r'New \d+%', page_text))
                            entry['print_pages'].setdefault(pdf.name, []).append({
                                'page': page_number,
                                'subjects': subject_count,
                                'bar_labels': label_count
                            })
                            if cid == 'G17-columns':
                                selected_column_values = len(re.findall(r'\bNormal\b', page_text))
                                if selected_column_values != subject_count:
                                    entry['failures'].append(
                                        f'{label}: {pdf.name}: page {page_number} contains '
                                        f'{subject_count} subjects and {selected_column_values} priority values'
                                    )
                if cid == 'G17-columns' and label == 'actual' and pdf.name.endswith('-print.pdf'):
                    selected_column_values = len(re.findall(r'\bNormal\b', extracted_text))
                    if selected_column_values != 100:
                        entry['failures'].append(
                            f'{label}: {pdf.name}: selected column contains {selected_column_values}/100 priority values'
                        )
                if cid == 'G18-ja' and pdf.name in {'export.pdf', 'final-export.pdf'}:
                    entry['text_checks'].setdefault(label, {})[pdf.name] = {'japanese': '日本語' in extracted_text}
                    if '日本語' not in extracted_text:
                        entry['failures'].append(f'{label}: {pdf.name}: Japanese text missing')
                if cid == 'G18-ar' and pdf.name.endswith('-print.pdf'):
                    entry['text_checks'].setdefault(label, {})[pdf.name] = {
                        'rtl_subjects': 'basic-open: visual regression' in extracted_text
                    }
                entry['pdfs'][label][pdf.name] = pages
                prefix = pdf.with_suffix('')
                rendered_pages = list(directory.glob(prefix.name + '-page-*.png'))
                if not rendered_pages or pdf.stat().st_mtime > min(page.stat().st_mtime for page in rendered_pages):
                    raise RuntimeError('PDF pages are missing or stale; run rasterize_pdfs.rb in Redmined first')
            except Exception as e:
                entry['failures'].append(f'{label}: {pdf.name}: {e}')
    if len(states) == 2 and all(states):
        expected_pdfs = entry['pdfs'].get('expected', {})
        actual_pdfs = entry['pdfs'].get('actual', {})
        for pdf in sorted(set(expected_pdfs) | set(actual_pdfs)):
            if pdf not in expected_pdfs or pdf not in actual_pdfs:
                entry['failures'].append(f'{pdf}: PDF missing')
                continue
            g17_chrome_print = case['group'] == 'G17' and '-print' in pdf
            if expected_pdfs[pdf] != actual_pdfs[pdf] and not g17_chrome_print:
                entry['failures'].append(f'{pdf}: PDF page counts differ')
            expected_geometry = entry['pdf_geometry']['expected'][pdf]
            actual_geometry = entry['pdf_geometry']['actual'][pdf]
            if g17_chrome_print:
                if len(set(map(tuple, expected_geometry + actual_geometry))) != 1:
                    entry['failures'].append(f'{pdf}: PDF page geometry differs')
            elif expected_geometry != actual_geometry:
                entry['failures'].append(f'{pdf}: PDF page geometry differs')
        def logical(state):
            return [(r['kind'], r['id'], r['project'], r['visible']) for r in state['rows']]
        names = set(states[0]['states']) | set(states[1]['states'])
        for name in sorted(names):
            pair = [s['states'].get(name) for s in states]
            if not all(pair): entry['failures'].append(f'{name}: missing state')
            elif logical(pair[0]) != logical(pair[1]): entry['failures'].append(f'{name}: logical rows differ')
            elif pair[0]['warning'] != pair[1]['warning']: entry['failures'].append(f'{name}: truncation warning differs')
            if all(pair):
                if pair[0]['paths'] != pair[1]['paths']: entry['failures'].append(f'{name}: relation path count differs')
                if pair[0]['today'] != pair[1]['today']: entry['failures'].append(f'{name}: today line differs')
                if all('selected' in s for s in pair) and sorted(set(pair[0]['selected'])) != sorted(set(pair[1]['selected'])):
                    entry['failures'].append(f'{name}: selection differs')
                if all('parentMarkers' in s for s in pair):
                    markers = [[
                        (marker['row'], marker['edge'], marker.get('taskOffset'))
                        for marker in state['parentMarkers'] if marker['top'] >= 0
                    ] for state in pair]
                    if markers[0] != markers[1]:
                        entry['failures'].append(f'{name}: parent marker alignment differs: {markers[0]} -> {markers[1]}')
                if any(s.get('printing') or s.get('errors') for s in pair):
                    entry['failures'].append(f'{name}: print state or page error left behind')
    if cid in {'G17-pages', 'G17-columns'} and all(label in entry['text_checks'] for label in ['expected', 'actual']):
        all_names = {f'bulk-{n:03}' for n in range(100)}
        for pdf in entry['text_checks']['expected']:
            before_names = entry['text_checks']['expected'][pdf]
            after_names = entry['text_checks']['actual'].get(pdf, [])
            missing_before = sorted(all_names - set(before_names))
            missing_after = sorted(all_names - set(after_names))
            if missing_before:
                entry['limitations'].append(f'{pdf}: baseline omits subject text {missing_before}')
            if missing_after:
                entry['failures'].append(f'{pdf}: candidate omits subject text {missing_after}')
    if cid == 'G18-ar' and all(label in entry['text_checks'] for label in ['expected', 'actual']):
        for pdf, expected_check in entry['text_checks']['expected'].items():
            actual_check = entry['text_checks']['actual'].get(pdf, {})
            if expected_check.get('rtl_subjects') and not actual_check.get('rtl_subjects'):
                entry['failures'].append(f'{pdf}: candidate omits the RTL subject pane')
            elif not expected_check.get('rtl_subjects') and not actual_check.get('rtl_subjects'):
                entry['limitations'].append(f'{pdf}: baseline and candidate omit the RTL subject pane in Chrome print')
    filenames = sorted(set(p.name for d in directories for p in d.glob('*.png') if p.name != 'failure.png'))
    for name in filenames:
        paths = [d / name for d in directories]
        item = dict(name=name, expected=str(paths[0].relative_to(root)), actual=str(paths[1].relative_to(root)))
        if not all(p.exists() for p in paths):
            page = re.fullmatch(r'(.+-print(?:-.+)?)-page-(\d+)\.png', name)
            baseline_extra_page = (
                case['group'] == 'G17' and page and paths[0].exists() and
                int(page.group(2)) > entry['pdfs'].get('actual', {}).get(f'{page.group(1)}.pdf', 0)
            )
            if baseline_extra_page:
                item['baseline_only'] = True
                item.pop('actual')
            else:
                item['error'] = 'image missing'
                entry['failures'].append(f'{name}: missing image')
        else:
            try:
                images = [Image.open(p).convert('RGBA') for p in paths]
                item['sizes'] = [im.size for im in images]
                item['content_boxes'] = [ImageChops.difference(im, Image.new('RGBA', im.size, 'white')).getbbox() for im in images]
                size = (max(im.width for im in images), max(im.height for im in images))
                canvases = []
                for im in images:
                    c = Image.new('RGBA', size, 'white'); c.paste(im, (0, 0)); canvases.append(c)
                diff = ImageChops.difference(*canvases)
                channels = diff.split()
                mask = channels[0]
                for channel in channels[1:]: mask = ImageChops.lighter(mask, channel)
                mask = mask.point(lambda p: 255 if p else 0)
                changed = mask.histogram()[255]
                item['changed_pixels'] = changed
                item['ratio'] = changed / (size[0] * size[1])
                diffpath = root / 'diff' / cid / name
                diffpath.parent.mkdir(parents=True, exist_ok=True)
                highlighted = Image.blend(canvases[0], Image.new('RGBA', size, 'white'), .65)
                highlighted.paste((255, 0, 100), mask=mask)
                highlighted.save(diffpath)
                item['diff'] = str(diffpath.relative_to(root))
            except Exception as e:
                item['error'] = str(e); entry['failures'].append(f'{name}: {e}')
        entry['images'].append(item)
    if cid == 'G01-basic':
        item = next((image for image in entry['images'] if image['name'] == 'screen-print-page-1.png'), None)
        if item and 'error' not in item:
            heights = []
            for path in [directories[0] / item['name'], directories[1] / item['name']]:
                image = Image.open(path).convert('RGB')
                crop = image.crop((0, 0, image.width, min(700, image.height)))
                box = ImageChops.difference(crop, Image.new('RGB', crop.size, 'white')).getbbox()
                heights.append(box[3] - box[1] if box else 0)
            ratio = heights[1] / heights[0] if heights[0] else 0
            entry['print_layout'] = {'content_heights': heights, 'ratio': ratio}
            if not 0.95 <= ratio <= 1.05:
                entry['failures'].append(f'Chrome print chart height differs: {heights[0]}px -> {heights[1]}px ({ratio:.2f}x)')
    entry['status'] = 'failure' if entry['failures'] else 'baseline-limitation' if entry['limitations'] else ('review' if any(i.get('changed_pixels') or i.get('sizes', [0, 0])[0] != i.get('sizes', [0, 0])[1] for i in entry['images']) else 'identical')
    results.append(entry)
(root / 'results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2))
metadata_path = root / 'run-metadata.json'
metadata = json.loads(metadata_path.read_text()) if metadata_path.exists() else {}
metadata_items = ''.join(
    f'<li><strong>{html.escape(str(key))}:</strong> {html.escape(str(value))}</li>'
    for key, value in metadata.items()
)
out = ['<!doctype html><meta charset="utf-8"><title>Gantt visual regression report</title><style>body{font:14px system-ui;margin:24px}table{border-collapse:collapse}td,th{padding:6px;border:1px solid #ccc}img{max-width:100%}.pair{display:grid;grid-template-columns:repeat(3,1fr);gap:8px}details{margin:12px 0}a{color:#0560af}.failure{color:#b00}.review{color:#875b00}</style><h1>Gantt visual regression report</h1>']
if metadata_items:
    out.append(f'<h2>Test environment</h2><ul>{metadata_items}</ul>')
out.append('<h2>Case summary</h2><table><tr><th>Case and coverage</th><th>Images</th><th>Pixel-identical images</th></tr>')
case_titles = {case['id']: case.get('title', case['id']) for case in cases}
case_labels = {case_id: case_id if title == case_id else f'{case_id}: {title}' for case_id, title in case_titles.items()}
for r in results:
    out.append(f'<tr><td><a href="#{r["id"]}">{html.escape(case_labels[r["id"]])}</a></td><td>{len(r["images"])}</td><td>{sum(i.get("changed_pixels") == 0 and i["sizes"][0] == i["sizes"][1] for i in r["images"])}</td></tr>')
out.append('</table>')
for r in results:
    out.append(f'<h2 id="{r["id"]}">{html.escape(case_labels[r["id"]])}</h2><pre>{html.escape(chr(10).join(r["failures"] + r["limitations"]))}</pre>')
    for label in ['expected', 'actual']:
        for pdf, count in r['pdfs'].get(label, {}).items(): out.append(f'<a href="{label}/{r["id"]}/{pdf}">{label}/{pdf} ({count} pages)</a> · ')
    for i in r['images']:
        out.append(f'<details><summary>{html.escape(i["name"])} — {i.get("changed_pixels", "error")} changed pixels ({i.get("ratio", 0):.3%}) size={i.get("sizes", "")} content={i.get("content_boxes", "")}</summary><div class="pair">')
        for key in ['expected', 'actual', 'diff']:
            if key in i: out.append(f'<div>{dict(expected="Baseline", actual="Candidate", diff="Difference")[key]}<a href="{i[key]}"><img loading="lazy" src="{i[key]}"></a></div>')
        out.append('</div></details>')
(root / 'report.html').write_text(''.join(out))
for r in results:
    print(r['id'], r['status'], '; '.join(r['failures'])[:250])
