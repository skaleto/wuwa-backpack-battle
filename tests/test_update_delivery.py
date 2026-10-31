"""Real TLS download + signed artifact verification, isolated from player files."""
import base64, hashlib, http.server, json, os, ssl, subprocess, tempfile, threading, unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
GODOT=os.environ.get('GODOT','/Applications/Godot.app/Contents/MacOS/Godot')
class Delivery(unittest.TestCase):
 def test_https_delivery(self):
  with tempfile.TemporaryDirectory() as tmp:
   p=Path(tmp);key=p/'sign.pem';tls=p/'tls.pem';cert=p/'cert.pem'
   def openssl(*args):return subprocess.check_output(['openssl',*map(str,args)],stderr=subprocess.DEVNULL)
   openssl('genrsa','-out',key,2048)
   openssl('req','-x509','-newkey','rsa:2048','-nodes','-keyout',tls,'-out',cert,'-days','1','-subj','/CN=localhost','-addext','subjectAltName=DNS:localhost')
   class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self,*args):pass
    def do_GET(self):
     route=self.path.split('?')[0]
     if route=='/redirect.json':self.send_response(302);self.send_header('Location','https://not-allowed.invalid/file');self.end_headers();return
     data=responses.get(route,b'')
     self.send_response(200 if data else 404);self.send_header('Content-Length',str(len(data)));self.end_headers();self.wfile.write(data)
   server=http.server.ThreadingHTTPServer(('localhost',0),Handler)
   context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER);context.load_cert_chain(cert,tls);server.socket=context.wrap_socket(server.socket,server_side=True)
   # Production accepts standard HTTPS only. QA binds an ephemeral TLS port via
   # a subclassed request adapter; the protocol still validates canonical URLs.
   base='https://localhost/'
   data=b'test-content'
   release={'schema':1,'sequence':11,'version':'v11','base_id':'qa','runtime':1,'notes':[], 'platforms':{'Windows':{'kind':'patch','url':base+'11.pck','bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}}}
   raw=json.dumps(release).encode();(p/'payload').write_bytes(raw)
   envelope={'payload':base64.b64encode(raw).decode(),'signature':base64.b64encode(openssl('dgst','-sha256','-sign',key,p/'payload')).decode()}
   tampered=dict(envelope,payload=base64.b64encode(raw+b' ').decode())
   responses={'/feed.json':json.dumps(envelope).encode(),'/tampered.json':json.dumps(tampered).encode(),'/11.pck':data,'/corrupt.pck':b'bad-content!'}
   config={'public_key':openssl('rsa','-in',key,'-pubout').decode(),'hosts':['localhost'],'feed_url':base+'feed.json','runtime':1,'base_id':'qa','sequence':10,'version':'v10','certificate':str(cert),'cache':str(p/'cache'),'qa_port':server.server_port}
   (p/'config.json').write_text(json.dumps(config))
   thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
   try:
    result=subprocess.run([GODOT,'--headless','--path',str(ROOT),'--script','tests/regression/update_https_probe.gd','--',str(p/'config.json')],capture_output=True,text=True,timeout=60)
    self.assertEqual(result.returncode,0,result.stdout+result.stderr)
    self.assertNotIn('SCRIPT ERROR',result.stderr)
   finally:server.shutdown();server.server_close();thread.join()
if __name__=='__main__':unittest.main()
