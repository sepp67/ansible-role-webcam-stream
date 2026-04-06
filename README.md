# ansible-role-webcam-stream

Projet de streaming webcam avec :

- diffusion live HLS à partir d'une caméra IP en RTSP
- page web simple servie par nginx
- snapshots automatiques au lever et au coucher du soleil
- galerie HTML sur 31 jours glissants

## Fonctionnement

Le conteneur :

- récupère le flux RTSP avec `ffmpeg`
- publie un flux HLS sous `/stream/index.m3u8`
- sert une page web live sur `/`
- prend des snapshots automatiquement toutes les 15 minutes si l'heure courante correspond à la fenêtre du lever ou du coucher du soleil
- publie la galerie sous `/gallery/`

## Variables d'environnement

- `RTSP_URL`
- `WEBCAM_LATITUDE`
- `WEBCAM_LONGITUDE`
- `WEBCAM_TIMEZONE`
- `SNAPSHOT_RETENTION_DAYS`
- `SNAPSHOT_WIDTH`
- `SNAPSHOT_HEIGHT`
- `SNAPSHOT_QUALITY`
- `SNAPSHOT_WINDOW_MINUTES`
- `HLS_TIME`
- `HLS_LIST_SIZE`

## Lancer en local

```bash
docker build -t webcam-stream .
docker run -d \
  -p 8080:80 \
  -e RTSP_URL='rtsp://user:password@192.168.8.100:554/h264Preview_01_main' \
  -e WEBCAM_LATITUDE='48.4636' \
  -e WEBCAM_LONGITUDE='7.4811' \
  -e WEBCAM_TIMEZONE='Europe/Paris' \
  --name webcam-stream \
  webcam-stream
