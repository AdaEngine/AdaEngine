# Requires Python + Pillow, ffmpeg and macOS system fonts.
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import subprocess
import sys
root=Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).parent)
def font(n,mono=False):return ImageFont.truetype('/System/Library/Fonts/SFNSMono.ttf' if mono else '/System/Library/Fonts/Helvetica.ttc',n)
steps=['01  SHAPE A PATH\nBend the screen.','02  CROSS THE FOLD\nOne world, two surfaces.','03  THE OTHER SIDE\nBring a prism inside.','04  FIND THE WAY\nYour shadow is the bridge.']
for i,step in enumerate(steps,1):
 im=Image.new('RGBA',(1920,1080),(24,38,57,255));d=ImageDraw.Draw(im)
 d.rounded_rectangle((570,94,1861,1017),radius=12,fill='#425369');d.rectangle((576,100,1855,1011),fill=(0,0,0,0))
 def text(x,y,s,n,c='#F2E9D5',mono=False):d.multiline_text((x,y),s,font=font(n,mono),fill=c,spacing=12)
 text(80,60,'ADAEDITOR  /  SHADOW FOLD',19,'#DBC394');d.rectangle((80,108,180,111),fill='#D4B681')
 text(76,154,'Fold\nthe light.',68);text(80,360,'Walk on the\nshadows you make.',34,'#BACAD0');text(80,550,step,22,'#96CABD')
 d.rounded_rectangle((64,708,520,892),radius=12,fill='#293C52');text(82,727,'SWIFT + ADASCRIPT',14,'#BACAD0')
 text(82,770,'FoldPose(angle: 90)\n\nFoldSurface.outer',19,mono=True)
 text(80,946,'Try the ShadowFold demo',23);text(80,1030,'Experimental device simulation / Recorded in AdaEditor',16,'#94ABBC')
 im.save(root/f'card-{i}.png')
f='[0:v]crop=1330:948:234:86,scale=1280:912,setsar=1,pad=1920:1080:576:100:color=0x182639[b0]'
conditions=['lt(t,7)','between(t,7,11)','between(t,11,20)','gte(t,20)']
for i,c in enumerate(conditions,1):f+=f";[b{i-1}][{i}:v]overlay=0:0:enable='{c}':shortest=1[b{i}]"
cmd=['ffmpeg','-y','-v','error','-i',str(root/'shadow-fold-raw.mp4')]
for i in range(1,5):cmd+=['-loop','1','-i',str(root/f'card-{i}.png')]
cmd+=['-filter_complex',f,'-map','[b4]','-t','30','-r','30','-c:v','libx264','-preset','fast','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(root/'shadow-fold.mp4')]
subprocess.run(cmd,check=True)
subprocess.run(['ffmpeg','-y','-v','error','-ss','8','-i',str(root/'shadow-fold.mp4'),'-frames:v','1',str(root/'shadow-fold-cover.png')],check=True)
print('Rendered Shadow Fold promo.')
