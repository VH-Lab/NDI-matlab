#!/usr/bin/env python3
"""Combined "tests" badge for the NDI-matlab CI runs.

The unit tests are split across several CI jobs (the no-cloud run and the
Cloud CI shards). Each job records its own counts, and the badge shows the
sum of the latest counts from every job.

  counts  Read a JUnit XML report and write one job's counts as JSON.
  badge   Sum every counts file in a folder and write a shields.io endpoint
          JSON (https://shields.io/badges/endpoint-badge) for the badge.

Only the Python standard library is used, so the script runs on a bare
GitHub Actions runner.
"""

import argparse
import json
import os
import sys
import xml.etree.ElementTree as ET

# Every job whose counts make up the badge. A job missing from the folder,
# or whose counts come from an older commit than the newest one there,
# marks the badge "(partial)".
EXPECTED_PARTS = ("nocloud", "cloud-1", "cloud-2", "cloud-3")


def junit_counts(path):
    """Return (tests, failed, skipped) from a JUnit XML report.

    Counts <testcase> elements, so it works whether the root element is
    <testsuites> or a single <testsuite>. A test case with a <failure> or
    <error> child counts as failed; one with a <skipped> child (MATLAB's
    incomplete tests) counts as skipped.
    """
    root = ET.parse(path).getroot()
    tests = failed = skipped = 0
    for case in root.iter("testcase"):
        tests += 1
        if case.find("failure") is not None or case.find("error") is not None:
            failed += 1
        elif case.find("skipped") is not None:
            skipped += 1
    return tests, failed, skipped


def badge_color_message(num_tests, num_passed, num_failed):
    """Badge color and message; mirrors nditools.testBadgeColorMessage."""
    if num_tests == 0:
        return "red", "no tests"
    if num_failed == 0:
        return "green", f"{num_passed} passed"
    message = f"{num_passed}/{num_tests} passed"
    if num_failed / num_tests < 0.05:
        return "yellow", message
    return "red", message


def combine(parts, expected=EXPECTED_PARTS):
    """Sum a {name: counts} mapping into a shields.io endpoint dict.

    The newest commit among the parts (by commit time) is taken as current.
    If any expected part is missing or comes from an older commit, the
    message ends in "(partial)"; the counts are still summed, so the badge
    keeps showing the last known state of every job.
    """
    tests = failed = skipped = 0
    for counts in parts.values():
        tests += counts["tests"]
        failed += counts["failed"]
        skipped += counts["skipped"]
    passed = tests - failed - skipped
    color, message = badge_color_message(tests, passed, failed)

    newest = max((c["commit_time"], c["sha"]) for c in parts.values())[1] if parts else None
    complete = all(name in parts and parts[name]["sha"] == newest for name in expected)
    if not complete:
        message += " (partial)"
    return {"schemaVersion": 1, "label": "tests", "message": message, "color": color}


def cmd_counts(args):
    tests, failed, skipped = junit_counts(args.junit)
    counts = {
        "part": args.part,
        "sha": args.sha,
        "commit_time": int(args.commit_time),
        "tests": tests,
        "failed": failed,
        "skipped": skipped,
    }
    with open(args.out, "w") as f:
        json.dump(counts, f, indent=2)
        f.write("\n")
    print(f"{args.part}: {tests} tests, {failed} failed, {skipped} skipped")


def cmd_badge(args):
    parts = {}
    for name in sorted(os.listdir(args.dir)):
        if name.endswith(".json"):
            with open(os.path.join(args.dir, name)) as f:
                counts = json.load(f)
            parts[counts["part"]] = counts
    badge = combine(parts)
    with open(args.out, "w") as f:
        json.dump(badge, f, indent=2)
        f.write("\n")
    print(f"badge: {badge['message']} ({badge['color']})")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("counts", help="write one job's counts from a JUnit report")
    p.add_argument("--junit", required=True)
    p.add_argument("--part", required=True)
    p.add_argument("--sha", required=True)
    p.add_argument("--commit-time", required=True)
    p.add_argument("--out", required=True)
    p.set_defaults(func=cmd_counts)

    p = sub.add_parser("badge", help="sum the counts in a folder into the badge")
    p.add_argument("--dir", required=True)
    p.add_argument("--out", required=True)
    p.set_defaults(func=cmd_badge)

    args = parser.parse_args(argv)
    args.func(args)


if __name__ == "__main__":
    sys.exit(main())
