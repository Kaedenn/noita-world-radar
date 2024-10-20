#!/usr/bin/env python3

"""
Generate the radar sprites drawn around the player

General usage:
  utility/build_radar_frames.py -o files/images/particles

Genrate a single set:
  utility/build_radar_frames.py \\
      -o files/images/particles \\
      -s item

Generate a single set using a custom color:
  utility/build_radar_frames.py \\
      -o files/images/particles \\
      -r 255 60 128 \\
      -s item
  utility/build_radar_frames.py \\
      -o files/images/particles \\
      -R 255 60 128 128 \\
      -s item
"""

import argparse
import logging
import os

from PIL import Image

logging.basicConfig(format="%(module)s:%(lineno)s: %(levelname)s: %(message)s",
                    level=logging.INFO)
logger = logging.getLogger(__name__)

# Enemy Radar perk: da4a16
# Item Radar perk: 4376ff
# Wand Radar perk: 39cd2b

COLORS = {
  "entity": (0xda, 0x4a, 0x16, 0xff),   # same as Enemy Radar perk
  "item": (0x43, 0x7f, 0xff, 0xff),     # same as Item Radar perk
  "material": (0xff, 0xff, 0x00, 0xff), # ffff00, yellow
  "spell": (0x39, 0xcd, 0x2b, 0xff),    # same as Wand Radar perk
}

FRAMES = {
  "far": "-------\n-------\n---+---\n--+x+--\n---+---\n-------\n-------",
  "faint": "-------\n---+---\n--+x+--\n-+x+x+-\n--+x+--\n---+---\n-------",
  "medium": "-------\n--+++--\n-+xxx+-\n-+x+x+-\n-+xxx+-\n--+++--\n-------",
  "strong": "---+---\n--+x+--\n-+x+x+-\n+x+x+x+\n-+x+x+-\n--+x+--\n---+---",
  "near": "+++++++\n+xxxxx+\n+x+++x+\n+x+x+x+\n+x+++x+\n+xxxxx+\n+++++++"
}

COLORMAP = {
  "-": (0x00, 0x00, 0x00, 0x00),
  "+": (0x00, 0x00, 0x00, 0x80),
  "x": (0xff, 0xff, 0xff, 0x00),
}

def main():
  ap = argparse.ArgumentParser()
  ap.add_argument("-o", "--outpath", metavar="PATH", default=os.curdir,
      help="write to %(metavar)s (default: current directory)")
  ap.add_argument("-s", "--set", metavar="NAME", choices=COLORS,
      help="limit to one set (default: all sets: %(choices)s)")
  mg = ap.add_mutually_exclusive_group()
  mg.add_argument("-r", "--rgb", nargs=3, metavar=("R", "G", "B"), type=int,
      help="override color (default: set color) (requires -s,--set)")
  mg.add_argument("-R", "--rgba", nargs=4, metavar=("R", "G", "B", "A"), type=int,
      help="override color (default: set color) (requires -s,--set)")
  ap.add_argument("-v", "--verbose", action="store_true",
      help="enable verbose output")
  args = ap.parse_args()
  if args.verbose:
    logger.setLevel(logging.DEBUG)

  if args.rgb or args.rgba:
    if not args.set:
      ap.error("-r,--rgb and -R,--rgba require -s,--set")

  if args.rgb:
    cr, cg, cb = args.rgb # pylint: disable=invalid-name
    COLORS[args.set] = (cr, cg, cb, 255)
  elif args.rgba:
    cr, cg, cb, ca = args.rgba # pylint: disable=invalid-name
    COLORS[args.set] = (cr, cg, cb, ca)

  set_list = list(COLORS.keys())
  if args.set:
    set_list = [args.set]

  for set_name in set_list:
    colormap = dict(COLORMAP)
    colormap["x"] = COLORS[set_name]
    for label, data in FRAMES.items():
      ofname = f"radar_{set_name}_{label}.png"
      rows = data.strip().splitlines()
      irows, icols = len(rows), len(rows[0])
      img = Image.new("RGBA", (icols, irows))
      for rnum, row in enumerate(rows):
        for cnum, col in enumerate(row):
          pcolor = colormap.get(col, (0x00, 0x00, 0x00, 0x00))
          img.putpixel((cnum, rnum), pcolor)
      image_path = os.path.join(args.outpath, ofname)
      logger.debug("Writing image to %s", image_path)
      img.save(image_path)

if __name__ == "__main__":
  main()

# vim: set ts=2 sts=2 sw=2:
