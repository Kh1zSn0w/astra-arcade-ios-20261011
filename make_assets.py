from pathlib import Path
import struct, zlib, math, random, wave, array

ROOT = Path(__file__).resolve().parent / "Astra" / "Assets"
ROOT.mkdir(parents=True, exist_ok=True)

class Canvas:
    def __init__(self, w, h):
        self.w,self.h=w,h
        self.p = bytearray(w*h*4)
    def px(self,x,y,c):
        if 0<=x<self.w and 0<=y<self.h:
            i=(int(y)*self.w+int(x))*4
            self.p[i:i+4]=bytes(c)
    def rect(self,x1,y1,x2,y2,c):
        for y in range(max(0,int(y1)),min(self.h,int(y2)+1)):
            for x in range(max(0,int(x1)),min(self.w,int(x2)+1)): self.px(x,y,c)
    def poly(self,pts,c):
        for y in range(self.h):
            crossings=[]
            for i in range(len(pts)):
                (x1,y1),(x2,y2)=pts[i],pts[(i+1)%len(pts)]
                if (y1<=y<y2) or (y2<=y<y1):
                    crossings.append(x1+(y-y1)*(x2-x1)/(y2-y1))
            crossings.sort()
            for i in range(0,len(crossings)-1,2):
                for x in range(max(0,math.ceil(crossings[i])),min(self.w,math.ceil(crossings[i+1]))):
                    self.px(x,y,c)
    def ellipse(self,cx,cy,rx,ry,c):
        for y in range(max(0,int(cy-ry)),min(self.h,int(cy+ry)+1)):
            for x in range(max(0,int(cx-rx)),min(self.w,int(cx+rx)+1)):
                if ((x-cx)/rx)**2+((y-cy)/ry)**2 <= 1: self.px(x,y,c)
    def save(self,name):
        def chunk(tag,data): return struct.pack(">I",len(data))+tag+data+struct.pack(">I",zlib.crc32(tag+data)&0xffffffff)
        raw=b"".join(b"\x00"+bytes(self.p[y*self.w*4:(y+1)*self.w*4]) for y in range(self.h))
        png=b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR",struct.pack(">IIBBBBB",self.w,self.h,8,6,0,0,0))+chunk(b"IDAT",zlib.compress(raw,9))+chunk(b"IEND",b"")
        (ROOT/name).write_bytes(png)
        print("SPRITE",name,len(png))

D=(21,31,53,255); BLACK=(9,17,29,255); INK=(25,36,55,255)
STEEL=(106,155,173,255); LIGHT=(209,232,218,255); CYAN=(112,234,230,255); WHITE=(246,248,226,255)
ORANGE=(255,169,92,255); RED=(239,101,92,255); RED_DARK=(119,50,63,255)
GOLD=(238,199,111,255); BLUE=(49,95,132,255)

# Falcon: ship geometry has deliberate stepped silhouette rather than a flat emoji icon.
c=Canvas(64,80)
c.poly([(32,1),(39,20),(45,39),(60,48),(60,63),(42,60),(39,74),(25,74),(22,60),(4,63),(4,48),(19,39),(25,20)],BLACK)
c.poly([(32,5),(38,25),(43,43),(57,50),(56,58),(39,56),(36,70),(28,70),(25,56),(8,58),(7,50),(21,43),(26,25)],STEEL)
c.poly([(32,7),(35,22),(35,57),(32,65),(29,57),(29,22)],LIGHT)
c.poly([(30,25),(34,25),(39,39),(34,46),(30,46),(25,39)],BLACK)
c.poly([(31,28),(33,28),(36,39),(33,43),(31,43),(28,39)],CYAN)
c.poly([(19,44),(25,39),(27,52),(11,54)],BLUE)
c.poly([(45,44),(39,39),(37,52),(53,54)],BLUE)
c.rect(10,55,22,58,WHITE);c.rect(42,55,54,58,WHITE)
c.rect(24,68,28,77,ORANGE);c.rect(36,68,40,77,ORANGE)
c.rect(26,69,27,77,GOLD);c.rect(37,69,38,77,GOLD)
c.save("falcon.png")

