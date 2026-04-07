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

run_ffmpeg() {
  while true; do
    echo "$(date -Is) starting ffmpeg" >> /var/log/ffmpeg-hls.log

    ffmpeg \
      -hide_banner \
      -loglevel info \
      -rtsp_transport tcp \
      -fflags +genpts+discardcorrupt \
      -use_wallclock_as_timestamps 1 \
      -i "${RTSP_URL}" \
      -an \
      -c:v copy \
      -f hls \
      -hls_time "${HLS_TIME:-2}" \
      -hls_list_size "${HLS_LIST_SIZE:-5}" \
      -hls_flags delete_segments+append_list+omit_endlist+independent_segments \
      -hls_delete_threshold 1 \
      /var/www/html/stream/index.m3u8 >> /var/log/ffmpeg-hls.log 2>&1

    rc=$?
    echo "$(date -Is) ffmpeg exited rc=${rc}, restart in 3s" >> /var/log/ffmpeg-hls.log
    sleep 3
  done
}

run_ffmpeg &

sleep 2
tail -n 50 /var/log/ffmpeg-hls.log || true

nginx -t
exec nginx -g "daemon off;"