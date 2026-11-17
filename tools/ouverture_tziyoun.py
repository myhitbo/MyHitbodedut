"""L'image d'ouverture : python3 tools/ouverture_tziyoun.py tools/sources-images/heikhal_tziyoun_facade.jpg android/app/src/main/res/drawable-nodpi/scene_ouverture_tombe.webp"""
import sys
from PIL import Image, ImageDraw, ImageFilter
src = Image.open(sys.argv[1]).convert('RGB')
k = src.width / 1024
# La façade du היכל הציון et son enseigne (coordonnées dans la photo de 1024 px de large).
x0, y0, x1, y1 = 215, 0, 775, 640
crop = src.crop((int(x0*k), int(y0*k), int(x1*k), int(y1*k)))
W, H = 900, 2000
band = crop.resize((W, round(crop.height * W / crop.width)), Image.LANCZOS)
band = band.filter(ImageFilter.UnsharpMask(radius=2, percent=60, threshold=2))
top = 230
fond = Image.new('RGB', (W, H), (0x1E, 0x3A, 0x30))
# Le ciel prolongé vers le haut : le haut de la photo, colonne par colonne, plus profond au sommet.
fh, fb = 90, 260
h = top + fh
rang = band.crop((0, 0, W, 6)).resize((W // 30, 1), Image.BOX).resize((W, 1), Image.BILINEAR)
ciel = rang.resize((W, h), Image.NEAREST)
moyen = rang.resize((1, 1), Image.BOX).getpixel((0, 0))
profond = Image.new('RGB', (W, h), (round(moyen[0] * 0.62), round(moyen[1] * 0.74), round(moyen[2] * 0.92)))
degrade = Image.linear_gradient('L').rotate(180).resize((W, h))
fond.paste(Image.composite(profond, ciel, degrade), (0, 0))
mask = Image.new('L', band.size, 255)
d = ImageDraw.Draw(mask)
for i in range(fh):
    d.line([(0, i), (W, i)], fill=round(255 * i / fh))
for i in range(fb):
    d.line([(0, band.height-1-i), (W, band.height-1-i)], fill=round(255 * i / fb))
fond.paste(band, (0, top), mask)
fond.save(sys.argv[2], 'WEBP', quality=84, method=6)
print(band.size, top, top+band.height)
