#!/usr/bin/env python3
"""Run explicitly registered game regressions with isolated QA profiles."""
import argparse,json,os,re,subprocess,sys,time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from release_manifest import ROOT,compute
GODOT=os.environ.get('GODOT','/Applications/Godot.app/Contents/MacOS/Godot')
SUITES=json.loads((ROOT/'tests/suites.json').read_text())
ERROR=re.compile(r'SCRIPT ERROR|Parse Error|^ERROR:|^FAIL(?:\s|:)',re.M)
def prepare_output_dirs():
    (ROOT/'build').mkdir(exist_ok=True);(ROOT/'build/.gdignore').touch()
    # Historic tests still produce their own named reports; these are outputs,
    # not hidden dependencies. Materialize output parents on a fresh clone.
    for path in (ROOT/'tests').rglob('*.gd'):
        for rel in re.findall(r'res://(build/qa/[^"\s]+)',path.read_text()):
            rel=rel.split("'")[0]
            parent=ROOT/rel if rel.endswith('/') else (ROOT/rel).parent
            parent.mkdir(parents=True,exist_ok=True)
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('tests',nargs='*');parser.add_argument('--jobs',type=int,choices=[1,2],default=1)
    args=parser.parse_args();selected=args.tests or list(SUITES)
    unknown=set(selected)-SUITES.keys()
    if unknown:parser.error('unknown suites: '+', '.join(sorted(unknown)))
    if compute()!=json.loads((ROOT/'data/release-hashes.json').read_text()):raise SystemExit('Stale release fingerprints')
    subprocess.run([sys.executable, '-m', 'unittest', 'discover', '-s', 'tests', '-p', 'test_privacy.py'], cwd=ROOT, check=True)
    prepare_output_dirs();logs=ROOT/'build/qa/regression';logs.mkdir(parents=True,exist_ok=True)
    def run(name):
        start=time.monotonic();spec=SUITES[name]
        try:
            result=subprocess.run([GODOT,'--headless','--path',str(ROOT),'--script',spec['path']],capture_output=True,text=True,timeout=spec['timeout'])
            output=result.stdout+result.stderr;code=result.returncode;timed_out=False
        except subprocess.TimeoutExpired as e:
            decode=lambda x:x.decode(errors='replace') if isinstance(x,bytes) else x or ''
            output=decode(e.stdout)+decode(e.stderr)+'\nTIMEOUT\n';code=None;timed_out=True
        except OSError as e:output=str(e);code=None;timed_out=False
        row={'ok':code==0 and not ERROR.search(output),'returncode':code,'timeout':timed_out,'seconds':round(time.monotonic()-start,3)}
        (logs/(name+'.log')).write_text(output)
        print(('PASS' if row['ok'] else 'FAIL')+f" {name} ({row['seconds']}s)",flush=True)
        return name,row
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:summary=dict(pool.map(run,selected))
    (logs/('partial-summary.json' if args.tests else 'suite-summary.json')).write_text(json.dumps(summary,indent=2)+'\n')
    passed=sum(bool(v['ok']) for v in summary.values());print(f'{passed}/{len(selected)} passed')
    return int(passed!=len(selected))
if __name__=='__main__':sys.exit(main())
