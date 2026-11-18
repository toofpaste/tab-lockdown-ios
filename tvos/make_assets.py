"""Package the established green lock design as tvOS layered brand assets.

Run locally with Pillow to regenerate. PNG output is committed, so CI needs no
image tooling. The shapes intentionally match the existing iPhone lock icon.
"""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).parent / 'App' / 'Assets.xcassets'
BRAND = ROOT / 'TVBrand.brandassets'
INFO = {'author': 'xcode', 'version': 1}
GREEN = (22, 101, 82)
MINT = (215, 247, 207)

def metadata(path, **values):
    path.mkdir(parents=True, exist_ok=True)
    (path / 'Contents.json').write_text(json.dumps(dict(info=INFO, **values), indent=2) + '\n')

def lock(size):
    # Draw at 4x to maintain smooth curves on the TV Home screen.
    w, h = size
    im = Image.new('RGBA', (w*4, h*4))
    d = ImageDraw.Draw(im)
    unit = h*4/240
    cx, cy = w*2, h*2
    def box(x1,y1,x2,y2): return (cx+x1*unit,cy+y1*unit,cx+x2*unit,cy+y2*unit)
    d.rounded_rectangle(box(-39,-72,39,20), radius=39*unit, fill=MINT)
    d.rounded_rectangle(box(-23,-55,23,20), radius=23*unit, fill=(0,0,0,0))
    d.rounded_rectangle(box(-58,-18,58,62), radius=16*unit, fill=MINT)
    d.ellipse(box(-10,6,10,26), fill=(0,0,0,0))
    d.rounded_rectangle(box(-5,18,5,40), radius=5*unit, fill=(0,0,0,0))
    return im.resize(size, Image.Resampling.LANCZOS)

metadata(ROOT)
assets = []
for name, size, scales in [('Small',(400,240),[1,2]), ('Large',(1280,768),[1])]:
    stack = BRAND / (name + '.imagestack')
    assets.append({'idiom':'tv','role':'primary-app-icon','size':f'{size[0]}x{size[1]}','filename':stack.name})
    metadata(stack, layers=[{'filename':x+'.imagestacklayer'} for x in ['Foreground','Background']])
    for layer in ['Foreground','Background']:
        folder = stack / (layer+'.imagestacklayer')
        metadata(folder)
        image_set = folder / 'Content.imageset'
        images = []
        for scale in scales:
            pixels = (size[0]*scale, size[1]*scale)
            image = lock(pixels) if layer == 'Foreground' else Image.new('RGB', pixels, GREEN)
            filename = f'icon-{scale}x.png'
            image_set.mkdir(parents=True, exist_ok=True)
            image.save(image_set/filename, optimize=True)
            images.append({'idiom':'tv','scale':f'{scale}x','filename':filename})
        metadata(image_set, images=images)

for name, size, role in [('TopShelf',(1920,720),'top-shelf-image'), ('TopShelfWide',(2320,720),'top-shelf-image-wide')]:
    folder = BRAND/(name+'.imageset')
    assets.append({'idiom':'tv','role':role,'size':f'{size[0]}x{size[1]}','filename':folder.name})
    images = []
    for scale in [1,2]:
        pixels = (size[0]*scale,size[1]*scale)
        image = Image.new('RGB',pixels,GREEN)
        symbol = lock((int(640*scale),int(640*scale)))
        image.paste(symbol, ((pixels[0]-symbol.width)//2, (pixels[1]-symbol.height)//2), symbol)
        folder.mkdir(parents=True,exist_ok=True)
        filename = f'shelf-{scale}x.png'; image.save(folder/filename,optimize=True)
        images.append({'idiom':'tv','scale':f'{scale}x','filename':filename})
    metadata(folder,images=images)
metadata(BRAND,assets=assets)

# Developer preview, outside the app bundle.
preview = Image.new('RGB',(800,480),GREEN)
preview.paste(lock((800,480)),(0,0),lock((800,480)))
preview.save(Path(__file__).parent/'icon-preview.png')
print('Generated tvOS Home icons and Top Shelf assets.')
