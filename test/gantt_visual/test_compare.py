"""Exercise the known visibility bug in both comparison directions."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from PIL import Image


class VisibilityComparisonTest(unittest.TestCase):
    def compare(self, before_bug=False, after_bug=False, *, bad_pane=False, changed_screen=False):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            expanded = ['project-1', 'issue-2', 'project-3', 'issue-4']
            correct = ['project-1']
            known = ['project-1', 'project-3', 'issue-4']
            case = {'id': 'G13-hidden-project', 'group': 'G13',
                    'expected_visibility': {'screen': expanded, 'collapse-project': correct, 'expand-project': expanded},
                    'known_visibility_bug': {'collapse-project': known}}
            (root / 'cases.json').write_text(json.dumps([case]))
            (root / 'manifest.json').write_text('{}')
            for label, bug in [('expected', before_bug), ('actual', after_bug)]:
                output = root / label / case['id']
                output.mkdir(parents=True)
                states = {}
                for name, keys in case['expected_visibility'].items():
                    visible = known if name == 'collapse-project' and bug else keys
                    rows = [{'kind': key.split('-')[0], 'id': int(key.split('-')[1]),
                             'project': 1 if key in expanded[:2] else 3, 'visible': key in visible}
                            for key in expanded]
                    panes = [{'pane': pane, 'keys': visible[:]} for pane in ['subjects', 'status', 'timeline']]
                    if bad_pane and label == 'actual' and name == 'collapse-project':
                        panes[-1]['keys'] = known
                    states[name] = {'rows': rows, 'warning': False, 'paths': 0, 'today': True,
                                    'selected': [], 'parentMarkers': [], 'errors': None, 'visibleByPane': panes}
                    color = 'black' if name == 'collapse-project' and bug else 'white'
                    if changed_screen and label == 'actual' and name == 'screen':
                        color = 'red'
                    Image.new('RGB', (2, 2), color).save(output / f'{name}.png')
                result = {'states': states, 'exports': {}, 'issue_set_matches': True, 'issue_order_matches': True}
                (output / 'result.json').write_text(json.dumps(result))
            subprocess.run([sys.executable, str(Path(__file__).with_name('compare.py')), '--root', str(root)],
                           check=True, capture_output=True, text=True)
            return json.loads((root / 'results.json').read_text())[0]

    def test_correct_on_both_sides(self):
        self.assertEqual('identical', self.compare()['status'])

    def test_shared_existing_bug(self):
        self.assertEqual('baseline-limitation', self.compare(True, True)['status'])

    def test_fix_produces_expected_difference(self):
        self.assertEqual('expected-difference', self.compare(True, False)['status'])

    def test_reintroduced_bug_is_failure(self):
        self.assertEqual('failure', self.compare(False, True)['status'])

    def test_mismatched_pane_is_failure(self):
        self.assertEqual('failure', self.compare(True, False, bad_pane=True)['status'])

    def test_unexpected_initial_pixels_are_failure(self):
        self.assertEqual('failure', self.compare(True, False, changed_screen=True)['status'])


if __name__ == '__main__':
    unittest.main()
