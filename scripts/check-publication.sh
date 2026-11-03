#!/usr/bin/env bash
# =====================================================================
# check-publication.sh — Guardián de publicación de NeuroRiemann
#
# Impide que material bibliográfico protegido, datos EEG, archivos
# sensibles, secretos o rutas locales entren en Git o en el sitio Quarto.
#
# Uso:
#   scripts/check-publication.sh [--staged] [--tracked] [--history] [--site DIR]
#   Sin argumentos equivale a --tracked.
#
#   --staged   archivos preparados para commit (gancho pre-commit)
#   --tracked  archivos versionados en el índice
#   --history  todas las rutas, tamaños y contenidos de todo el historial
#   --site DIR árbol renderizado (p. ej. _book) antes de publicar
#
# Excepciones de extensión: rutas exactas en scripts/publication-allowlist.txt
# (una por línea, sin comodines). docs/ y datos privados no admiten excepciones.
#
# Compatible con bash 3.2 (macOS). Sin dependencias externas.
# Salida: 0 = OK; 1 = violaciones; 2 = error de uso.
# =====================================================================
set -u

MAX_BYTES=$((5 * 1024 * 1024))

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
  echo "check-publication: no es un repositorio Git" >&2
  exit 2
}
cd "$ROOT" || exit 2
ALLOWLIST="scripts/publication-allowlist.txt"

# Patrones construidos por concatenación para que este archivo no se
# detecte a sí mismo. Nunca se imprime el contenido coincidente (solo
# archivo y línea), para no filtrar secretos en los registros de CI.
P_KEY='-----BEGIN [A-Z ]*PRIV''ATE KEY'
P_GH='gh[pousr]''_[A-Za-z0-9]{36,}'
P_GHPAT='github''_pat_[A-Za-z0-9_]{40,}'
P_AWS='AK''IA[0-9A-Z]{16}'
P_SLACK='xox''[baprs]-[A-Za-z0-9-]{10,}'
P_SK='(^|[^A-Za-z0-9])s''k-[A-Za-z0-9_-]{20,}'
SECRET_RE="$P_KEY|$P_GH|$P_GHPAT|$P_AWS|$P_SLACK|$P_SK"
HOME_RE='/Us''ers/[A-Za-z0-9._-]+/|/ho''me/[a-z][a-z0-9_-]*/'

FAIL=0
fail() { printf '  ✗ %s\n' "$1"; FAIL=1; }

is_allowlisted() {
  [ -f "$ALLOWLIST" ] && grep -qxF -- "$1" "$ALLOWLIST"
}

