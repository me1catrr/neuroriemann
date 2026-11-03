#!/usr/bin/env bash
# =====================================================================
# test-check-publication.sh — Pruebas del guardián de publicación
#
# Crea repositorios temporales en $TMPDIR y comprueba que
# scripts/check-publication.sh bloquea cada caso prohibido y acepta
# los casos legítimos. No toca el repositorio real.
# =====================================================================
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
GUARD="$HERE/check-publication.sh"
BASE=$(mktemp -d "${TMPDIR:-/tmp}/nr-guard-test.XXXXXX")
trap 'rm -rf "$BASE"' EXIT

PASS=0; FAILS=0
G() { git -c core.hooksPath=/dev/null -c commit.gpgsign=false \
          -c user.name=test -c user.email=test@example.invalid "$@"; }

new_repo() {
  local d="$BASE/$1"
  mkdir -p "$d/scripts" && cp "$GUARD" "$d/scripts/" && cd "$d" && G init -q -b main
  G add scripts/check-publication.sh
}

# expect <ok|fail> <descripción> <argumentos del guardián...>
expect() {
  local want="$1" desc="$2"; shift 2
  local got=fail
  bash scripts/check-publication.sh "$@" >/dev/null 2>&1 && got=ok
  if [ "$got" = "$want" ]; then
    printf '  ✓ %s\n' "$desc"; PASS=$((PASS + 1))
  else
    printf '  ✗ %s (esperado %s, obtenido %s)\n' "$desc" "$want" "$got"; FAILS=$((FAILS + 1))
  fi
}

FAKE_TOKEN="gh""p_$(printf 'a%.0s' $(seq 1 36))"
FAKE_HOME="$(printf '/%s/%s/proyecto' Users alguien)"

echo "▸ Pruebas de check-publication.sh"

new_repo clean
echo "# ok" > README.md; G add README.md
expect ok   "repositorio limpio aceptado" --staged

new_repo docs_pdf
mkdir docs && echo x > docs/articulo.pdf; G add -f docs/articulo.pdf
expect fail "docs/*.pdf bloqueado" --staged

new_repo docs_md
mkdir docs && echo x > docs/notas.md; G add -f docs/notas.md
expect fail "cualquier archivo en docs/ bloqueado" --staged

new_repo eeg
echo x > sub01.edf; G add -f sub01.edf
expect fail "datos EEG (.edf) bloqueados" --staged

new_repo data
mkdir -p data/raw && echo x > data/raw/s.csv; G add -f data/raw/s.csv
expect fail "data/ no sintético bloqueado" --staged

new_repo synthetic
mkdir -p data/synthetic && echo "a,b" > data/synthetic/spd.csv; G add -f data/synthetic/spd.csv
expect ok   "data/synthetic/ aceptado" --staged

new_repo token
echo "token=$FAKE_TOKEN" > notas.txt; G add notas.txt
expect fail "token de GitHub bloqueado" --staged

new_repo pkey
printf -- '-----BEGIN RSA %s KEY-----\nabc\n' "PRIVATE" > clave.txt; G add clave.txt
expect fail "clave privada bloqueada" --staged

new_repo hist_secret
echo "t=$FAKE_TOKEN" > n.txt; G add n.txt; G commit -q -m "error"
echo "limpio" > n.txt; G add n.txt; G commit -q -m "limpieza"
expect ok   "secreto retirado: --tracked limpio" --tracked
expect fail "secreto retirado: --history lo detecta" --history

new_repo home
echo "ver $FAKE_HOME/x" > notas.md; G add notas.md
expect fail "ruta local absoluta bloqueada" --staged

new_repo env
echo "A=1" > .env; G add -f .env
expect fail ".env bloqueado" --staged

new_repo big
dd if=/dev/zero of=grande.bin bs=1048576 count=6 2>/dev/null; G add grande.bin
expect fail "archivo > 5 MB bloqueado" --staged

new_repo allow
mkdir figs && echo x > figs/propia.pdf && echo "figs/propia.pdf" > scripts/publication-allowlist.txt
G add -f figs/propia.pdf scripts/publication-allowlist.txt
expect ok   "PDF propio en lista de excepciones aceptado" --staged

new_repo history
mkdir docs && echo x > docs/a.pdf; G add -f docs/a.pdf; G commit -q -m "error"
G rm -q --cached docs/a.pdf; G commit -q -m "retirada"
expect ok   "historial: --tracked limpio tras retirar" --tracked
expect fail "historial: --history detecta docs/ pasado" --history

new_repo site
mkdir -p _book/docs && echo x > _book/docs/a.html
expect fail "sitio con docs/ bloqueado" --site _book
mkdir -p _book2 && echo "<p>ok</p>" > _book2/index.html
expect ok   "sitio limpio aceptado" --site _book2

echo "Resultado: $PASS correctas, $FAILS fallidas."
[ "$FAILS" -eq 0 ]
