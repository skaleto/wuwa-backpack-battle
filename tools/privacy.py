#!/usr/bin/env python3
"""Fail publication on private paths or credential payloads. Never print matched values."""
import argparse
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RULES = {
    'private-agent-output': re.compile(rb'exec-[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}', re.I),
    'personal-home-path': re.compile(rb'(?:/Users/|/home/)[A-Za-z0-9_.-]+/|[A-Za-z]:[\\/]+Users[\\/]+[A-Za-z0-9_. -]+[\\/]'),
    'private-capture-path': re.compile(rb'/var/folders/[A-Za-z0-9_-]+/'),
    'credential': re.compile(rb'\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{50,}|LTAI[A-Za-z0-9]{16,}|AKIA[A-Z0-9]{16})\b|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----\s+[A-Za-z0-9+/=]{40,}'),
}

def findings(data):
    # Scan text and text-like metadata strings, not arbitrary compressed pixels.
    try:
        data.decode('utf8')
        segments = [data]
    except UnicodeDecodeError:
        segments = re.findall(rb'[\x20-\x7e]{12,}', data)
    return sorted({name for name, pattern in RULES.items() for value in segments if pattern.search(value)})

def check_paths(paths, root=ROOT):
    errors=[]
    for rel in paths:
        path=root/rel
        if path.is_file():
            hit=findings(path.read_bytes())
            if hit: errors.append((str(rel),hit))
    if errors:
        for path, hit in errors: print(path+': '+', '.join(hit))
        raise ValueError(f'Privacy check failed in {len(errors)} files')
    return len(paths)

def public_source(path):
    """Asset provenance must not reveal the workstation outside the repository."""
    try: return str(Path(path).resolve().relative_to(ROOT))
    except ValueError: return 'private-source'

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--root',type=Path);a=p.parse_args()
    root=a.root or ROOT
    paths=[x for x in root.rglob('*') if x.is_file()] if a.root else [Path(x) for x in subprocess.check_output(['git','ls-files','-z'],cwd=ROOT).decode().split('\0') if x]
    count=check_paths(paths,root)
    print(f'Privacy check: {count} files passed')
if __name__=='__main__': main()
