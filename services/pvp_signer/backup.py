"""Consistent SQLite backup with restore verification and bounded local retention."""
import argparse,os,sqlite3,tempfile,time
from contextlib import closing
from pathlib import Path

def backup(database:Path,destination:Path,keep:int=7):
    if keep<1:raise ValueError('keep must be positive')
    os.umask(0o077)
    destination.mkdir(parents=True,exist_ok=True,mode=0o700)
    if not database.is_file():raise FileNotFoundError('database missing')
    final=destination/('state-'+time.strftime('%Y%m%dT%H%M%SZ',time.gmtime())+f'-{time.time_ns()%1000000000:09d}.sqlite3')
    temporary=final.with_suffix('.tmp')
    try:
        with closing(sqlite3.connect(f'file:{database}?mode=ro',uri=True)) as source,closing(sqlite3.connect(temporary)) as target:
            source.backup(target)
        # Restore into a separate database, proving a usable snapshot, not a WAL copy.
        with tempfile.TemporaryDirectory(dir=destination,prefix='.verify-') as directory:
            with closing(sqlite3.connect(temporary)) as source,closing(sqlite3.connect(Path(directory)/'restored.db')) as restored:
                source.backup(restored)
                if restored.execute('PRAGMA integrity_check').fetchone()[0]!='ok':raise RuntimeError('restore integrity check failed')
                tables=[r[0] for r in source.execute("SELECT name FROM sqlite_master WHERE type='table'")]
                for name in tables:
                    quoted='"'+name.replace('"','""')+'"'
                    if source.execute('SELECT COUNT(*) FROM '+quoted).fetchone()!=restored.execute('SELECT COUNT(*) FROM '+quoted).fetchone():raise RuntimeError('restore row count mismatch')
        os.replace(temporary,final)
        # Only files created by this tool; never remove a different service's backups.
        for old in sorted(destination.glob('state-????????T??????Z-?????????.sqlite3'),reverse=True)[keep:]:old.unlink()
        return final
    finally:
        temporary.unlink(missing_ok=True)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--database',default='/var/lib/pvp-signer/state.db');p.add_argument('--directory',default='/var/backups/pvp-signer');p.add_argument('--keep',type=int,default=7);a=p.parse_args()
    output=backup(Path(a.database),Path(a.directory),a.keep)
    print('Verified backup:',output.name,'bytes:',output.stat().st_size)
