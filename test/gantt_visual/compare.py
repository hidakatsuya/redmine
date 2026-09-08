"""Rasterize every PDF page and report strict pixel differences, never hide missing output."""
import argparse
import html
import json
import re
import subprocess
from pathlib import Path
from urllib.parse import urlparse, parse_qs
from PIL import Image, ImageChops
from pypdf import PdfReader

parser = argparse.ArgumentParser()
parser.add_argument('--root', type=Path, default=Path('tmp/gantt_visual'))
a = parser.parse_args()
root = a.root
cases = json.loads((root / 'cases.json').read_text())
manifest = json.loads((root / 'manifest.json').read_text())
results = []
for case in cases:
    cid = case['id']
    directories = [root / label / cid for label in ['expected', 'actual']]
    entry = dict(id=cid, failures=[], limitations=[], images=[], pdfs={}, text_checks={})
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
        for pdf in sorted(directory.glob('*.pdf')):
            try:
                reader = PdfReader(pdf)
                pages = len(reader.pages)
                if case['group'] == 'G17':
                    names = re.findall(r'bulk-\d{3}', '\n'.join(p.extract_text() for p in reader.pages))
                    entry['text_checks'].setdefault(label, {})[pdf.name] = names
                entry['pdfs'][label][pdf.name] = pages
                prefix = pdf.with_suffix('')
                if not list(directory.glob(prefix.name + '-page-*.png')) or pdf.stat().st_mtime > min(p.stat().st_mtime for p in directory.glob(prefix.name + '-page-*.png')):
                    for old in directory.glob(prefix.name + '-page-*.png'): old.unlink()
                    subprocess.run(['pdftoppm', '-r', '96', '-png', str(pdf), str(prefix) + '-page'], check=True, capture_output=True)
            except Exception as e:
                entry['failures'].append(f'{label}: {pdf.name}: {e}')
    if len(states) == 2 and all(states):
        if entry['pdfs'].get('expected') != entry['pdfs'].get('actual'):
            entry['failures'].append('PDF page counts differ')
        def logical(state):
            return [(r['kind'], r['id'], r['project'], r['visible']) for r in state['rows']]
        names = set(states[0]['states']) | set(states[1]['states'])
        for name in sorted(names):
            pair = [s['states'].get(name) for s in states]
            if not all(pair): entry['failures'].append(f'{name}: missing state')
            elif logical(pair[0]) != logical(pair[1]): entry['failures'].append(f'{name}: logical rows differ')
            elif pair[0]['warning'] != pair[1]['warning']: entry['failures'].append(f'{name}: truncation warning differs')
            if all(pair):
                if pair[0]['today'] != pair[1]['today']: entry['failures'].append(f'{name}: today line differs')
                if all('selected' in s for s in pair) and sorted(set(pair[0]['selected'])) != sorted(set(pair[1]['selected'])):
                    entry['failures'].append(f'{name}: selection differs')
                if any(s.get('printing') or s.get('errors') for s in pair):
                    entry['failures'].append(f'{name}: print state or page error left behind')
    if case['group'] == 'G17' and all(label in entry['text_checks'] for label in ['expected', 'actual']):
        all_names = {f'bulk-{n:03}' for n in range(100)}
        for pdf in entry['text_checks']['expected']:
            before_names = entry['text_checks']['expected'][pdf]
            after_names = entry['text_checks']['actual'].get(pdf, [])
            if before_names != after_names:
                entry['failures'].append(f'{pdf}: bulk subjects differ')
            missing = sorted(all_names - set(before_names))
            if missing and before_names == after_names:
                entry['limitations'].append(f'{pdf}: both implementations omit subject text {missing}')
            if len(after_names) != len(set(after_names)):
                entry['failures'].append(f'{pdf}: duplicated bulk subjects')
    filenames = sorted(set(p.name for d in directories for p in d.glob('*.png') if p.name != 'failure.png'))
    for name in filenames:
        paths = [d / name for d in directories]
        item = dict(name=name, expected=str(paths[0].relative_to(root)), actual=str(paths[1].relative_to(root)))
        if not all(p.exists() for p in paths):
            item['error'] = 'image missing'
            entry['failures'].append(f'{name}: missing image')
        else:
            try:
                images = [Image.open(p).convert('RGBA') for p in paths]
                item['sizes'] = [im.size for im in images]
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
    entry['status'] = 'failure' if entry['failures'] else 'baseline-limitation' if entry['limitations'] else ('review' if any(i.get('changed_pixels') or i.get('sizes', [0, 0])[0] != i.get('sizes', [0, 0])[1] for i in entry['images']) else 'identical')
    results.append(entry)
(root / 'results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2))
out = ['<!doctype html><meta charset="utf-8"><title>Gantt 回帰テスト</title><style>body{font:14px system-ui;margin:24px}table{border-collapse:collapse}td,th{padding:6px;border:1px solid #ccc}img{max-width:100%}.pair{display:grid;grid-template-columns:repeat(3,1fr);gap:8px}details{margin:12px 0}a{color:#0560af}.failure{color:#b00}.review{color:#875b00}</style><h1>ガント回帰テスト</h1><p>画面・印刷の許容判断は人間の確認待ちです。G17には前後共通の件名欠落があり、成功には含めません。</p><p>画面・エクスポート・印刷を同じ形式の旧実装と比較。差分は閾値なし。ピンク色は変化した画素。画像リンクで原寸表示。</p><p><a href="review.md">評価記録</a> / <a href="environment.json">環境</a> / <a href="cases.json">ケース定義</a></p><table><tr><th>ケース</th><th>状態</th><th>画像数</th><th>完全一致</th></tr>']
labels = {"failure": "失敗", "review": "目視確認待ち", "baseline-limitation": "旧版にも印刷欠落", "identical": "一致"}
for r in results:
    out.append(f'<tr><td><a href="#{r["id"]}">{r["id"]}</a></td><td class="{r["status"]}">{labels[r["status"]]}</td><td>{len(r["images"])}</td><td>{sum(i.get("changed_pixels") == 0 and i["sizes"][0] == i["sizes"][1] for i in r["images"])}</td></tr>')
out.append('</table>')
for r in results:
    out.append(f'<h2 id="{r["id"]}">{r["id"]}</h2><pre>{html.escape(chr(10).join(r["failures"] + r["limitations"]))}</pre>')
    for label in ['expected', 'actual']:
        for pdf, count in r['pdfs'].get(label, {}).items(): out.append(f'<a href="{label}/{r["id"]}/{pdf}">{label}/{pdf} ({count} pages)</a> · ')
    for i in r['images']:
        out.append(f'<details><summary>{html.escape(i["name"])} — {i.get("changed_pixels", "error")} changed pixels ({i.get("ratio", 0):.3%}) {i.get("sizes", "")}</summary><div class="pair">')
        for key in ['expected', 'actual', 'diff']:
            if key in i: out.append(f'<div>{dict(expected="変更前", actual="変更後", diff="差分")[key]}<a href="{i[key]}"><img loading="lazy" src="{i[key]}"></a></div>')
        out.append('</div></details>')
(root / 'report.html').write_text(''.join(out))
for r in results:
    print(r['id'], r['status'], '; '.join(r['failures'])[:250])
