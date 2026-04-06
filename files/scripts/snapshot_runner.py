#!/opt/webcam/venv/bin/python3
from __future__ import annotations

import os
import subprocess
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

from astral import LocationInfo
from astral.sun import sun

RTSP_URL = os.environ["RTSP_URL"]
LAT = float(os.environ.get("WEBCAM_LATITUDE", "48.4636"))
LON = float(os.environ.get("WEBCAM_LONGITUDE", "7.4811"))
TZ = os.environ.get("WEBCAM_TIMEZONE", "Europe/Paris")

RETENTION_DAYS = int(os.environ.get("SNAPSHOT_RETENTION_DAYS", "31"))
WIDTH = int(os.environ.get("SNAPSHOT_WIDTH", "1920"))
HEIGHT = int(os.environ.get("SNAPSHOT_HEIGHT", "1080"))
QUALITY = int(os.environ.get("SNAPSHOT_QUALITY", "2"))
WINDOW_MINUTES = int(os.environ.get("SNAPSHOT_WINDOW_MINUTES", "10"))

GALLERY_DIR = "/var/www/html/gallery"
GALLERY_SCRIPT = "/opt/webcam/scripts/generate_gallery.sh"


def ensure_dirs() -> None:
    os.makedirs(GALLERY_DIR, exist_ok=True)


def get_sun_times(now: datetime) -> dict:
    city = LocationInfo("webcam", "local", TZ, LAT, LON)
    return sun(city.observer, date=now.date(), tzinfo=ZoneInfo(TZ))


def within_window(now: datetime, target: datetime) -> bool:
    return abs((now - target).total_seconds()) <= WINDOW_MINUTES * 60


def already_taken(date_str: str, label: str) -> bool:
    prefix = f"{date_str}_{label}_"
    for name in os.listdir(GALLERY_DIR):
        if name.startswith(prefix) and name.endswith(".jpg"):
            return True
    return False


def take_snapshot(label: str, now: datetime) -> None:
    filename = now.strftime(f"%Y-%m-%d_{label}_%H-%M-%S.jpg")
    output = os.path.join(GALLERY_DIR, filename)

    cmd = [
        "/usr/bin/ffmpeg",
        "-y",
        "-rtsp_transport", "tcp",
        "-i", RTSP_URL,
        "-frames:v", "1",
        "-q:v", str(QUALITY),
        "-vf", f"scale={WIDTH}:{HEIGHT}",
        output,
    ]
    subprocess.run(cmd, check=True)
    subprocess.run([GALLERY_SCRIPT], check=True)


def cleanup(now: datetime) -> None:
    cutoff = now - timedelta(days=RETENTION_DAYS)
    for name in os.listdir(GALLERY_DIR):
        if not name.endswith(".jpg"):
            continue
        path = os.path.join(GALLERY_DIR, name)
        mtime = datetime.fromtimestamp(os.path.getmtime(path), tz=ZoneInfo(TZ))
        if mtime < cutoff:
            os.remove(path)


def main() -> None:
    ensure_dirs()
    now = datetime.now(ZoneInfo(TZ))
    s = get_sun_times(now)
    date_str = now.strftime("%Y-%m-%d")

    cleanup(now)

    if within_window(now, s["sunrise"]) and not already_taken(date_str, "sunrise"):
        take_snapshot("sunrise", now)

    if within_window(now, s["sunset"]) and not already_taken(date_str, "sunset"):
        take_snapshot("sunset", now)

    subprocess.run([GALLERY_SCRIPT], check=True)


if __name__ == "__main__":
    main()