def fighter(name,base,accent,variant=0):
    c=Canvas(56,68)
    c.poly([(28,64),(37,45),(42,32),(54,21),(52,8),(36,17),(33,4),(23,4),(20,17),(4,8),(2,21),(14,32),(19,45)],BLACK)
    c.poly([(28,59),(34,43),(39,30),(51,18),(48,12),(34,20),(31,8),(25,8),(22,20),(8,12),(5,18),(17,30),(22,43)],base)
    c.poly([(28,55),(31,39),(31,11),(25,11),(25,39)],accent)
    c.poly([(25,37),(31,37),(34,28),(28,23),(22,28)],BLACK)
    c.poly([(25,35),(31,35),(32,29),(28,26),(24,29)],CYAN)
    c.rect(6,16,13,19,accent);c.rect(42,16,49,19,accent)
    c.rect(24,5,31,8,WHITE if variant else ORANGE)
    c.save(name)
fighter("enemy_scout.png",RED,ORANGE)
fighter("enemy_ace.png",(113,128,187,255),(205,202,235,255),1)

# Armored gunship (slow, wider, higher hit points)
c=Canvas(90,72)
c.poly([(45,68),(59,54),(61,43),(88,30),(83,11),(62,23),(54,5),(36,5),(28,23),(7,11),(2,30),(29,43),(31,54)],BLACK)
c.poly([(45,63),(55,51),(57,40),(82,28),(78,17),(59,29),(51,11),(39,11),(31,29),(12,17),(8,28),(33,40),(35,51)],(96,122,112,255))
c.rect(40,16,50,53,(176,196,159,255))
c.rect(19,30,34,38,(57,76,74,255));c.rect(56,30,71,38,(57,76,74,255))
c.ellipse(45,44,8,10,INK);c.ellipse(45,45,5,6,ORANGE)
c.rect(16,18,21,28,ORANGE);c.rect(69,18,74,28,ORANGE)
c.rect(37,11,52,14,LIGHT)
c.save("enemy_heavy.png")

# End-of-sector boss / aircraft carrier-sized dreadnought
c=Canvas(176,132)
c.poly([(88,128),(105,106),(124,92),(170,69),(173,27),(133,36),(117,9),(59,9),(43,36),(3,27),(6,69),(52,92),(71,106)],BLACK)
c.poly([(88,119),(100,99),(119,84),(161,63),(165,35),(127,46),(111,17),(65,17),(49,46),(11,35),(15,63),(57,84),(76,99)],(89,108,122,255))
c.poly([(88,113),(98,96),(105,29),(71,29),(78,96)],(142,169,172,255))
for x in [22,140]:
    c.rect(x,48,x+14,73,INK);c.rect(x+4,52,x+10,66,RED)
for x in [42,116]:
    c.rect(x,54,x+18,84,(43,68,83,255));c.ellipse(x+9,70,7,7,ORANGE)
c.poly([(78,65),(98,65),(110,86),(88,105),(66,86)],BLACK)
c.poly([(81,69),(95,69),(105,85),(88,99),(71,85)],RED)
c.rect(82,84,94,90,GOLD)
for x in [30,129]:
    c.rect(x,36,x+15,40,LIGHT)
c.rect(70,24,106,29,WHITE)
c.save("boss.png")

for name,col in [('laser.png',CYAN),('enemy_laser.png',RED),('boss_laser.png',ORANGE)]:
    c=Canvas(10,30)
    c.rect(1,4,8,25,(*col[:3],70))
    c.rect(3,1,6,28,col)
    c.rect(4,4,5,25,WHITE)
    c.save(name)

for name,col,symbol in [
    ("pickup_power.png",CYAN,"P"),("pickup_repair.png",(130,224,146,255),"+"),
    ("pickup_bomb.png",ORANGE,"B"),("pickup_shield.png",(146,177,255,255),"S")]:
    c=Canvas(32,32)
    c.poly([(16,1),(30,16),(16,30),(1,16)],BLACK)
    c.poly([(16,4),(27,16),(16,27),(4,16)],col)
    c.poly([(16,8),(24,16),(16,24),(8,16)],INK)
    if symbol=="+":
        c.rect(14,10,17,22,WHITE); c.rect(10,14,21,17,WHITE)
    elif symbol=="P":
        c.rect(11,10,14,22,WHITE); c.rect(14,10,19,13,WHITE);c.rect(17,13,20,17,WHITE);c.rect(14,17,19,19,WHITE)
    elif symbol=="B":
        c.rect(11,10,14,22,WHITE);c.rect(14,10,19,13,WHITE);c.rect(14,15,20,17,WHITE);c.rect(14,20,19,22,WHITE);c.rect(19,13,21,15,WHITE);c.rect(19,18,21,20,WHITE)
    else:
        c.rect(12,11,21,13,WHITE);c.rect(11,14,14,17,WHITE);c.rect(13,17,20,19,WHITE);c.rect(19,19,21,22,WHITE);c.rect(11,22,19,24,WHITE)
    c.save(name)

