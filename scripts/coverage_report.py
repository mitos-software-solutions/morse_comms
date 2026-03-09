#!/usr/bin/env python3
"""
Parse coverage/lcov.info and print a coverage summary.
Run after: flutter test --coverage

Usage:
    python3 scripts/coverage_report.py
"""

import os
import re
import sys

LCOV_PATH = os.path.join(os.path.dirname(__file__), "..", "coverage", "lcov.info")


def parse_lcov(path: str):
    hits = 0
    total = 0
    file_stats: dict[str, dict] = {}
    current_file = None

    with open(path) as f:
        for line in f:
            line = line.strip()
            if line.startswith("SF:"):
                raw = line[3:]
                current_file = raw.split("lib/")[-1] if "lib/" in raw else raw
                file_stats[current_file] = {"hit": 0, "found": 0}
            elif line.startswith("LH:"):
                v = int(line[3:])
                hits += v
                if current_file:
                    file_stats[current_file]["hit"] = v
            elif line.startswith("LF:"):
                v = int(line[3:])
                total += v
                if current_file:
                    file_stats[current_file]["found"] = v

    return hits, total, file_stats


def badge_color(pct: float) -> str:
    if pct >= 90:
        return "brightgreen"
    if pct >= 75:
        return "yellow"
    if pct >= 60:
        return "orange"
    return "red"


def main():
    if not os.path.exists(LCOV_PATH):
        print("coverage/lcov.info not found. Run: flutter test --coverage")
        sys.exit(1)

    hits, total, file_stats = parse_lcov(LCOV_PATH)
    pct = hits / total * 100 if total else 0
    color = badge_color(pct)

    print(f"\n{'='*60}")
    print(f"  Coverage: {hits}/{total} lines  ({pct:.1f}%)")
    print(f"{'='*60}\n")

    rows = [(f, s["hit"], s["found"]) for f, s in file_stats.items() if s["found"] > 0]
    rows.sort(key=lambda r: r[1] / r[2])

    print(f"{'File':<58} {'Hit':>5} {'Fnd':>5} {'%':>5}")
    print("-" * 76)
    for fname, h, fo in rows:
        bar = "#" * int(h / fo * 20)
        print(f"{fname:<58} {h:>5} {fo:>5} {h/fo*100:>4.0f}%  [{bar:<20}]")

    print(f"\nShields.io badge URL:")
    encoded_pct = f"{pct:.0f}%25"
    print(f"  ![Coverage](https://img.shields.io/badge/coverage-{encoded_pct}-{color})")
    print()


if __name__ == "__main__":
    main()
