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

run_ffmpeg_once() {
  rm -f /var/www/html/stream/*.ts /var/www/html/stream/*.m3u8 || true

  ffmpeg \
  -hide_banner \
  -loglevel info \
  -rtsp_transport tcp \
  -fflags +genpts+discardcorrupt+nobuffer \
  -flags low_delay \
  -use_wallclock_as_timestamps 1 \
  -i "${RTSP_URL}" \
  -an \
  -vf "fps=10,scale=1280:-2" \
  -c:v libx264 \
  -preset veryfast \
  -tune zerolatency \
  -pix_fmt yuv420p \
  -g 20 \
  -keyint_min 20 \
  -sc_threshold 0 \
  -force_key_frames "expr:gte(t,n_forced*2)" \
  -f hls \
  -hls_time 2 \
  -hls_list_size 4 \
  -hls_flags delete_segments+append_list+omit_endlist+independent_segments \
  -hls_delete_threshold 1 \
  /var/www/html/stream/index.m3u8
  FFMPEG_PID=$!
}

watch_ffmpeg() {
  local stale_after="${HLS_STALE_AFTER:-20}"

  while kill -0 "${FFMPEG_PID}" 2>/dev/null; do
    sleep 5

    latest_file="$(find /var/www/html/stream -maxdepth 1 \( -name '*.ts' -o -name 'index.m3u8' \) -type f 2>/dev/null | xargs -r ls -t 2>/dev/null | head -n 1 || true)"

    if [ -z "${latest_file}" ]; then
      echo "$(date -Is) watchdog: no HLS files yet" >> /var/log/ffmpeg-hls.log
      continue
    fi

    now="$(date +%s)"
    mtime="$(stat -c %Y "${latest_file}" 2>/dev/null || echo 0)"
    age=$((now - mtime))

    if [ "${age}" -gt "${stale_after}" ]; then
      echo "$(date -Is) watchdog: HLS stale for ${age}s, killing ffmpeg pid=${FFMPEG_PID}" >> /var/log/ffmpeg-hls.log
      kill -TERM "${FFMPEG_PID}" 2>/dev/null || true
      sleep 2
      kill -KILL "${FFMPEG_PID}" 2>/dev/null || true
      wait "${FFMPEG_PID}" 2>/dev/null || true
      return 1
    fi
  done

  wait "${FFMPEG_PID}"
}

run_supervisor() {
  while true; do
    echo "$(date -Is) starting ffmpeg" >> /var/log/ffmpeg-hls.log
    run_ffmpeg_once

    if watch_ffmpeg; then
      rc=$?
      echo "$(date -Is) ffmpeg exited rc=${rc}, restarting in 3s" >> /var/log/ffmpeg-hls.log
    else
      echo "$(date -Is) ffmpeg was killed by watchdog, restarting in 3s" >> /var/log/ffmpeg-hls.log
    fi

    sleep 3
  done
}

run_supervisor &

sleep 2
tail -n 50 /var/log/ffmpeg-hls.log || true

nginx -t
exec nginx -g "daemon off;"