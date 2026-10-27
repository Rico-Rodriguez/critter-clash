#!/usr/bin/env python3
"""Reads the ortho silhouettes `petlineup --solo=SP --ortho=front|side` writes
(600x600, magenta bg, 200 px/m, row 300 = y 1.0, side camera at +x so column
increase = z decrease) and prints each species' frame in model metres, the data
pet_gen.gd FRAMES bakes. usage: pet_frames.py DIR"""
import sys, glob, os
import numpy as np
from PIL import Image

PX, CY = 200.0, 300.0

def mask(path):
    a = np.asarray(Image.open(path).convert("RGB")).astype(int)
    bg = a[0, 0]
    return (np.abs(a - bg).sum(axis=2) > 40)

def main(d):
    for f in sorted(glob.glob(os.path.join(d, "petlineup_*_side.png"))):
        sp = os.path.basename(f)[len("petlineup_"):-len("_side.png")]
        s = mask(f); fr = mask(f.replace("_side", "_front"))
        ys, xs = np.nonzero(s)
        top = 1 - (ys.min() - CY) / PX; bot = 1 - (ys.max() - CY) / PX
        zf = (300 - xs.min()) / PX; zb = (300 - xs.max()) / PX
        ys2, xs2 = np.nonzero(fr)
        hw = max(abs(xs2.min() - 300), abs(xs2.max() - 300)) / PX
        # head: top-most pixel row within the front 30% of the z span; upright top-most overall
        span = xs.max() - xs.min()
        fm = xs <= xs.min() + span * 0.25
        hy = 1 - (ys[fm].min() - CY) / PX
        hz = (300 - xs[fm][np.argmin(ys[fm])]) / PX
        ty = 1 - (ys[xs.argmax()] - CY) / PX
        print(f"{sp:14s} top {top:5.2f} bot {bot:5.2f} zf {zf:5.2f} zb {zb:5.2f} hw {hw:5.2f} head({hy:5.2f},{hz:5.2f}) tail y {ty:5.2f}")

main(sys.argv[1] if len(sys.argv) > 1 else "/tmp/wtb/fr")
