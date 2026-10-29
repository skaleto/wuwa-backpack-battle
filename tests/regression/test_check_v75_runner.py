import importlib.util, pathlib, sys, unittest
spec=importlib.util.spec_from_file_location('runner',pathlib.Path(__file__).resolve().parents[1]/'tools/legacy/check_v75.py')
r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
class RunnerTests(unittest.TestCase):
 def run_code(self,code,timeout=2):return r.execute([sys.executable,'-u','-c',code],timeout)
 def test_pass(self):self.assertTrue(self.run_code('print("0 failures")')['ok'])
 def test_error_zero_exit(self):self.assertFalse(self.run_code('print("SCRIPT ERROR broken")')['ok'])
 def test_fail_colon(self):self.assertFalse(self.run_code('print("FAIL: broken")')['ok'])
 def test_nonzero(self):self.assertFalse(self.run_code('raise SystemExit(2)')['ok'])
 def test_timeout_retains_partial_streams(self):
  out=self.run_code('import time,sys; print("partial stdout"); print("partial stderr",file=sys.stderr); time.sleep(10)',.1)
  self.assertTrue(out['timeout']);self.assertFalse(out['ok']);self.assertIn('partial stdout',out['output']);self.assertIn('partial stderr',out['output'])
 def test_missing_executable(self):self.assertFalse(r.execute(['/nonexistent-v75'],1)['ok'])
if __name__=='__main__':unittest.main()
