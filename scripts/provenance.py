#!/usr/bin/env python3
"""Content pins, explicit review state, and deterministic bundle sidecars (stdlib only)."""
import argparse
import hashlib
import json
import pathlib
import re
import subprocess
import sys

CANONICAL = ('concepts', 'entities', 'comparisons', 'queries', 'decisions')
LEGACY = 'decisions/choose-explanation-model.md'
TOPICS = {'concepts/congestion-diagnosis.md': 'congestion',
          'concepts/alternative-scoring.md': 'alternatives'}
STATES = {'unverified', 'needs-review', 'reviewed'}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def encoded(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + '\n').encode()


def safe_file(root, path):
    relative = pathlib.PurePosixPath(path)
    if relative.is_absolute() or '..' in relative.parts or not path:
        raise ValueError('unsafe path: ' + path)
    file = root / path
    if not file.is_file() or not file.resolve().is_relative_to(root.resolve()):
        raise ValueError('missing/outside source: ' + path)
    return file


def snapshot(root, path):
    file = safe_file(root, path)
    digest = sha(file.read_bytes())
    result = subprocess.run(['git', '-C', str(root), 'log', '-1', '--format=%H', '--', path],
                            check=True, capture_output=True, text=True)
    revision = result.stdout.strip() or None
    if revision:
        committed = subprocess.run(['git', '-C', str(root), 'show', revision + ':' + path],
                                   capture_output=True, check=True).stdout
        if sha(committed) != digest:
            revision = None  # working bytes do not belong to that revision
    return {'path': path, 'sha256': digest, 'revision': revision}


def frontmatter(text):
    match = re.match(r'^---\n(.*?)\n---\n', text, re.S)
    header = match.group(1) if match else ''
    sources_match = re.search(r'^sources:\s*\n((?:  - .*\n?)*)', header, re.M)
    sources = re.findall(r'^  - (.+)$', sources_match.group(1), re.M) if sources_match else []
    confidence = re.search(r'^confidence: (.+)$', header, re.M)
    contested = re.search(r'^contested: (.+)$', header, re.M)
    return sources, confidence.group(1) if confidence else None, bool(contested and contested.group(1) == 'true')


def inventory(root):
    paths = []
    for directory in CANONICAL:
        paths.extend(p.relative_to(root).as_posix() for p in (root / directory).glob('*.md'))
    paths.extend(p.relative_to(root).as_posix() for p in (root / 'records').rglob('*.json'))
    paths.extend(p.relative_to(root).as_posix() for p in (root / 'packages').glob('*/prompt.md'))
    return sorted(paths)


def document(root, path):
    data = safe_file(root, path).read_bytes()
    text = data.decode()
    if path.split('/')[0] in CANONICAL:
        sources, confidence, contested = frontmatter(text)
        if not sources and path != LEGACY:
            raise ValueError(path + ': canonical page needs raw evidence')
        non_raw = [s for s in sources if not s.startswith('raw/')]
        if non_raw:
            raise ValueError(path + ': non-raw evidence: ' + ', '.join(non_raw))
    elif path.startswith('records/'):
        def walk(value):
            if isinstance(value, dict):
                for key, child in value.items():
                    if key == 'source' and isinstance(child, str):
                        yield child
                    else:
                        yield from walk(child)
            elif isinstance(value, list):
                for child in value:
                    yield from walk(child)
        sources = sorted(set(walk(json.loads(text))))
        if any(not s.startswith('raw/') for s in sources):
            raise ValueError(path + ': record evidence must be raw')
        confidence, contested = None, False
    else:
        sources, confidence, contested = [], None, False  # prompt is an instruction, not evidence
    return {'sha256': sha(data), 'confidence': confidence, 'contested': contested,
            'sources': [snapshot(root, s) for s in sources]}


def refresh(root, previous):
    documents = {}
    old_documents = (previous or {}).get('documents', {})
    for path in inventory(root):
        current = document(root, path)
        old = old_documents.get(path)
        changed = old is not None and any(old.get(k) != current[k] for k in current)
        claims = (old or {}).get('claims') or [{'id': path + '#page', 'scope': 'document',
                                               'status': 'unverified'}]
        claims = json.loads(json.dumps(claims))
        for claim in claims:
            prior = claim.get('sources')
            if changed or (prior is not None and prior != current['sources']):
                claim['status'] = 'needs-review'
                claim.pop('review', None)
            if claim.get('scope') == 'quote':
                quote = claim['quote']
                if claim.get('sha256') is not None and claim['sha256'] != sha(quote.encode()):
                    claim['status'] = 'needs-review'
                    claim.pop('review', None)
                if quote not in safe_file(root, path).read_text():
                    raise ValueError(path + ': claim quote changed; edit selector explicitly: ' + claim['id'])
                claim['sha256'] = sha(quote.encode())
            else:
                claim['sha256'] = current['sha256']
            claim['sources'] = current['sources']
            if path == LEGACY:
                claim['status'] = 'unverified'
                claim.pop('review', None)
                claim['missingEvidence'] = 'No captured experiment output or review approval under raw/experiments.'
            if path in TOPICS:
                claim['topic'] = TOPICS[path]
        current['claims'] = claims
        documents[path] = current
    return {'schemaVersion': 1, 'documents': documents}


