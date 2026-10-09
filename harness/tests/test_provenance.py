import importlib.util
import json
import pathlib
import subprocess
import shutil
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).resolve().parents[2] / 'scripts/provenance.py'
spec = importlib.util.spec_from_file_location('provenance', SCRIPT)
p = importlib.util.module_from_spec(spec)
spec.loader.exec_module(p)


class ProvenanceTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name)
        for directory in ['raw', 'concepts', 'records', 'packages/test', 'indexes']:
            (self.root / directory).mkdir(parents=True)
        (self.root / 'raw/evidence.txt').write_text('captured original\n')
        (self.root / 'concepts/policy.md').write_text(
            '---\nsources:\n  - raw/evidence.txt\nconfidence: low\ncontested: true\n---\n\nA claim.\n')
        (self.root / 'packages/test/prompt.md').write_text('Explain only.\n')
        (self.root / 'packages/test/context-bundle.json').write_text(
            '{"canonicalContext":["concepts/policy.md"],"recordContext":[]}\n')
        subprocess.run(['git', 'init', '-q', str(self.root)], check=True)
        subprocess.run(['git', '-C', str(self.root), 'add', '.'], check=True)
        subprocess.run(['git', '-C', str(self.root), '-c', 'user.name=Test', '-c',
                        'user.email=test@example.invalid', 'commit', '-qm', 'fixture'], check=True)
        self.contract = p.refresh(self.root, None)
        (self.root / 'scripts').mkdir()
        for name in ['build-bundle.sh', 'provenance.py']:
            shutil.copy2(SCRIPT.parent / name, self.root / 'scripts' / name)
        (self.root / 'indexes/provenance.json').write_bytes(p.encoded(self.contract))

    def tearDown(self):
        self.tmp.cleanup()

    def test_baseline_is_unverified_and_pinned(self):
        self.assertEqual([], p.validate(self.root, self.contract))
        claim = self.contract['documents']['concepts/policy.md']['claims'][0]
        fixture = json.loads((SCRIPT.parent.parent / 'harness/fixtures/source-version.valid.json').read_text())
        self.assertEqual(fixture['status'], claim['status'])
        self.assertEqual(40, len(claim['sources'][0]['revision']))
        self.assertEqual('low', self.contract['documents']['concepts/policy.md']['confidence'])

    def test_source_change_fails_then_refresh_requires_review(self):
        (self.root / 'raw/evidence.txt').write_text('different\n')
        self.assertTrue(any('needs-review' in e for e in p.validate(self.root, self.contract)))
        refreshed = p.refresh(self.root, self.contract)
        self.assertEqual('needs-review', refreshed['documents']['concepts/policy.md']['claims'][0]['status'])
        self.assertEqual([], p.validate(self.root, refreshed))

    def test_claim_change_cannot_reuse_review(self):
        (self.root / 'concepts/policy.md').write_text(
            (self.root / 'concepts/policy.md').read_text() + 'Another claim.\n')
        self.assertTrue(p.validate(self.root, self.contract))
        self.assertEqual('needs-review', p.refresh(self.root, self.contract)['documents']['concepts/policy.md']['claims'][0]['status'])

    def test_non_raw_is_rejected_and_review_is_not_invented(self):
        (self.root / 'concepts/policy.md').write_text(
            '---\nsources:\n  - packages/test/prompt.md\nconfidence: medium\ncontested: false\n---\nA claim.\n')
        with self.assertRaises(ValueError):
            p.refresh(self.root, self.contract)
        self.contract['documents']['concepts/policy.md']['claims'][0]['status'] = 'reviewed'
        self.assertTrue(p.validate(self.root, self.contract))

    def test_metadata_is_deterministic_and_complete(self):
        a = p.metadata(self.root, 'test', self.contract)
        b = p.metadata(self.root, 'test', self.contract)
        self.assertEqual(a, b)
        self.assertEqual(64, len(a['bundleSha256']))
        self.assertEqual(2, len(a['documents']))
        self.assertEqual('unverified', a['documents'][0]['claims'][0]['status'])

    def test_path_escape_and_missing_source_rejected(self):
        for path in ['../outside', '/etc/passwd', 'raw/missing']:
            with self.assertRaises(ValueError):
                p.snapshot(self.root, path)

    def test_review_revision_must_exist_and_bind_the_document(self):
        claim = self.contract['documents']['concepts/policy.md']['claims'][0]
        claim['status'] = 'reviewed'
        claim['review'] = {'reviewer': 'Fixture only', 'revision': '0' * 40,
                           'documentSha256': self.contract['documents']['concepts/policy.md']['sha256']}
        self.assertTrue(any('review revision' in e for e in p.validate(self.root, self.contract)))

    def test_refresh_does_not_promote_missing_raw_to_reviewed(self):
        (self.root / 'decisions').mkdir()
        (self.root / p.LEGACY).write_text('---\nsources: []\nconfidence: low\ncontested: false\n---\nOld numbers.\n')
        contract = p.refresh(self.root, self.contract)
        claim = contract['documents'][p.LEGACY]['claims'][0]
        self.assertEqual('unverified', claim['status'])
        self.assertTrue(claim['missingEvidence'])
        claim['status'] = 'reviewed'
        self.assertTrue(p.validate(self.root, contract))
