from PIL import Image
im = Image.open(r"game/assets/art/characters/mansour_walk.png").convert("RGBA")
f = 64 * 2          # frame size x sprite_scale
row = 2             # walk_rows["down"]
still = im.crop((0, row * f, f, row * f + f))
bb = still.getbbox()
print("frame size      :", still.size)
print("opaque bbox     :", bb)
print("head top frac   :", round(bb[1] / still.size[1], 3))
print("figure h frac   :", round((bb[3] - bb[1]) / still.size[1], 3))
# Where a head-and-shoulders crop should actually start and end.
top = bb[1]
head_h = int((bb[3] - bb[1]) * 0.38)
print("suggested crop  :", (bb[0], top, bb[2], top + head_h))