def validate(root, contract):
    errors = []
    if contract.get('schemaVersion') != 1:
        errors.append('unsupported schemaVersion')
    documents = contract.get('documents', {})
    if set(inventory(root)) != set(documents):
        errors.append('needs-review: contract inventory differs from files')
    ids = set()
    for path, pinned in documents.items():
        try:
            current = document(root, path)
            if any(pinned.get(k) != value for k, value in current.items()):
                errors.append(path + ': needs-review: document/source bytes or revision changed')
            claims = pinned.get('claims', [])
            if not claims:
                errors.append(path + ': missing claims')
            for claim in claims:
                claim_id = claim.get('id')
                if not claim_id or claim_id in ids:
                    errors.append(path + ': missing/duplicate claim id')
                ids.add(claim_id)
                if claim.get('scope') == 'quote':
                    quote = claim.get('quote', '')
                    if not quote or quote not in safe_file(root, path).read_text() or claim.get('sha256') != sha(quote.encode()):
                        errors.append(path + ': needs-review: quote changed')
                elif claim.get('scope') != 'document' or claim.get('sha256') != current['sha256']:
                    errors.append(path + ': needs-review: claim scope/hash invalid')
                if claim.get('sources') != current['sources']:
                    errors.append(path + ': needs-review: claim/source binding differs')
                if claim.get('status') not in STATES:
                    errors.append(path + ': invalid review state')
                if path == LEGACY and (claim.get('status') != 'unverified' or not claim.get('missingEvidence')):
                    errors.append(path + ': missing experiment must remain unverified')
                if claim.get('status') == 'reviewed':
                    review = claim.get('review', {})
                    if (not current['sources'] or not all(s['revision'] for s in current['sources']) or
                        not review.get('reviewer') or review.get('documentSha256') != current['sha256'] or
                        not re.fullmatch(r'[0-9a-f]{40}', review.get('revision', ''))):
                        errors.append(path + ': reviewed requires raw evidence and explicit review binding')
                    else:
                        reviewed = subprocess.run(['git', '-C', str(root), 'show', review['revision'] + ':' + path],
                                                  capture_output=True)
                        if reviewed.returncode != 0 or sha(reviewed.stdout) != current['sha256']:
                            errors.append(path + ': review revision does not contain the reviewed document')
        except (ValueError, OSError, subprocess.CalledProcessError) as exc:
            errors.append(path + ': ' + str(exc))
    return errors


def metadata(root, service, contract):
    errors = validate(root, contract)
    if errors:
        raise ValueError('\n'.join(errors))
    bundle = subprocess.run([str(root / 'scripts/build-bundle.sh'), service],
                            capture_output=True, check=True).stdout
    paths = re.findall(r'^----- FILE: (.+) -----$', bundle.decode(), re.M)
    return {'schemaVersion': 1, 'service': service, 'bundleSha256': sha(bundle),
            'provenanceSha256': sha(encoded(contract)),
            'documents': [{'path': path, **contract['documents'][path]} for path in paths],
            'inclusionPolicy': 'Full static context; contested/low/unverified/needs-review remain qualified policy context, never verified facts. Backend facts take priority.'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=pathlib.Path, default=pathlib.Path(__file__).resolve().parents[1])
    parser.add_argument('command', choices=['check', 'refresh', 'metadata'])
    parser.add_argument('service', nargs='?')
    args = parser.parse_args()
    root = args.root.resolve()
    file = root / 'indexes/provenance.json'
    previous = json.loads(file.read_text()) if file.exists() else None
    if args.command == 'refresh':
        file.write_bytes(encoded(refresh(root, previous)))
        print('refreshed content pins; changed claims need review', file=sys.stderr)
    elif args.command == 'check':
        errors = validate(root, previous or {})
        if errors:
            raise ValueError('\n'.join(errors))
        print('provenance check passed')
    else:
        if not args.service:
            parser.error('metadata requires service')
        sys.stdout.buffer.write(encoded(metadata(root, args.service, previous or {})))


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as exc:
        print('provenance: ' + str(exc), file=sys.stderr)
        sys.exit(1)
