#!/usr/bin/env python3
"""Summarize MarkRead [bench] logcat lines from platform_benchmark_hud.dart.

Usage:
  python3 scripts/summarize_bench_log.py /tmp/markread_bench.log
  adb logcat -d | python3 scripts/summarize_bench_log.py -

Prints per-label min/median/max for fps, hz, ui, rast, tot, rss, plus worst
frames and optional first-N sample windows (open hitch).
"""

from __future__ import annotations

import argparse
import re
import statistics
import sys
from collections import defaultdict
from typing import Iterable

LINE_RE = re.compile(
    r"\[bench\]\s+(?P<label>.+?)\s+"
    r"fps=(?P<fps>\d+)\s+"
    r"hz=(?P<hz>\S+)\s+"
    r"ui=(?P<ui>\S+)\s+"
    r"rast=(?P<rast>\S+)\s+"
    r"tot=(?P<tot>\S+)\s+"
    r"rss=(?P<rss>\S+)\s+"
    r"janky=(?P<janky>\S+)"
)


def parse_lines(lines: Iterable[str]) -> list[dict]:
    rows: list[dict] = []
    for line in lines:
        m = LINE_RE.search(line)
        if not m:
            continue
        rss_raw = m.group("rss")
        rss = None
        if rss_raw != "n/a":
            rss = float(rss_raw.replace("MB", "").replace("mb", ""))
        rows.append(
            {
                "label": m.group("label").strip(),
                "fps": int(m.group("fps")),
                "hz": float(m.group("hz")),
                "ui": float(m.group("ui")),
                "rast": float(m.group("rast")),
                "tot": float(m.group("tot")),
                "rss": rss,
                "janky": m.group("janky").lower() == "true",
                "raw": line.rstrip(),
            }
        )
    return rows


def _col(rows: list[dict], key: str) -> list[float]:
    out = []
    for r in rows:
        v = r[key]
        if v is None:
            continue
        out.append(float(v))
    return out


def summarize(name: str, rows: list[dict], worst_n: int = 5) -> None:
    if not rows:
        print(f"\n=== {name} ===\nNO DATA")
        return

    print(f"\n=== {name}  n={len(rows)} ===")
    for key in ("fps", "hz", "ui", "rast", "tot", "rss"):
        xs = _col(rows, key)
        if not xs:
            print(f"{key:5} n/a")
            continue
        print(
            f"{key:5} min={min(xs):.1f}  med={statistics.median(xs):.1f}  "
            f"max={max(xs):.1f}"
        )
    janky = sum(1 for r in rows if r["janky"])
    print(f"janky samples: {janky}/{len(rows)}")

    worst = sorted(rows, key=lambda r: r["tot"], reverse=True)[:worst_n]
    print(f"worst {len(worst)} by tot:")
    for r in worst:
        rss = "n/a" if r["rss"] is None else f"{r['rss']:.1f}MB"
        print(
            f"  fps={r['fps']:3d} hz={r['hz']:.0f} "
            f"ui={r['ui']:.1f} rast={r['rast']:.1f} tot={r['tot']:.1f} "
            f"rss={rss} janky={r['janky']}"
        )


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument(
        "path",
        help="log file path, or - for stdin",
    )
    ap.add_argument(
        "--first",
        type=int,
        default=10,
        help="also summarize first N samples per label (default 10)",
    )
    ap.add_argument(
        "--worst",
        type=int,
        default=5,
        help="how many worst frames to print (default 5)",
    )
    args = ap.parse_args()

    if args.path == "-":
        rows = parse_lines(sys.stdin)
    else:
        with open(args.path, encoding="utf-8", errors="replace") as f:
            rows = parse_lines(f)

    if not rows:
        print("No [bench] lines found.", file=sys.stderr)
        return 1

    by: dict[str, list[dict]] = defaultdict(list)
    for r in rows:
        by[r["label"]].append(r)

    print(f"total [bench] samples: {len(rows)}")
    print(f"labels: {', '.join(sorted(by))}")

    for label in sorted(by):
        subset = by[label]
        summarize(label, subset, worst_n=args.worst)
        if args.first > 0 and len(subset) > args.first:
            summarize(f"{label} · first {args.first}", subset[: args.first], worst_n=3)
            summarize(
                f"{label} · remaining",
                subset[args.first :],
                worst_n=3,
            )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