# check_path RUTA CONTEXTO [site]
check_path() {
  local p="$1" ctx="$2" mode="${3:-repo}" low base
  low=$(printf '%s' "$p" | tr '[:upper:]' '[:lower:]')
  base=${low##*/}

  if [ "$mode" = site ]; then
    case "$low" in
      docs/*|*/docs/*) fail "$ctx: ruta docs/ en el sitio: $p"; return ;;
    esac
  fi

  case "$low" in
    docs/*|papers/*|literature/*|bibliografia-privada/*|zotero/*|storage/*|\
    private/*|*/private/*|confidential/*|*/confidential/*)
      fail "$ctx: ruta privada: $p"; return ;;
    data/synthetic/*) ;;
    data/*|datos/*|raw/*|rawdata/*|sourcedata/*|derivatives/*)
      fail "$ctx: datos no publicables: $p"; return ;;
  esac

  case "$base" in
    .env.example) ;;
    .env|.env.*|*.pem|*.key|*.p12|*.pfx|id_rsa*|id_ed25519*|credentials*|\
    secrets*|.netrc|*.secret|*.token|participants_private*|*_private.*)
      fail "$ctx: archivo sensible: $p"; return ;;
  esac

  case "$low" in
    *.pdf|*.epub|*.djvu|*.ps|*.mobi|*.azw3|*.chm|*.doc|*.docx|*.ppt|*.pptx|*.xls|*.xlsx|\
    *.edf|*.edf+|*.bdf|*.gdf|*.vhdr|*.vmrk|*.eeg|*.set|*.fdt|*.cnt|*.mff|*.xdf|*.fif|*.fif.gz|\
    *.nwb|*.dat|*.raw|*.mat|*.h5|*.hdf5|*.nc|*.npy|*.npz|*.pkl|*.pickle|*.joblib|*.jld|*.jld2|\
    *.bson|*.nii|*.nii.gz|*.sqlite|*.db)
      is_allowlisted "$p" || fail "$ctx: extensión no publicable: $p" ;;
  esac
}

check_size() {
  local p="$1" size="$2" ctx="$3"
  if [ -n "$size" ] && [ "$size" -gt "$MAX_BYTES" ]; then
    fail "$ctx: archivo > 5 MB ($size bytes): $p"
  fi
}

# Busca patrones en el índice (git grep --cached). Argumentos opcionales: rutas.
check_content_index() {
  local ctx="$1"; shift
  local hits
  hits=$(git grep --cached -I -n -E -e "$SECRET_RE" -- "$@" 2>/dev/null | cut -d: -f1,2)
  [ -n "$hits" ] && while IFS= read -r h; do fail "$ctx: posible secreto en $h"; done <<EOF
$hits
EOF
  hits=$(git grep --cached -I -n -E -e "$HOME_RE" -- "$@" 2>/dev/null | cut -d: -f1,2)
  [ -n "$hits" ] && while IFS= read -r h; do fail "$ctx: ruta local absoluta en $h"; done <<EOF
$hits
EOF
}

run_staged() {
  echo "▸ Archivos preparados (--staged)"
  local files=() f
  while IFS= read -r -d '' f; do
    files+=("$f")
    check_path "$f" staged
    check_size "$f" "$(git cat-file -s ":$f" 2>/dev/null)" staged
  done < <(git diff --cached --name-only -z --diff-filter=ACMR)
  if [ "${#files[@]}" -gt 0 ]; then
    check_content_index staged "${files[@]}"
  fi
}

run_tracked() {
  echo "▸ Archivos versionados (--tracked)"
  local info path sha
  while IFS= read -r -d '' info; do
    path=${info#*$'\t'}
    sha=$(printf '%s' "$info" | cut -d' ' -f2)
    check_path "$path" tracked
    check_size "$path" "$(git cat-file -s "$sha" 2>/dev/null)" tracked
  done < <(git ls-files -s -z)
  check_content_index tracked
}

run_history() {
  echo "▸ Historial completo (--history)"
  git rev-parse --verify -q HEAD >/dev/null || { echo "  (sin commits)"; return; }
  local p line type size rest hits
  while IFS= read -r p; do
    [ -n "$p" ] && check_path "$p" history
  done < <(git log --all --name-only --format= | sort -u)

  while IFS= read -r line; do
    type=${line%% *}; rest=${line#* }
    size=${rest%% *}; p=${rest#* }
    [ "$type" = blob ] && check_size "$p" "$size" history
  done < <(git rev-list --objects --all | git cat-file --batch-check='%(objecttype) %(objectsize) %(rest)')

  hits=$(git rev-list --all | xargs git grep -I -l -E -e "$SECRET_RE" 2>/dev/null)
  [ -n "$hits" ] && while IFS= read -r h; do fail "history: posible secreto en ${h:0:12}…:${h#*:}"; done <<EOF
$hits
EOF
  hits=$(git rev-list --all | xargs git grep -I -l -E -e "$HOME_RE" 2>/dev/null)
  [ -n "$hits" ] && while IFS= read -r h; do fail "history: ruta local absoluta en ${h:0:12}…:${h#*:}"; done <<EOF
$hits
EOF
}

run_site() {
  local dir="$1" f rel hits
  echo "▸ Sitio renderizado (--site $dir)"
  [ -d "$dir" ] || { echo "check-publication: no existe $dir" >&2; exit 2; }
  while IFS= read -r -d '' f; do
    rel=${f#"$dir"/}
    check_path "$rel" site site
    check_size "$rel" "$(wc -c <"$f" | tr -d ' ')" site
  done < <(find "$dir" -type f -print0)
  hits=$(grep -rIlE -e "$SECRET_RE" "$dir" 2>/dev/null)
  [ -n "$hits" ] && while IFS= read -r h; do fail "site: posible secreto en $h"; done <<EOF
$hits
EOF
  hits=$(grep -rIlE -e "$HOME_RE" "$dir" 2>/dev/null)
  [ -n "$hits" ] && while IFS= read -r h; do fail "site: ruta local absoluta en $h"; done <<EOF
$hits
EOF
}

[ $# -eq 0 ] && set -- --tracked
while [ $# -gt 0 ]; do
  case "$1" in
    --staged)  run_staged ;;
    --tracked) run_tracked ;;
    --history) run_history ;;
    --site)    [ $# -ge 2 ] || { echo "Uso: --site DIR" >&2; exit 2; }; run_site "$2"; shift ;;
    -h|--help) sed -n '2,23p' "$0"; exit 0 ;;
    *) echo "check-publication: opción desconocida: $1" >&2; exit 2 ;;
  esac
  shift
done

if [ "$FAIL" -ne 0 ]; then
  echo "✗ check-publication: se han detectado violaciones. Corrige antes de continuar."
  exit 1
fi
echo "✓ check-publication: sin violaciones."
exit 0
