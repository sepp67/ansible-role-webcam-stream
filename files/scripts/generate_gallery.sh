#!/usr/bin/env bash
set -euo pipefail

GALLERY_DIR="/var/www/html/gallery"
OUTPUT_FILE="${GALLERY_DIR}/index.html"

mkdir -p "${GALLERY_DIR}"

cat > "${OUTPUT_FILE}" <<'EOF'
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width,initial-scale=1.0">
  <title>Galerie Webcam</title>
  <link rel="stylesheet" href="/gallery.css">
</head>
<body>
  <h1>Galerie Webcam</h1>
  <p><a href="/">Retour au live</a></p>
  <div class="grid">
EOF

find "${GALLERY_DIR}" -maxdepth 1 -type f -name '*.jpg' | sort -r | while read -r img; do
  base="$(basename "${img}")"
  ts="${base%.jpg}"
  cat >> "${OUTPUT_FILE}" <<EOF
    <div class="card">
      <a href="/gallery/${base}"><img src="/gallery/${base}" alt="${base}"></a>
      <div class="meta">${ts}</div>
    </div>
EOF
done

cat >> "${OUTPUT_FILE}" <<'EOF'
  </div>
</body>
</html>
EOF
