#!/usr/bin/env bash
set -eo pipefail
source /opt/ros/humble/setup.bash
source /opt/roscon/ws/install/setup.bash
set -u

mode="${1:?Expected cpu or gpu}"
choice="${2:?Expected vine or footpath}"
case "$choice" in
  vine)
    recording=out_vine_1push_3carry_st_ly_11_06_2024_1_label
    ;;
  footpath)
    recording=footpath1_p1_oj+mk+gl_1walk+check_st_11_12_2024_1_label
    ;;
  *) echo "Unknown bag: $choice" >&2; exit 2 ;;
esac
bag="/data/bags/$choice"
cache_root="/data/caches/$choice"
diagnostics="/output/${mode}_${choice}_diagnostics.jsonl"
package=/opt/roscon/ws/install/late_fusion_pkg/share/late_fusion_pkg
rviz="${ROSCON_LAUNCH_RVIZ:-${ROSCON_RVIZ:-true}}"
rate="${ROSCON_PLAYBACK_RATE:-1.0}"

if [[ "$rviz" == true && -z "${DISPLAY:-}" ]]; then
  echo 'ROSCON_RVIZ=true requires DISPLAY; set ROSCON_RVIZ=false for headless use.' >&2
  exit 2
fi
if [[ ! -f "$bag/metadata.yaml" ]]; then
  echo "AGHRI bag missing at $bag" >&2
  exit 2
fi
: > "$diagnostics"

if [[ "$mode" == cpu ]]; then
  test -f "$cache_root/yolo_finetuned/detections.csv"
  test -f "$cache_root/pointpillars_finetuned/detections.csv"
  echo 'ROSCon CPU mode: cached YOLO11s + PointPillars, live fusion + DeepFusionMOT'
  exec ros2 launch late_fusion_pkg aghri_generic_late_fusion.launch.py \
    bag_path:="$bag" recording_name:="$recording" \
    camera_model:=finetuned lidar_detector:=pointpillars lidar_model:=finetuned \
    detector_profile:=custom \
    YOLO_cache:="$cache_root/yolo_finetuned/detections.csv" \
    SECOND_cache:="$cache_root/pointpillars_finetuned/detections.csv" \
    fusion_config:="$package/config/aghri_generic_late_fusion.yaml" \
    visualization_config:="$package/config/aghri_visualization.yaml" \
    rviz_config:="$package/rviz/aghri_generic_late_fusion.rviz" \
    qos_overrides:=/opt/roscon/qos.yaml diagnostics_output:="$diagnostics" \
    enable_visualisation:=true launch_rviz:="$rviz" \
    show_original_lidar_markers:=true show_tracked_markers:=true \
    show_tracked_projection_image:=true bag_start_delay_sec:=12.0 \
    playback_rate:="$rate"
elif [[ "$mode" == gpu ]]; then
  test -f /models/yolo11s_best.pt
  test -f /models/pointpillars_best.pth
  echo 'ROSCon GPU mode: live YOLO11s + PointPillars, live fusion + DeepFusionMOT'
  exec ros2 launch late_fusion_pkg aghri_online_late_fusion.launch.py \
    bag_path:="$bag" camera_model:=finetuned \
    lidar_detector:=pointpillars lidar_model:=finetuned \
    fusion_config:="$package/config/aghri_generic_late_fusion.yaml" \
    visualization_config:="$package/config/aghri_visualization.yaml" \
    rviz_config:="$package/rviz/aghri_generic_late_fusion.rviz" \
    qos_overrides:=/opt/roscon/qos.yaml diagnostics_output:="$diagnostics" \
    yolo_python:=/usr/bin/python3 worker_python:=/usr/bin/python3 \
    detector_device:=cuda:0 mmdet3d_device:=cuda:0 \
    enable_tracking:=true enable_visualisation:=true launch_rviz:="$rviz" \
    bag_start_delay_sec:="${ROSCON_BAG_START_DELAY_GPU:-18.0}" playback_rate:="$rate"
else
  echo "Unknown mode: $mode" >&2
  exit 2
fi
