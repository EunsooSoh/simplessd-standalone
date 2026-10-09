#!/usr/bin/env python3
"""Nexus 5 BIOTracer trace -> blkparse-style text for SimpleSSD-standalone.

Input columns (tab separated):
  LSN(512B sector), length(sectors), bytes, flag, t1, t2, t3, t4
Per the BIOTracer Readme: flag bit0 = write (1,5) / read (0,4), t1 is the
request generation time, and the mmc driver may add extra sectors to the size,
so the length is rounded down to a multiple of 8 sectors (4KB, minimum 8).

Output line (matches the Regex in config/sample.cfg):
  8,0 0 <seq> <sec>.<nsec> 0 D <R|W> <LSN> + <len>
Time is relative to the first request and sorted by arrival time.

Usage: convert_nexus5.py <input dir> <output dir>
"""
import os
import sys


def convert(src, dst):
    reqs = []
    with open(src) as f:
        for line in f:
            p = line.split()
            if len(p) < 5:
                continue
            reqs.append((p[4], int(p[0]), max(8, int(p[1]) // 8 * 8), int(p[3]) & 1))

    # Python's decimal timestamps are strings: keep integer ns to avoid float error
    def ns(t):
        sec, _, frac = t.partition(".")
        return int(sec) * 10**9 + int((frac + "000000000")[:9])

    reqs = sorted(((ns(t), lsn, n, w) for t, lsn, n, w in reqs),
                  key=lambda r: r[0])
    if not reqs:
        return None

    t0 = reqs[0][0]
    writes = wbytes = w4k = 0
    max_lsn = 0

    with open(dst, "w", newline="\n") as out:
        for i, (t, lsn, n, w) in enumerate(reqs, 1):
            rel = t - t0
            out.write("8,0 0 %d %d.%09d 0 D %s %d + %d\n" %
                      (i, rel // 10**9, rel % 10**9, "W" if w else "R", lsn, n))
            max_lsn = max(max_lsn, lsn + n)
            if w:
                writes += 1
                wbytes += n * 512
                w4k += n == 8

    return len(reqs), writes, wbytes, w4k, max_lsn, (reqs[-1][0] - t0) / 1e9


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)

    src_dir, dst_dir = sys.argv[1:]
    os.makedirs(dst_dir, exist_ok=True)

    print("%-28s %8s %8s %9s %6s %9s %8s" %
          ("file", "reqs", "writes", "writeMiB", "4K%", "maxGiB", "sec"))

    for name in sorted(os.listdir(src_dir)):
        if not name.endswith(".txt"):
            continue

        r = convert(os.path.join(src_dir, name),
                    os.path.join(dst_dir, "converted_" + name))
        if r is None:
            continue

        n, w, wb, w4k, mx, dur = r
        print("%-28s %8d %8d %9.1f %6.1f %9.2f %8.1f" %
              (name, n, w, wb / 2**20, 100.0 * w4k / max(w, 1),
               mx * 512 / 2**30, dur))


main()
