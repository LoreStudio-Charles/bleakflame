"""Drop a generated ship sprite into assets/ships/ with the right orientation.

    python tools/place_ship_art.py <downloaded.png> <hull-name> [--rotate cw|ccw|180|none]

    python tools/place_ship_art.py ~/Downloads/frame_07.png harrier --rotate cw

THE CONVENTION IT ENFORCES: hull art noses +X (RIGHT). PixelLab generates these
nose-UP however firmly the prompt asks otherwise, so they need a lossless 90
degree CLOCKWISE turn. Get it wrong and the ship flies sideways in combat and
sits rotated on the paperdoll -- which is exactly what happened to the
Sparrowhawk (authored nose-DOWN, found only because its variant skins disagreed).

Rotation is by whole right angles, so it is pixel-exact: no resampling, no
blurring, no palette drift.

SIZE IS NOT CRITICAL. BuildShip scales any sprite to its hull's size-band budget
(LIGHT 32 / MEDIUM 64 / HEAVY 128 / SUPER_HEAVY 256 px canvases, 2x the band px),
so an off-size canvas scales to fit rather than breaking. This warns when it
looks unintended, and does not refuse.

Hull name is the display name in snake_case -- harrier, goshawk, dray,
bellwether -- because that is the file BuildShip looks for. Pass a path with a
slash instead (galean-navy/cruiser-3) to use the faction-folder convention, which
needs HullDef.art_path pointed at it.
"""
import argparse
import os
import sys

from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHIPS = os.path.join(REPO, 'assets', 'ships')

# Size-band canvases, for the sanity warning only.
BAND_PX = {32: 'LIGHT', 64: 'MEDIUM', 128: 'HEAVY', 256: 'SUPER_HEAVY'}
TURNS = {'cw': -90, 'ccw': 90, '180': 180, 'none': 0}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('source', help='the downloaded PNG')
    ap.add_argument('hull', help='snake_case hull name, or faction/file')
    ap.add_argument('--rotate', choices=sorted(TURNS), default='cw',
                    help='whole right angles only (default: cw, for nose-up art)')
    ap.add_argument('--force', action='store_true', help='overwrite existing art')
    args = ap.parse_args()

    if not os.path.isfile(args.source):
        print('no such file: %s' % args.source)
        return 1

    dst = os.path.join(SHIPS, args.hull.replace('/', os.sep) + '.png')
    if os.path.exists(dst) and not args.force:
        print('%s already exists -- pass --force to replace it' % dst)
        return 1

    img = Image.open(args.source).convert('RGBA')
    turn = TURNS[args.rotate]
    if turn:
        img = img.rotate(turn, expand=True)

    w, h = img.size
    if w != h:
        print('note: %dx%d is not square; it will scale on its width' % (w, h))
    elif w not in BAND_PX:
        near = min(BAND_PX, key=lambda b: abs(b - w))
        print('note: %dpx is not a standard canvas (nearest: %dpx = %s). It will '
              'still scale to its band.' % (w, near, BAND_PX[near]))

    os.makedirs(os.path.dirname(dst), exist_ok=True)
    img.save(dst)
    print('wrote %s  (%dx%d, rotated %s)' % (dst, w, h, args.rotate))
    print('Nose must point RIGHT. Open it and check before flying -- rotation is '
          'the one thing nothing downstream can detect for you.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
