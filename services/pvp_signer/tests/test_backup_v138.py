import importlib.util,sqlite3,tempfile,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('backup',Path(__file__).resolve().parents[1]/'backup.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
class BackupTests(unittest.TestCase):
 def test_wal_restore_and_retention(self):
  with tempfile.TemporaryDirectory() as tmp:
   root=Path(tmp);db=root/'state.db';dest=root/'backups'
   with sqlite3.connect(db) as con:
    con.execute('PRAGMA journal_mode=WAL');con.execute('CREATE TABLE players(id TEXT)');con.execute("INSERT INTO players VALUES('alice')");con.commit()
    a=module.backup(db,dest,2);b=module.backup(db,dest,2);c=module.backup(db,dest,2)
    self.assertFalse(a.exists());self.assertTrue(b.exists())
    self.assertEqual(list(dest.glob("*.tmp*")),[])
    with sqlite3.connect(c) as restored:self.assertEqual(restored.execute('SELECT id FROM players').fetchone(),('alice',))
 def test_missing_database_never_creates_empty_backup(self):
  with tempfile.TemporaryDirectory() as tmp:
   root=Path(tmp)
   with self.assertRaises(FileNotFoundError):module.backup(root/'missing.db',root/'backups')
