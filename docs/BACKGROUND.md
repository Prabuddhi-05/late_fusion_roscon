# Workshop background: AGHRI and DeepFusionMOT

This page provides a short introduction for the demo and a closer look at the data and tracking pipeline. The [main README](../README.md) has the setup commands and activities.

## Slide 1 — AGHRI Dataset (about 1 minute)

- **AGHRI** is a multimodal dataset for sensing people around agricultural robots, developed at the University of Lincoln.
- It covers four environments: **strawberry polytunnels, vineyards, footpaths, and farmsides**.
- The robot records **ZED RGB-D**, **three fisheye cameras**, and **3D LiDAR**, with calibration and motion metadata.
- People walk, stand, inspect the robot, push trolleys, carry trays, and work among crops. Conditions include sun, overcast skies, some snow, and occlusion.
- The release provides **2D camera boxes, 3D LiDAR cuboids, person identities, and front-ZED occlusion events** for detection and tracking research.
- **Today's demo uses the ZED RGB camera and Livox LiDAR** from two selected recordings: `footpath` and `vine`.

[Watch the two-minute AGHRI dataset video](https://www.youtube.com/watch?v=nL7mKnMcCzc). The [AGHRI dataset page](https://doi.org/10.24385/lincoln.32982638) describes the full release; the workshop download contains only the selected bags, caches, and checkpoints.

### Dataset overview

AGHRI supports research on **2D and 3D human detection**, **2D and 3D multi-object tracking**, **person re-identification**, and **camera–LiDAR fusion**. The full release contains many sequences; the workshop uses one footpath and one vineyard recording.

### Robotic platform and sensors

AGHRI was collected on an **Agilex Hunter 2.0** with a **ZED 2 RGB-D camera**, three **Arducam fisheye cameras**, and a **Livox Mid-360 LiDAR**.

![AGHRI robotic platform and sensors](background/aghri_platform.png)

The modalities capture different views of the same scene: RGB appearance, depth, wide-angle fisheye images, and a 3D point cloud.

![Examples of synchronised AGHRI sensor data](background/aghri_modalities.png)

### Collection environments and activities

![Polytunnel, vineyard, footpath, and farmside scenes](background/aghri_environments.png)

The recordings include single- and multi-person scenes. People walk, stand, talk, check the robot, push trolleys, carry trays, and pick fruit. The robot may be stationary or moving.

### Annotations

The camera annotations mark people with **2D boxes and identities** in the ZED RGB and fisheye views. The LiDAR annotations mark people with **3D boxes and identities**. The front-ZED occlusion log records partial, total, and out-of-frame visibility events. ZED depth is provided as sensor data but is not one of the annotated modalities.

A dataset identity is ground truth; a number assigned by DeepFusionMOT during this demo is a separate tracker ID.

## Slide 2 — DeepFusionMOT (about 2 minutes)

- **Goal:** detect multiple people and keep their identities over time using camera and LiDAR.
- **YOLO11s** finds people as 2D boxes in the ZED RGB image.
- **PointPillars** finds people as 3D cuboids in the LiDAR point cloud.
- **Late fusion** decides which camera and LiDAR detections describe the same person.
- The **AGHRI DeepFusionMOT adaptation** associates detections with existing tracks and assigns persistent IDs.
- **RViz2** shows the camera boxes, LiDAR proposals, matches, unmatched proposals, and tracks.

In **GPU mode**, both detectors run on each replayed sensor stream. In **CPU mode**, their saved predictions are replayed. Fusion and tracking run live in both modes.

The original DeepFusionMOT research uses a camera–LiDAR tracking framework; this workshop uses its AGHRI adaptation for people.

### Figure 1: AGHRI late-fusion and deep-association architecture

![AGHRI late-fusion and four-level DeepFusionMOT association architecture](background/late_fusion_architecture.png)

The wider AGHRI benchmark supports **SECOND or PointPillars** for LiDAR detection; this workshop selects **PointPillars**. The diagram follows detections through late fusion, four association levels, track management, and the **2D and 3D track outputs**.

### How one camera–LiDAR match is made

1. YOLO11s produces a 2D person box; PointPillars produces a 3D person cuboid.
2. Calibration transforms the LiDAR cuboid into the camera view. Its projected corners form a 2D image envelope.
3. The fusion node compares that envelope with camera boxes using image-space intersection over union (**IoU**) and assigns candidate pairs.
4. It sends results down three paths: **matched 3D**, **unmatched LiDAR 3D**, and **unmatched camera 2D**. A match preserves the detector's 3D cuboid.

### Figure 2: Same-frame camera–LiDAR association example

![One AGHRI frame showing the camera box, LiDAR cuboid, projected overlap, and routed output](background/same_frame_association.png)

In this footpath frame, the projected LiDAR envelope overlaps the YOLO box with **IoU ≈ 0.597**. That exceeds the workshop's default **0.10** threshold, so it becomes a camera-supported 3D detection. The figure is one frame; tracking uses evidence across successive frames.

### Four levels of data association

The tracker predicts where existing tracks should be, then associates new evidence in this order:

| Level | New evidence and existing tracks | What it does |
| --- | --- | --- |
| **1** | Camera-matched 3D detections → existing 3D tracks | Updates 3D tracks with detections supported by both sensors. |
| **2** | LiDAR-only 3D detections → remaining 3D tracks | Can maintain a 3D track when no camera match was accepted. |
| **3** | Camera-only 2D detections → existing 2D tracks | Maintains a separate camera-space tracking branch. |
| **4** | Updated 2D tracks → remaining projected 3D tracks | Uses compatible 2D evidence to support a 3D track that Level 1 or 2 did not update. |

Kalman prediction and robot-motion compensation prepare the tracks for each new frame; track management then updates, starts, or retires tracks after association.

The node publishes **3D tracks** on `/deepfusionmot/tracked_3d` and **2D tracks** on `/deepfusionmot/tracked_2d`. The workshop's RViz2 layout displays the 3D tracks and their camera projections. A red unmatched LiDAR box can therefore still contribute to a magenta track.

## Sources

- [AGHRI dataset tools and dataset overview](https://github.com/LCAS/AGHRI-dataset-tools)
- [AGHRI dataset release](https://doi.org/10.24385/lincoln.32982638)
- [AGHRI late-fusion benchmark](https://github.com/LCAS/AGHRI-dataset-benchmark)
- [Original DeepFusionMOT implementation](https://github.com/wangxiyang2022/DeepFusionMOT)
- [DeepFusionMOT paper](https://arxiv.org/abs/2202.12100)

The dataset photographs and sensor montage are reproduced from the local AGHRI Dataset Tools workspace. Figures 1 and 2 are reproduced from the local AGHRI late-fusion benchmark workspace.
