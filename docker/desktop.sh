#!/usr/bin/env bash
set -euo pipefail

export DISPLAY=:99
export LIBGL_ALWAYS_SOFTWARE=1
export QT_X11_NO_MITSHM=1

if xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
  echo "Desktop display $DISPLAY is already running"
  exit 0
fi

# A stopped and restarted Dev Container retains /tmp but not Xvfb processes.
rm -f /tmp/.X99-lock /tmp/.X11-unix/X99

Xvfb "$DISPLAY" -screen 0 1600x900x24 -nolisten tcp >/tmp/roscon-xvfb.log 2>&1 &
for _ in $(seq 1 50); do
  if xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then break; fi
  sleep 0.1
done
xdpyinfo -display "$DISPLAY" >/dev/null

openbox >/tmp/roscon-openbox.log 2>&1 &
x11vnc -display "$DISPLAY" -localhost -nopw -forever -shared -rfbport 5900 \
  -bg -o /tmp/roscon-x11vnc.log >/dev/null
websockify --web=/usr/share/novnc 0.0.0.0:6080 localhost:5900 \
  >/tmp/roscon-websockify.log 2>&1 &

for _ in $(seq 1 50); do
  if (echo >/dev/tcp/127.0.0.1/6080) >/dev/null 2>&1; then
    echo 'Browser desktop ready at http://localhost:6080/'
    if [[ "${ROSCON_RVIZ:-true}" == true ]]; then
      rviz2 -d /opt/roscon/ws/install/late_fusion_pkg/share/late_fusion_pkg/rviz/aghri_generic_late_fusion.rviz \
        >/tmp/roscon-rviz.log 2>&1 &
      echo "RViz2 started on $DISPLAY (PID $!)"
    fi
    exit 0
  fi
  sleep 0.1
done
echo 'Browser desktop failed to start; inspect /tmp/roscon-*.log' >&2
exit 1
