#!/usr/bin/env bash
set -euo pipefail
set -x

: "${RTSP_URL:?RTSP_URL is required}"

mkdir -p /var/www/html/stream /var/www/html/gallery

/opt/webcam/scripts/generate_gallery.sh

cat > /etc/cron.d/webcam-snapshots <<'EOF'
*/15 * * * * root /opt/webcam/scripts/snapshot_runner.py >> /var/log/webcam-snapshots.log 2>&1
EOF

chmod 0644 /etc/cron.d/webcam-snapshots
crontab /etc/cron.d/webcam-snapshots

service cron start

ffmpeg \
  -rtsp_transport tcp \
  -i "${RTSP_URL}" \
  -c:v copy \
  -an \
  -f hls \
  -hls_time "${HLS_TIME:-4}" \
  -hls_list_size "${HLS_LIST_SIZE:-6}" \
  -hls_flags delete_segments+append_list+omit_endlist \
  -hls_delete_threshold 1 \
  /var/www/html/stream/index.m3u8 >/var/log/ffmpeg-hls.log 2>&1 &

sleep 2
cat /var/log/ffmpeg-hls.log || true

nginx -t

exec nginx -g "daemon off;"