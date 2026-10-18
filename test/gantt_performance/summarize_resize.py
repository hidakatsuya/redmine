import argparse
import hashlib
import json
from pathlib import Path
from statistics import mean, median

parser = argparse.ArgumentParser()
parser.add_argument('--root', type=Path, required=True)
root = parser.parse_args().root
runs = [json.loads((root / f'{name}.json').read_text()) for name in ['before-1', 'after-1', 'after-2', 'before-2']]
rows = []
for scenario in runs[0]['results']:
    name = scenario['scenario']
    row = {'scenario': name, 'rows': scenario['rows'], 'paths': scenario['paths']}
    for label in ['before', 'after']:
        results = [next(item for item in run['results'] if item['scenario'] == name) for run in runs if run['run'].startswith(label)]
        assert all(item['issueIds'] == scenario['issueIds'] and item['coordinatesUnchanged'] for item in results)
        assert all(len(item['samples']) == 39 and item['paths'] == scenario['paths'] for item in results)
        samples = [sample for item in results for sample in item['samples']]
        row[label] = {
            'events': len(samples), 'mean_ms': mean(samples), 'median_ms': median(samples),
            'p95_ms': sorted(samples)[int(.95 * (len(samples) - 1))],
            'round_means_ms': [mean(item['samples']) for item in results],
            'browser_task_ms_per_event': sum(item['browserCpuMs']['TaskDuration'] for item in results) / len(samples),
            'browser_script_ms_per_event': sum(item['browserCpuMs']['ScriptDuration'] for item in results) / len(samples),
            'retained_paths': [item['retainedPaths'] for item in results]
        }
    row['handler_reduction_percent'] = 100 * (1 - row['after']['mean_ms'] / row['before']['mean_ms'])
    row['task_reduction_percent'] = 100 * (1 - row['after']['browser_task_ms_per_event'] / row['before']['browser_task_ms_per_event'])
    row['issue_ids_sha256'] = hashlib.sha256(json.dumps(scenario['issueIds'], separators=(',', ':')).encode()).hexdigest()
    rows.append(row)
summary = {'browser': runs[0]['browser'], 'order': [run['run'] for run in runs], 'scenarios': rows}
(root / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
print(json.dumps(summary, indent=2))
