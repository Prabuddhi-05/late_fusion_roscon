#!/usr/bin/env bash
set -euo pipefail

bag="${1:-vine}"
mode="${ROSCON_MODE:-}"
if [[ "$bag" != vine && "$bag" != footpath ]]; then
  echo 'Usage: bash run.sh [vine|footpath]' >&2
  exit 2
fi
if [[ "$mode" != cpu && "$mode" != gpu ]]; then
  echo 'Run this command inside the ROSCon CPU or GPU VS Code Dev Container.' >&2
  exit 2
fi

[[ -f "/data/bags/$bag/metadata.yaml" ]] || {
  echo "Missing bag: /data/bags/$bag (download the shared data folder first)." >&2; exit 2;
}
if [[ "$mode" == cpu ]]; then
  for detector in yolo_finetuned pointpillars_finetuned; do
    [[ -f "/data/caches/$bag/$detector/detections.csv" ]] || {
      echo "Missing cache: /data/caches/$bag/$detector/detections.csv" >&2; exit 2;
    }
  done
else
  for checkpoint in yolo11s_best.pt pointpillars_best.pth; do
    [[ -f "/models/$checkpoint" ]] || {
      echo "Missing checkpoint: /models/$checkpoint" >&2; exit 2;
    }
  done
  /usr/bin/python3 -c 'import torch; assert torch.cuda.is_available(), "CUDA is unavailable in this container"'
fi

bash /opt/roscon/pipeline.sh "$mode" "$bag"
python3 /opt/roscon/verify.py "$mode" --bag "$bag" --output /output
