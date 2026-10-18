FROM ros:humble-ros-base-jammy AS common

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PYTHONNOUSERSITE=1 \
    ROSCON_REPO_ROOT=/opt/roscon/ws/src/late_fusion_pkg

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-colcon-common-extensions python3-numpy python3-scipy python3-opencv \
    ros-humble-vision-msgs ros-humble-message-filters ros-humble-cv-bridge \
    ros-humble-tf2-ros ros-humble-rviz2 ros-humble-rosbag2 \
    ros-humble-rosbag2-storage-default-plugins \
    xvfb x11vnc x11-utils openbox novnc websockify libgl1-mesa-dri \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sfn vnc.html /usr/share/novnc/index.html

RUN getent group 1000 >/dev/null || groupadd -g 1000 roscon; \
    getent passwd 1000 >/dev/null || useradd -m -u 1000 -g 1000 -s /bin/bash roscon; \
    mkdir -p /output && chown 1000:1000 /output

COPY src/late_fusion_pkg /opt/roscon/ws/src/late_fusion_pkg
COPY docker /opt/roscon/
RUN /bin/bash -c 'source /opt/ros/humble/setup.bash && cd /opt/roscon/ws && colcon build --packages-select late_fusion_pkg --event-handlers console_direct+' \
    && chmod +x /opt/roscon/entrypoint.sh /opt/roscon/pipeline.sh /opt/roscon/desktop.sh

WORKDIR /workspace
ENTRYPOINT ["/opt/roscon/entrypoint.sh"]

FROM common AS cpu

FROM common AS gpu

ENV PIP_NO_CACHE_DIR=1 \
    PYTHONPATH=/opt/roscon/models \
    ROSCON_YOLO_CHECKPOINT=/models/yolo11s_best.pt \
    ROSCON_POINTPILLARS_CHECKPOINT=/models/pointpillars_best.pth \
    ROSCON_POINTPILLARS_CONFIG=/opt/roscon/models/configs/models/pointpillars_aghri_finetune_seed42.py \
    AGHRI_POINTPILLARS_BASE_CONFIG=/opt/roscon/models/configs/models/pointpillars_aghri.py \
    MPLCONFIGDIR=/tmp/roscon-matplotlib \
    YOLO_CONFIG_DIR=/tmp/roscon-ultralytics

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-pip python3-dev libgl1 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install --no-cache-dir \
    torch==2.1.2+cu118 torchvision==0.16.2+cu118 \
    --extra-index-url https://download.pytorch.org/whl/cu118
RUN python3 -m pip install --no-cache-dir numpy==1.26.4 opencv-python==4.11.0.86
RUN python3 -m pip install --no-cache-dir \
    https://download.openmmlab.com/mmcv/dist/cu118/torch2.1.0/mmcv-2.1.0-cp310-cp310-manylinux1_x86_64.whl
RUN python3 -m pip install --no-cache-dir \
    opencv-python-headless==4.11.0.86 \
    mmengine==0.10.7 mmdet==3.3.0 mmdet3d==1.4.0 \
    spconv-cu118==2.3.8 ultralytics==8.3.154

COPY models /opt/roscon/models