# Hand-pixelled insignia for home screen, no system icon fallback.
c=Canvas(1024,1024)
for y in range(1024):
    for x in range(1024):
        c.px(x,y,(10,20,34,255))
for y in range(128,910,72): c.rect(118,y,906,y+2,(21,40,57,255))
for x in range(130,914,72): c.rect(x,115,x+2,909,(21,40,57,255))
c.poly([(512,110),(578,292),(670,464),(892,577),(892,741),(645,700),(589,881),(435,881),(379,700),(132,741),(132,577),(354,464),(446,292)],BLACK)
c.poly([(512,138),(564,317),(654,484),(862,597),(858,700),(632,663),(575,841),(449,841),(392,663),(166,700),(162,597),(370,484),(460,317)],STEEL)
c.poly([(512,168),(548,345),(548,763),(512,816),(476,763),(476,345)],LIGHT)
c.poly([(479,414),(545,414),(593,524),(512,614),(431,524)],INK)
c.poly([(488,426),(536,426),(570,521),(512,580),(454,521)],CYAN)
c.rect(188,672,389,695,WHITE); c.rect(635,672,836,695,WHITE)
c.rect(449,812,482,895,ORANGE);c.rect(542,812,575,895,ORANGE)
c.rect(458,840,471,892,GOLD);c.rect(551,840,564,892,GOLD)
c.save("astra_icon.png")

def pcm(name, seconds, voices, gain=0.36):
    sr=22050
    frames=array.array('h')
    for i in range(int(sr*seconds)):
        t=i/sr
        s=0.0
        for wavefn in voices:
            s+=wavefn(t)
        s=max(-1,min(1,s*gain))
        frames.append(int(s*32767))
    with wave.open(str(ROOT/name),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(sr);f.writeframes(frames.tobytes())
    print("AUDIO",name,len(frames))

def env(t,d): return min(1,t*90)*max(0,1-t/d)**1.7 if t<d else 0
pcm("shoot.wav",0.12,[lambda t: math.sin(2*math.pi*(1100*t-420*t*t))*env(t,.12)])
pcm("hit.wav",0.18,[lambda t: (math.sin(2*math.pi*(180*t+45*t*t)) + .35*math.sin(2*math.pi*400*t))*env(t,.18)])
pcm("explode.wav",.55,[lambda t: ((random.Random(int(t*22050)).random()*2-1)*.6+math.sin(2*math.pi*(115*t-70*t*t))*.4)*env(t,.55)])
pcm("pickup.wav",.34,[lambda t: math.sin(2*math.pi*(490*t+630*t*t))*env(t,.34)])
pcm("click.wav",.1,[lambda t: math.sin(2*math.pi*670*t)*env(t,.1)])
pcm("bomb.wav",.9,[lambda t: (math.sin(2*math.pi*(80*t-15*t*t))+.5*math.sin(2*math.pi*145*t))*env(t,.9)])
pcm("warning.wav",.45,[lambda t: (math.sin(2*math.pi*360*t)+math.sin(2*math.pi*460*t))*.5*env(t,.45)])
# Original four-part chip theme with repeating 12-bar cadence.
notes=[220,261.63,293.66,329.63,293.66,261.63,196,246.94,261.63,329.63,392,329.63]
bass=[110,130.81,146.83,123.47]
def music(t):
    step=int(t/.27);local=t% .27
    f=notes[step%len(notes)]
    chirp=(1 if math.sin(2*math.pi*f*t)>=0 else -1)*(.18+ .12*min(1,local*23))*max(0,1-local/.27)
    b=bass[int(t/1.08)%len(bass)]
    low=math.sin(2*math.pi*b*t)*.16
    kick=(math.sin(2*math.pi*65*(t%.54))*max(0,1-(t%.54)/.15)**2)*.26
    return chirp+low+kick
pcm("music.wav",12.96,[music],1.0)
