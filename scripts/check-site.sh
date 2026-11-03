#!/usr/bin/env bash
# =====================================================================
# check-site.sh — Comprobación del libro renderizado antes de publicar
#
# Uso: scripts/check-site.sh [DIR]   (por defecto: _book)
#
# 1. Guardián de publicación sobre el árbol renderizado (--site): rutas
#    docs/, extensiones prohibidas, archivos > 5 MB, secretos, rutas locales.
# 2. Referencias cruzadas o citas sin resolver (Quarto las marca con «?@»
#    o con la clase quarto-unresolved-ref).
# 3. Archivos fuente que no deberían publicarse (.qmd, .jl, .py, .toml, .bib).
# 4. Aviso (no bloqueante) de marcas [VERIFICAR] pendientes.
#
# Salida: 0 = OK; 1 = problemas; 2 = error de uso.
# =====================================================================
set -u

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "check-site: no es un repositorio Git" >&2; exit 2; }
cd "$ROOT" || exit 2
DIR="${1:-_book}"
[ -d "$DIR" ] || { echo "check-site: no existe $DIR (¿falta quarto render?)" >&2; exit 2; }

FAIL=0
fail() { printf '  ✗ %s\n' "$1"; FAIL=1; }

bash scripts/check-publication.sh --site "$DIR" || FAIL=1

echo "▸ Referencias sin resolver"
hits=$(grep -rlE '\?@[A-Za-z]|quarto-unresolved-ref' --include='*.html' "$DIR" 2>/dev/null)
if [ -n "$hits" ]; then
  while IFS= read -r h; do fail "referencia sin resolver en $h"; done <<EOF
$hits
EOF
fi

echo "▸ Archivos fuente en el sitio"
src=$(find "$DIR" -type f \( -name '*.qmd' -o -name '*.jl' -o -name '*.py' -o -name '*.toml' -o -name '*.bib' -o -name '*.ipynb' \) 2>/dev/null)
if [ -n "$src" ]; then
  while IFS= read -r s; do fail "archivo fuente publicado: $s"; done <<EOF
$src
EOF
fi

echo "▸ Marcas [VERIFICAR] (aviso)"
nver=$(grep -roh '\[VERIFICAR' --include='*.html' "$DIR" 2>/dev/null | wc -l | tr -d ' ')
[ "$nver" -gt 0 ] && echo "  ! $nver marcas [VERIFICAR] pendientes en el sitio"

if [ "$FAIL" -ne 0 ]; then
  echo "✗ check-site: hay problemas en $DIR."
  exit 1
fi
echo "✓ check-site: $DIR listo para publicar."
exit 0
