#!/usr/bin/env python3
"""Optional independent JSON/XML/raster check against a LOCAL Anvil on port 18545.
Run forge build, then anvil --port 18545, then python3 tools/check_art.py.
No packages, environment variables, keys, remote RPC, or Foundry FFI are used.
The script deploys through the test factory using an unlocked local Anvil account.
Output goes into test/scratch/ and is not a production asset or dependency.
"""
import base64,json,pathlib,struct,subprocess,time,urllib.request,xml.etree.ElementTree as ET,zlib
ROOT=pathlib.Path(__file__).resolve().parents[1]
OUT=ROOT/'test/scratch'; OUT.mkdir(parents=True,exist_ok=True)
RPC='http://127.0.0.1:18545'
RESERVE='2E28b29560a6d4812E58680484c685D0352f8ff9'
def rpc(method,params):
    request=urllib.request.Request(RPC,json.dumps(dict(jsonrpc='2.0',id=1,method=method,params=params)).encode(),{'Content-Type':'application/json'})
    result=json.load(urllib.request.urlopen(request))
    if 'error' in result:raise RuntimeError(result['error'])
    return result['result']
def selector(signature):return subprocess.check_output(['cast','sig',signature],text=True).strip()
def call(address,signature,args=()):
    data=selector(signature)+''.join(f'{x:064x}' for x in args)
    return bytes.fromhex(rpc('eth_call',[{'to':address,'data':data,'gas':'0x1c9c380'},'latest'])[2:])
def dynamic(data):
    at=int.from_bytes(data[:32],'big');size=int.from_bytes(data[at:at+32],'big')
    return data[at+32:at+32+size]
def send(data,to=None):
    tx={'from':account,'data':data,'gas':'0x1c9c380'}
    if to:tx['to']=to
    h=rpc('eth_sendTransaction',[tx]);r=receipt_for(h);assert int(r['status'],16)==1,r
    return r
def receipt_for(h):
    for _ in range(100):
        result=rpc('eth_getTransactionReceipt',[h])
        if result:return result
        time.sleep(0.02)
    raise RuntimeError('local transaction not mined')
account=rpc('eth_accounts',[])[0]
factory_code=json.loads((ROOT/'out/IMDPunks.t.sol/PunkFactory.json').read_text())['bytecode']['object']
factory=send(factory_code)['contractAddress']
receipt=send(selector('deploy(address)')+RESERVE.lower().rjust(64,'0'),factory)
assert int(receipt['gasUsed'],16)<10000000
logs=receipt['logs']; assert len(logs)==200
punks=logs[0]['address']; print('Factory deployment gas:',int(receipt['gasUsed'],16),flush=True)
art='0x'+call(punks,'art()')[-20:].hex()
# Include the required IDs and a deliberately chosen representative of every type.
samples=[0,777,888,9999]+[((r-4321)%10000)*7679%10000 for r in [0,9,33,121,3961]]+[i*47+199 for i in range(191)]
assert len(samples)==len(set(samples))==200
portraits=[];seen_types=set()
claim_sig=selector('claim(uint256)'); uri_sig=selector('tokenURI(uint256)');image_sig=selector('imageOf(uint256)')
for index,number in enumerate(samples):
    if number>=198 and number not in [777,888]:
        # Test accounts are impersonated locally: each claims one number.
        claimer='0x'+f'{0x100000+number:040x}'
        rpc('anvil_impersonateAccount',[claimer]);rpc('anvil_setBalance',[claimer,hex(10**18)])
        h=rpc('eth_sendTransaction',[{'from':claimer,'to':punks,'data':claim_sig+f'{number:064x}','gas':'0x493e0'}])
        assert int(receipt_for(h)['status'],16)==1
    uri=dynamic(bytes.fromhex(rpc('eth_call',[{'to':punks,'data':uri_sig+f'{number:064x}'},'latest'])[2:])).decode()
    assert uri.startswith('data:application/json;base64,')
    meta=json.loads(base64.b64decode(uri.split(',',1)[1],validate=True))
    assert meta['name']==f'IMDPunk #{number}'
    img=dynamic(bytes.fromhex(rpc('eth_call',[{'to':punks,'data':image_sig+f'{number:064x}'},'latest'])[2:])).decode()
    assert meta['image']==img and img.startswith('data:image/svg+xml;base64,')
    svg=base64.b64decode(img.split(',',1)[1],validate=True)
    root=ET.fromstring(svg); assert root.attrib=={'viewBox':'0 0 24 24','shape-rendering':'crispEdges'}
    assert root.tag=='{http://www.w3.org/2000/svg}svg'
    raster=[None]*576
    for rect in root:
        assert rect.tag=='{http://www.w3.org/2000/svg}rect'
        a=rect.attrib;x=int(a.get('x',0));y=int(a.get('y',0));w=int(a['width']);h=int(a['height'])
        assert 0<=x<x+w<=24 and 0<=y<y+h<=24
        color=bytes.fromhex(a['fill'][1:]);assert len(color)==3
        for yy in range(y,y+h):
            for xx in range(x,x+w):raster[yy*24+xx]=color
    assert all(raster)
    attrs=meta['attributes']; assert attrs[0]['trait_type']=='Type'
    kind=attrs[0]['value'];seen_types.add(kind)
    rank=(number*7919+4321)%10000
    expected='Alien' if rank<9 else 'Ape' if rank<33 else 'Zombie' if rank<121 else 'Female' if rank<3961 else 'Male'
    assert kind==expected
    assert attrs[-1]=={'trait_type':'Accessory count','value':len(attrs)-2}
    assert len({a['trait_type'] for a in attrs})==len(attrs)
    for y in range(21,24):
        for x in range(24):
            if x< (7 if kind=='Female' else 6) or x>10:assert raster[y*24+x]==bytes.fromhex('718993')
    portraits.append((number,raster))
    if index<40:(OUT/f'{number}.svg').write_bytes(svg)
    if (index+1)%25==0:print('JSON/XML/raster samples:',index+1,flush=True)
assert seen_types=={'Alien','Ape','Zombie','Female','Male'}
# Write a nearest-neighbour contact sheet as PNG using only the standard library.
scale=6;cols=10;rows=5;gap=6;tile=24*scale
width=cols*(tile+gap)+gap;height=rows*(tile+gap)+gap
canvas=bytearray(bytes.fromhex('eeeeea')*(width*height))
for i,(_,pixels) in enumerate(portraits[:cols*rows]):
    ox=gap+(i%cols)*(tile+gap);oy=gap+(i//cols)*(tile+gap)
    for y in range(tile):
        for x in range(tile):
            pos=((oy+y)*width+ox+x)*3;canvas[pos:pos+3]=pixels[(y//scale)*24+x//scale]
def chunk(tag,data):return struct.pack('>I',len(data))+tag+data+struct.pack('>I',zlib.crc32(tag+data)&0xffffffff)
scan=b''.join(b'\0'+canvas[y*width*3:(y+1)*width*3] for y in range(height))
png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',width,height,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(scan))+chunk(b'IEND',b'')
(OUT/'contact-sheet.png').write_bytes(png)
(OUT/'preview-ids.json').write_text(json.dumps([i for i,_ in portraits[:cols*rows]]))
print('All 200 independent checks passed. Preview:',OUT/'contact-sheet.png',flush=True)
