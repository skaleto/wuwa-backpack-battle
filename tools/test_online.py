#!/usr/bin/env python3
"""Real client + real signer business API + test-only in-memory OSS transport."""
from pathlib import Path
import subprocess
import sys
import tempfile
import time
ROOT = Path(__file__).resolve().parents[1]
GODOT = '/Applications/Godot.app/Contents/MacOS/Godot'
SCRIPT = 'tests/regression/test_async_integration_v134.gd'
with tempfile.TemporaryDirectory(prefix='pvp-v134-') as tmp:
    pool = Path(tmp)/'pool'; state = Path(tmp)/'fixture.json'
    prefix = [GODOT, '--headless', '--path', str(ROOT), '--script', SCRIPT, '--']
    subprocess.run(prefix+['--pool-file', str(pool)], cwd=ROOT, check=True, timeout=20)
    server = subprocess.Popen([sys.executable, 'tests/fixtures/async_http_fixture_v134.py', '--state', str(state), '--pool', pool.read_text()], cwd=ROOT, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    try:
        for _ in range(100):
            if state.exists() or server.poll() is not None: break
            time.sleep(.05)
        if not state.exists(): raise RuntimeError('Local fixture did not start')
        try:
            result = subprocess.run(prefix+['--fixture', str(state)], cwd=ROOT, capture_output=True, text=True, timeout=45)
            output = result.stdout+result.stderr
            failed = result.returncode != 0 or 'SCRIPT ERROR' in output or 'FAIL ' in output
        except subprocess.TimeoutExpired as error:
            output = (error.stdout or b'').decode()+(error.stderr or b'').decode()+'\nFAIL timeout\n'
            failed = True
        dest = ROOT/'build/qa/pvp-v134/checks';dest.mkdir(parents=True, exist_ok=True)
        (dest/'client-service-integration.log').write_text(output)
        print(output)
    finally:
        server.terminate();server.communicate(timeout=15)
    sys.exit(1 if failed else 0)
