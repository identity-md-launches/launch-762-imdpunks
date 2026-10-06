#!/usr/bin/env python3
"""Authoring source for original IMDPunks pixel layers. Python standard library only.
Regenerates src/PunkSprites.sol and docs/accessories.md; no network or sprite-sheet input.
Each rectangle paints flat palette indices; the exported data contains horizontal pixel runs.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = []

class Layer:
    def __init__(self): self.p = [[-1]*24 for _ in range(24)]
    def box(self,x,y,w,h,c):
        assert 0 <= x < x+w <= 24 and 0 <= y < y+h <= 21
        for row in range(y,y+h):
            for col in range(x,x+w): self.p[row][col] = c
        return self
    def runs(self):
        out = bytearray()
        for y,row in enumerate(self.p):
            x=0
            while x<24:
                c=row[x]; end=x+1
                while end<24 and row[end]==c: end+=1
                if c>=0: out.extend((y,x,end-x,c))
                x=end
        return out

def add(name,slot,female,layer):
    colors={v for row in layer.p for v in row if v>=0}
    assert len(colors)<=3, (name,colors)
    assert sum(v>=0 for row in layer.p for v in row)>=3 or 'Mole' in name
    CATALOG.append((name,slot,female,layer))

def head(style,color,f=False):
    p=Layer(); x=7 if f else 6; y=7 if f else 5; w=9 if f else 11
    # All female hair extends beyond her outline. Nothing extends below row 20.
    if style=='mohawk':
        p.box(10,y-4,3,4,1).box(11,y-4,2,5,color).box(9,y,5,2,color)
        p.box(x-1,y+3,2,3,color)
    elif style=='wild':
        p.box(x-2,y-1,w+3,5,color).box(x-1,y-3,3,3,color).box(x+4,y-4,3,4,color)
        p.box(x+w-1,y-2,3,4,color).box(x-2,y+3,3,4,color)
    elif style=='messy':
        p.box(x-1,y-1,w+2,4,color).box(x+1,y-2,3,2,color).box(x+6,y-3,3,3,color)
        p.box(x-1,y+2,2,5,color).box(x+5,y+2,4,2,color)
    elif style=='part':
        p.box(x-1,y,w+1,3,color).box(x+1,y-1,w-2,2,color).box(x-1,y+2,3,6,color)
        p.box(x+6,y,1,3,1)
    elif style=='long':
        p.box(x-2,y,w+3,3,color).box(x-2,y+2,3,21-y-2,color)
        p.box(x+w-1,y+2,3,21-y-2,color).box(x,y-1,w-1,2,color)
    elif style=='bob':
        p.box(x-2,y,w+3,4,color).box(x-2,y+3,3,9,color)
        p.box(x+w-1,y+3,3,9,color).box(x,y-1,w-1,2,color)
    elif style=='tails':
        p.box(x-1,y,w+1,3,color).box(x,y-1,w-1,2,color)
        p.box(x-3,y+3,3,8,color).box(x+w,y+3,3,8,color)
        p.box(x-3,y+4,3,2,14).box(x+w,y+4,3,2,14)
    elif style=='frizz':
        p.box(x-2,y-1,w+3,5,color).box(x,y-3,w-1,3,color)
        p.box(x-3,y+2,3,6,color).box(x+w,y+2,3,6,color)
        p.box(x-1,y-2,2,2,color).box(x+w-1,y-2,2,2,color)
    elif style=='braids':
        p.box(x-1,y,w+1,3,color).box(x-2,y+2,3,12,color).box(x+w,y+2,3,12,color)
        for yy in range(y+4,y+14,3):
            p.box(x-2,yy,3,1,1).box(x+w,yy,3,1,1)
    elif style=='crop':
        p.box(x,y,w-1,3,color).box(x+1,y-1,w-3,1,color).box(x,y+2,2,3,color)
    elif style=='stripe':
        p.box(x+1,y,w-3,2,color).box(x,y+2,2,5,color).box(x,y+4,3,1,12)
    elif style=='cap':
        p.box(x-1,y-1,w+1,4,1).box(x,y-1,w-1,3,color).box(x+3,y+2,w,2,1)
        p.box(x+4,y+2,w-1,1,color)
    elif style=='beanie':
        p.box(x,y-2,w-1,2,1).box(x-1,y,w+1,4,1).box(x,y-1,w-1,4,color)
        p.box(x-1,y+2,w+1,2,12)
    elif style=='hood':
        # Hood frames the head only, with no garment, shoulders or body.
        p.box(x-2,y-2,w+3,4,1).box(x-2,y+1,2,20-y,1).box(x+w-1,y+1,3,20-y,1)
        p.box(x-1,y-1,w+1,3,color).box(x-1,y+2,1,18-y,color).box(x+w,y+2,1,18-y,color)
    elif style=='bandana':
        p.box(x-1,y,w+1,3,color).box(x-2,y+2,3,4,color).box(x+2,y+1,6,1,13)
    elif style=='band':
        p.box(x-1,y+3,w+1,2,color).box(x,y+3,w-1,1,13)
    elif style=='top':
        p.box(x+1,max(0,y-5),w-3,6,1).box(x+2,max(0,y-4),w-5,4,color)
        p.box(x+1,y-1,w-3,2,14).box(x-2,y+1,w+3,2,1)
    elif style=='fedora':
        p.box(x+1,y-3,w-3,2,1).box(x,y-1,w-1,3,color).box(x-2,y+2,w+3,2,1)
        p.box(x,y+1,w-1,1,14)
    elif style=='cowboy':
        p.box(x+1,y-3,w-3,5,color).box(x+3,y-3,3,1,1)
        p.box(x-3,y+1,w+5,2,color).box(x-3,y,2,2,color).box(x+w,y,2,2,color)
        p.box(x,y+1,w-1,1,1)
    elif style=='police':
        p.box(x-1,y-2,w+1,4,21).box(x,y-3,w-1,2,21)
        p.box(x+4,y-1,3,2,20).box(x,y+2,w+2,2,1)
    elif style=='tiara':
        p.box(x,y+1,w-1,2,20).box(x+1,y-1,2,3,20).box(x+5,y-2,2,4,20)
        p.box(x+5,y,2,2,18)
    elif style=='wide':
        p.box(x,y-2,w-1,4,color).box(x-3,y+2,w+5,2,color).box(x,y+1,w-1,1,14)
    else: raise ValueError(style)
    return p

male_heads=[('Copper Mohawk','mohawk',22),('Blue Mohawk','mohawk',15),('Green Mohawk','mohawk',16),('Pink Mohawk','mohawk',18),('Wild Crop','wild',9),('Messy Crop','messy',10),('Side Part','part',9),('Long Straight Hair','long',10),('Short Bob','bob',9),('Round Frizz','frizz',9),('Work Cap','cap',15),('Wool Beanie','beanie',16),('Loose Hood','hood',21),('Tied Bandana','bandana',14),('Sport Headband','band',15),('Tall Hat','top',21),('Felt Fedora','fedora',10),('Ranch Hat','cowboy',11),('Police Cap','police',21),('Gold Tiara','tiara',20),('Twin Tails','tails',10),('Curly Crop','crop',9),('Shaved Stripe','stripe',10)]
female_heads=[('Rose Mohawk','mohawk',18),('Teal Mohawk','mohawk',19),('Violet Mohawk','mohawk',17),('Wild Waves','wild',10),('Messy Waves','messy',9),('Swept Part','part',11),('Long Silk Hair','long',9),('Blunt Bob','bob',14),('High Pigtails','tails',11),('Wide Frizz','frizz',9),('Long Braids','braids',10),('Soft Cap','cap',18),('Knit Beanie','beanie',17),('Tied Headscarf','bandana',15),('Cloth Headband','band',14),('Rose Tiara','tiara',20),('Wide Sunhat','wide',11),('Soft Hood','hood',17)]

def eyes(style,f):
    p=Layer(); y=13 if f else 12; l=9; r=13 if f else 14
    if style=='big':
        p.box(l-1,y-1,4,4,1).box(r-1,y-1,4,4,1).box(l+3,y,1,1,1).box(l-3,y,2,1,1)
    elif style=='small':
        p.box(l-1,y,4,2,1).box(r-1,y,4,2,1).box(l+2,y,3,1,1).box(l-3,y,2,1,1)
    elif style=='nerd':
        p.box(l-1,y-1,4,4,1).box(r-1,y-1,4,4,1).box(l,y,2,2,13).box(r,y,2,2,13)
        p.box(l+3,y,1,1,1).box(l-3,y,2,1,1)
    elif style=='3d':
        p.box(l-2,y-1,r-l+6,4,13).box(l-1,y,3,2,14).box(r,y,3,2,15)
    elif style=='visor':
        p.box(l-3,y-1,r-l+7,4,1).box(l-2,y,r-l+5,2,19)
    elif style=='patch':
        p.box(l-3,y-1,r-l+6,1,1).box(r-1,y,3,3,1)
    elif style=='shadow':
        p.box(l-1,y-1,3,2,17).box(r-1,y-1,3,2,17).box(l,y,2,1,1).box(r,y,2,1,1)
    return p

def mouth(style,f):
    p=Layer(); x=12; y=18 if f else 17
    if style=='cigarette':p.box(x+2,y,6,1,13).box(x+7,y,1,1,14)
    elif style=='pipe':p.box(x+2,y,5,1,10).box(x+6,y-2,3,3,10).box(x+6,y-2,3,1,1)
    elif style=='vape':p.box(x+2,y,6,2,21).box(x+6,y,2,1,19)
    elif style=='smile':p.box(x-1,y,5,1,2).box(x-1,y,1,1,1).box(x+3,y,1,1,1).box(x,y+1,3,1,1)
    elif style=='frown':p.box(x-1,y,5,1,2).box(x,y,3,1,1).box(x-1,y+1,1,1,1).box(x+3,y+1,1,1,1)
    elif style=='lipstick':p.box(x-1,y,4,2,14).box(x,y,2,1,24)
    elif style=='teeth':p.box(x-1,y,5,1,1).box(x,y,2,2,13)
    elif style=='pick':p.box(x+2,y,5,1,11)
    return p

def beard(style):
    p=Layer()
    if style=='beard':p.box(7,16,2,4,9).box(9,18,6,2,9).box(15,16,1,3,9)
    elif style=='strap':p.box(7,14,1,6,10).box(8,19,7,1,10).box(15,15,1,4,10)
    elif style=='goatee':p.box(11,18,3,2,9).box(11,16,4,1,9)
    elif style=='moustache':p.box(10,16,5,1,9).box(10,17,2,1,9)
    elif style=='handle':p.box(10,16,5,1,10).box(9,16,2,3,10).box(15,16,1,3,10)
    elif style=='chops':p.box(7,13,2,5,9).box(14,18,2,2,9)
    return p

for f,heads in [(False,male_heads),(True,female_heads)]:
    for name,style,c in heads:add(name,0,f,head(style,c,f))
    for name,style in [('Wide Shades','big'),('Slim Shades','small'),('Study Glasses','nerd'),('Cinema Glasses','3d'),('Clear Visor','visor'),('Cloth Eye Patch','patch'),('Plum Eye Shadow','shadow')]:
        add(('Small ' if f else '')+name,1,f,eyes(style,f))
    mouths=[('Paper Cigarette','cigarette'),('Wood Pipe','pipe'),('Pocket Vape','vape'),('Wide Smile','smile'),('Deep Frown','frown'),('Red Lipstick','lipstick'),('Front Teeth','teeth'),('Wood Toothpick','pick')]
    if f: mouths=[mouths[i] for i in [0,2,3,4,5,6]]
    for name,style in mouths:add(('Soft ' if f else '')+name,2,f,mouth(style,f))
    if not f:
        for name,style in [('Full Beard','beard'),('Chin Strap','strap'),('Square Goatee','goatee'),('Short Moustache','moustache'),('Handlebar Moustache','handle'),('Side Whiskers','chops')]:add(name,3,f,beard(style))
    p=Layer();x=6 if f else 5;y=15 if f else 14
    p.box(x,y,2,3,20).box(x,y+1,1,1,1)
    add('Gold Drop' if f else 'Gold Hoop',4,f,p)
    # Neck jewellery is confined to the existing neck above row 21.
    p=Layer().box(8 if f else 7,20,2 if f else 3,1,20)
    if f:p.box(8,19,1,1,20)
    add('Fine Chain' if f else 'Short Chain',5,f,p)
    p=Layer().box(8 if f else 7,20,2 if f else 3,1,1)
    if f:p.box(8,19,2,1,1)
    add('Velvet Choker' if f else 'Plain Choker',5,f,p)
    add('Beauty Mole' if f else 'Cheek Mole',6,f,Layer().box(10,16,1,1,9))
    add('Peach Cheek' if f else 'Rosy Cheek',6,f,Layer().box(8 if f else 9,15,3,2,18))
    add('Small Spot' if f else 'Dark Spot',6,f,Layer().box(10,15,2,2,10))

assert len(CATALOG)==87,len(CATALOG)
blob=bytearray();names=bytearray();records=bytearray();md=['# Accessory catalog','', 'Original authored layers, generated by `tools/generate_sprites.py`. IDs are stable; 0 means no accessory.', '', '| ID | Set | Slot | Name | Pixels |', '|---|---|---|---|---|']
for i,(name,slot,f,p) in enumerate(CATALOG,1):
    runs=p.runs();n=name.encode()
    records.extend(len(blob).to_bytes(2,'big')+len(runs).to_bytes(2,'big')+len(names).to_bytes(2,'big')+bytes((len(n),slot,int(f))))
    blob.extend(runs);names.extend(n)
    md.append(f'| {i} | {"Female" if f else "Male / Alien / Ape / Zombie"} | {["Head","Eyes","Mouth","Facial hair","Ear","Neck","Face mark"][slot]} | {name} | {sum(v>=0 for row in p.p for v in row)} |')
source='''// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @notice Original flat pixel layers. Generated by tools/generate_sprites.py; no storage or setters.
contract PunkSprites {
    uint256 public constant ACCESSORY_COUNT = 87;
    bytes private constant RECORDS = hex"RECORDS";
    bytes private constant PIXELS = hex"PIXELS";
    bytes private constant NAMES = hex"NAMES";

    function accessory(uint256 id) external pure returns (string memory name, uint8 slot, bool female, bytes memory runs) {
        require(id > 0 && id <= ACCESSORY_COUNT, "accessory range");
        bytes memory records = RECORDS;
        uint256 i = (id - 1) * 9;
        uint256 start = uint256(uint8(records[i])) * 256 + uint8(records[i+1]);
        uint256 length = uint256(uint8(records[i+2])) * 256 + uint8(records[i+3]);
        uint256 nameStart = uint256(uint8(records[i+4])) * 256 + uint8(records[i+5]);
        name = string(_slice(NAMES, nameStart, uint8(records[i+6])));
        slot = uint8(records[i+7]);
        female = records[i+8] != 0;
        runs = _slice(PIXELS, start, length);
    }

    function _slice(bytes memory data, uint256 start, uint256 length) private pure returns (bytes memory result) {
        result = new bytes(length);
        // Every offset and length is generated from this contract's constant tables.
        assembly ("memory-safe") {
            let src := add(add(data, 32), start)
            let dst := add(result, 32)
            for { let j := 0 } lt(j, length) { j := add(j, 32) } {
                mstore(add(dst, j), mload(add(src, j)))
            }
        }
    }
}
'''
source=source.replace('hex"RECORDS"','hex"'+records.hex()+'"').replace('hex"PIXELS"','hex"'+blob.hex()+'"').replace('hex"NAMES"','hex"'+names.hex()+'"')
(ROOT/'src/PunkSprites.sol').write_text(source)
(ROOT/'docs/accessories.md').write_text('\n'.join(md)+'\n')
print(f'{len(CATALOG)} accessories; {len(blob)} pixel bytes; {len(records)+len(blob)+len(names)} total table bytes')
