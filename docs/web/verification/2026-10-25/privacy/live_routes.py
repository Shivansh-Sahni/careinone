"""Public route and byte checks; never calls paid inference."""
import datetime as dt,hashlib,json,urllib.request,urllib.error
from pathlib import Path
root=Path(__file__).resolve().parents[5]
origin='https://careinone.org'
report={'checkedAtUTC':dt.datetime.now(dt.timezone.utc).isoformat(),'releaseSHA':'5246f03323bed521b41f318a0e3a8d21beebfa20','paidRequests':0,'patientDataUsed':False,'checks':[]}
for base,path,expected,file in [
 (origin,'/',200,'web/public/index.html'),(origin,'/app.js',200,'web/public/app.js'),
 (origin,'/api/status',200,None),(origin,'/api/config',401,None),
 (origin,'/privacy',200,'backend/public/privacy.html'),(origin,'/support',200,'backend/public/support.html'),
 ('https://careinone-api.onrender.com','/health',200,None),
 ('https://careinone-api.onrender.com','/v1/config',401,None),
 ('https://careinone-api.onrender.com','/privacy',200,'backend/public/privacy.html'),
 ('https://careinone-api.onrender.com','/support',200,'backend/public/support.html'),
 ('https://careinone-api.onrender.com','/',400,None)]:
 req=urllib.request.Request(base+path)
 try:
  response=urllib.request.urlopen(req,timeout=25)
 except urllib.error.HTTPError as error:
  response=error
 with response:
  raw=response.read(); item={'url':base+path,'status':response.status}
  assert response.status==expected,item
  if file:
   assert raw==(root/file).read_bytes(),file
   item.update(bytesMatchLocal=True,sha256=hashlib.sha256(raw).hexdigest())
  if path=='/api/status':
   assert json.loads(raw)=={'enabled':True,'storage':'browser-only','publicAccess':True}
  report['checks'].append(item)
for path in ('/','/app.js'):
 with urllib.request.urlopen('https://www.careinone.org'+path,timeout=25) as response:
  assert response.url==origin+path
  report['checks'].append({'wwwRedirectPath':path,'finalURL':response.url,'passed':True})
report['passed']=True
print(json.dumps(report,indent=2))
