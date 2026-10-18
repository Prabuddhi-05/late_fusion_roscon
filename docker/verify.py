#!/usr/bin/env python3
"""Check that a completed workshop replay used both detectors and downstream nodes."""

import argparse
from collections import defaultdict
import json
from pathlib import Path


def accepted_match_count(fusion_events):
    total = 0
    for data in fusion_events:
        fields = dict(part.split("=", 1) for part in data.split(",") if "=" in part)
        if "matches" not in fields:
            raise ValueError(f"fusion diagnostic has no matches count: {data}")
        total += int(fields["matches"])
    return total


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("cpu", "gpu"))
    parser.add_argument("--bag", choices=("vine", "footpath"), default="vine")
    parser.add_argument("--output", type=Path, default=Path("output"))
    args = parser.parse_args()
    path = args.output / f"{args.mode}_{args.bag}_diagnostics.jsonl"
    by_source = defaultdict(list)
    for line in path.read_text().splitlines():
        event = json.loads(line)
        try:
            payload = json.loads(event["data"])
        except json.JSONDecodeError:
            payload = event["data"]
        by_source[event["source"]].append(payload)

    if args.mode == "cpu":
        expected_frames = {"vine": (192, 132), "footpath": (262, 200)}[args.bag]
        for source, expected in zip(("camera_cache", "lidar_cache"), expected_frames):
            events = by_source[source]
            assert len(events) == expected, (source, len(events), expected)
            assert events[-1]["hits"] == expected and events[-1]["misses"] == 0
        assert not by_source["camera_live"] and not by_source["lidar_live"]
    else:
        for source in ("camera_live", "lidar_live"):
            assert by_source[source], f"missing {source} inference diagnostics"
        assert not by_source["camera_cache"] and not by_source["lidar_cache"]

    assert by_source["fusion"], "no late fusion updates"
    assert by_source["tracking"], "no DeepFusionMOT updates"
    assert any(item.get("tracked_3d", 0) > 0 for item in by_source["tracking"]), "no 3D tracks"
    assert any(item.get("source") == "tracked_boxes" for item in by_source["visualization"]), "no tracked markers"
    for source in ("camera_cache", "lidar_cache", "camera_live", "lidar_live", "fusion", "tracking"):
        if by_source[source]:
            print(f"{source}: {len(by_source[source])}")
    print(f"accepted camera-LiDAR matches: {accepted_match_count(by_source['fusion'])} (sum across fusion updates)")
    print(f"{args.mode} {args.bag} pipeline: PASS")


if __name__ == "__main__":
    main()
