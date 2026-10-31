#!/usr/bin/env python3
"""Build cumulative signed update releases. Private keys stay outside the project.

Use `patch` against an immutable baseline PCK + its runtime inventory, or `sign`
with a release specification containing locally verified artifact paths. Publish
immutable artifacts before replacing updates/stable.json. No credentials needed.
"""
import argparse, base64, hashlib, json, subprocess, tempfile
from pathlib import Path
from build import GODOT, ROOT
IMMUTABLE = ('main.tscn', 'project.godot', 'data/update-channel.json',
             'scripts/update/bootstrap.gd', 'scripts/update/update_manifest.gd',
             'scripts/update/update_store.gd')
def digest(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for part in iter(lambda:f.read(1024*1024),b''):h.update(part)
    return h.hexdigest()
def require_base(stage, inventory):
    entries={e['path']:e['sha256'] for e in json.loads(inventory.read_text())}
    for name in IMMUTABLE:
        if entries.get(name)!=digest(stage/name):
            raise ValueError('Bootstrap/runtime changed; publish a full client: '+name)
def patch(stage, base_pack, inventory, platform, output):
    require_base(stage,inventory)
    if not base_pack.is_file() or output.exists():raise ValueError('Need existing baseline and new output path')
    output.parent.mkdir(parents=True,exist_ok=True)
    result=subprocess.run([GODOT,'--headless','--path',str(stage),'--export-patch',platform,str(output),'--patches',str(base_pack)],capture_output=True,text=True,timeout=600)
    if result.returncode or 'ERROR:' in result.stdout+result.stderr:
        output.with_suffix('.log').write_text(result.stdout+result.stderr)
        raise RuntimeError('Patch export failed or no files changed; inspect the local .log beside output')
    if not output.is_file():raise RuntimeError('No patch output')
def sign(spec, key, output, channel):
    key=key.resolve()
    if key.is_relative_to(ROOT):raise ValueError('Signing key must be outside repository')
    config=json.loads(channel.read_text());release=json.loads(spec.read_text())
    if release.get('schema')!=1 or type(release.get('sequence')) is not int or release['sequence']<config['sequence']:raise ValueError('Invalid release sequence')
    if not isinstance(release.get('notes',[]),list) or len(release.get('notes',[]))>8:raise ValueError('Invalid notes')
    from urllib.parse import urlsplit
    for platform,entry in release['platforms'].items():
        for artifact in [entry]+([entry['full']] if 'full' in entry else []):
            for field in ('url','fallback_url'):
                if field not in artifact:continue
                url=urlsplit(artifact[field])
                if url.scheme!='https' or url.hostname not in config['hosts'] or url.username or url.port or url.fragment:raise ValueError('Untrusted origin')
            if artifact['kind']=='web':continue
            if artifact['kind']=='full':
                root=artifact.get('archive_root','');exe=artifact.get('executable','')
                if not root or '/' in root or not exe:raise ValueError('Full artifact needs archive_root/executable')
                for part in (root,exe):
                    if Path(part).is_absolute() or any(x in ('', '.', '..') for x in part.split('/')) or '\\' in part or ':' in part:raise ValueError('Unsafe archive layout')
            local=Path(artifact.pop('file')).resolve()
            if not local.is_file():raise ValueError('Missing artifact')
            artifact.update(bytes=local.stat().st_size,sha256=digest(local))
    # Check the signing key matches the pinned public key before generating feed.
    public=subprocess.check_output(['openssl','pkey','-in',str(key),'-pubout'],stderr=subprocess.DEVNULL).decode()
    if public.strip()!=config['public_key'].strip():raise ValueError('Wrong signing key')
    raw=json.dumps(release,ensure_ascii=False,separators=(',',':')).encode()
    with tempfile.TemporaryDirectory() as d:
        payload=Path(d)/'payload';payload.write_bytes(raw)
        signature=subprocess.check_output(['openssl','dgst','-sha256','-sign',str(key),str(payload)],stderr=subprocess.DEVNULL)
    envelope=json.dumps({'payload':base64.b64encode(raw).decode(),'signature':base64.b64encode(signature).decode()},separators=(',',':')).encode()
    if len(envelope)>65536:raise ValueError('Feed too large')
    output.parent.mkdir(parents=True,exist_ok=True)
    temp=output.with_suffix('.tmp');temp.write_bytes(envelope);temp.replace(output)
    return release
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);sub=p.add_subparsers(dest='command',required=True)
    s=sub.add_parser('sign');s.add_argument('--spec',type=Path,required=True);s.add_argument('--key',type=Path,required=True);s.add_argument('--output',type=Path,required=True);s.add_argument('--channel',type=Path,default=ROOT/'data/update-channel.json')
    s=sub.add_parser('patch');s.add_argument('--stage',type=Path,required=True);s.add_argument('--base-pack',type=Path,required=True);s.add_argument('--inventory',type=Path,required=True);s.add_argument('--platform',choices=['Windows','macOS'],required=True);s.add_argument('--output',type=Path,required=True)
    a=p.parse_args()
    if a.command=='sign':
        release=sign(a.spec,a.key,a.output,a.channel);print('Signed release',release['version'],'sequence',release['sequence'])
    else:patch(a.stage.resolve(),a.base_pack.resolve(),a.inventory.resolve(),a.platform,a.output.resolve());print('Cumulative patch:',a.output.name)
