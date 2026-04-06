FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    nginx \
    python3 \
    python3-pip \
    python3-venv \
    tzdata \
    ca-certificates \
    bash \
    cron \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/webcam

COPY files/scripts/requirements.txt /opt/webcam/requirements.txt
RUN python3 -m venv /opt/webcam/venv \
 && /opt/webcam/venv/bin/pip install --no-cache-dir -r /opt/webcam/requirements.txt

COPY files/nginx/default.conf /etc/nginx/sites-available/default
COPY files/html/index.html /var/www/html/index.html
COPY files/html/gallery.css /var/www/html/gallery.css

RUN mkdir -p /var/www/html/stream /var/www/html/gallery /opt/webcam/scripts

COPY files/scripts/entrypoint.sh /opt/webcam/scripts/entrypoint.sh
COPY files/scripts/generate_gallery.sh /opt/webcam/scripts/generate_gallery.sh
COPY files/scripts/snapshot_runner.py /opt/webcam/scripts/snapshot_runner.py

RUN chmod +x /opt/webcam/scripts/entrypoint.sh \
    /opt/webcam/scripts/generate_gallery.sh \
    /opt/webcam/scripts/snapshot_runner.py

EXPOSE 80

ENTRYPOINT ["/opt/webcam/scripts/entrypoint.sh"]
