# Render branded promo from an actual AdaEditor recording.
# Usage: python3 render.py /folder/containing/unfold-raw-final.mp4
# Requires Pillow, ffmpeg, and macOS system fonts.
from pathlib import Path
import subprocess
import sys
from PIL import Image,ImageDraw,ImageFont
root=Path(sys.argv[1])
def font(size,mono=False):return ImageFont.truetype('/System/Library/Fonts/SFNSMono.ttf' if mono else '/System/Library/Fonts/Helvetica.ttc',size)
for step,title in enumerate(['01  REVEAL\nA second perspective.','02  INTERACT\nChange the same world.','03  KEEP PLAYING\nFold back. No restart.'],1):
 im=Image.new('RGBA',(1920,1080),(7,20,28,255));d=ImageDraw.Draw(im)
 d.rounded_rectangle((570,114,1861,1001),radius=12,fill='#183441')
 d.rectangle((576,120,1855,995),fill=(0,0,0,0))
 def text(x,y,s,size,color='#ECF8FA',mono=False):d.multiline_text((x,y),s,font=font(size,mono),fill=color,spacing=12)
 text(80,60,'ADAEDITOR  /  FOLDABLE PREVIEW',19,'#50EACB')
 d.rectangle((80,108,180,111),fill='#50EACB')
 text(76,154,'Unfold\nthe screen.',68)
 text(80,360,'Unlock another\nway to play.',34,'#A4C3CF')
 text(80,550,title,22,'#50EACB')
 d.rounded_rectangle((64,708,520,892),radius=12,fill='#102A36')
 text(82,727,'AVAILABLE IN SWIFT + ADASCRIPT',14,'#86AEBE')
 text(82,762,'@res var display: DisplayLayout;\n\ndisplay.isExpanded\ndisplay.secondary',17,mono=True)
 text(80,946,'Try the UnfoldTheWorld demo',23)
 text(80,1030,'Experimental layout simulation  /  Recorded in AdaEditor',16,'#7299AA')
 text(576,64,'ONE SCENE. TWO WAYS TO PLAY.',18,'#86AEBE')
 im.save(root/f'card-{step}.png')
f="[0:v]crop=1422:974:234:62,scale=1280:876,setsar=1,pad=1920:1080:576:120:color=0x07141C[base];[base][1:v]overlay=0:0:enable='lt(t,7)':shortest=1[a];[a][2:v]overlay=0:0:enable='between(t,7,15)':shortest=1[b];[b][3:v]overlay=0:0:enable='gte(t,15)':shortest=1"
(root/'promo-filter.txt').write_text(f)
cmd=['ffmpeg','-y','-v','error','-i',str(root/'unfold-raw-final.mp4')]
for n in range(1,4):cmd+=['-loop','1','-i',str(root/f'card-{n}.png')]
cmd+=['-filter_complex',f,'-t','30','-r','30','-c:v','libx264','-preset','fast','-crf','18','-pix_fmt','yuv420p','-movflags','+faststart',str(root/'unfold-promo.mp4')]
subprocess.run(cmd,check=True)
subprocess.run(['ffmpeg','-y','-v','error','-ss','6','-t','7','-i',str(root/'unfold-promo.mp4'),'-filter_complex','fps=8,scale=960:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=sierra2_4a','-loop','0',str(root/'unfold-demo.gif')],check=True)
subprocess.run(['ffmpeg','-y','-v','error','-ss','10','-i',str(root/'unfold-promo.mp4'),'-frames:v','1',str(root/'unfold-cover.png')],check=True)
print('Promo, GIF and cover exported.')
