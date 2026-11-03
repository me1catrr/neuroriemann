#!/usr/bin/env python3
"""verify_bib.py — Verificación de bib/references.bib (solo biblioteca estándar).

Cada entrada debe tener al menos un identificador verificable:
  doi = {...}                       → Crossref (api.crossref.org)
  eprint = {...} (archiveprefix arXiv) → arXiv (export.arxiv.org)
  isbn = {...}                      → dígito de control + Open Library

Uso:
  python3 scripts/verify_bib.py [--offline] [--log bib/VERIFICATION.md] [BIB]

  --offline  solo comprueba presencia y formato (DOI, arXiv, dígito de control ISBN)
  --log F    escribe el registro de verificación (clave → identificador → título
             obtenido → similitud → fecha) en F

Online, el título de la entrada se compara con el del registro (similitud ≥ 0,85
tras normalizar) y, si hay año en ambos, debe coincidir. Salida: 0 = todo
verificado; 1 = fallos; 2 = error de uso.
"""

from __future__ import annotations

import argparse
import datetime as dt
import difflib
import json
import re
import sys
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

USER_AGENT = "neuroriemann-verify-bib/0.1 (+https://github.com/me1catrr/neuroriemann)"
TITLE_THRESHOLD = 0.85
DOI_RE = re.compile(r"^10\.\d{4,9}/\S+$")
ARXIV_RE = re.compile(r"^(\d{4}\.\d{4,5}|[a-z\-]+(\.[A-Z]{2})?/\d{7})(v\d+)?$")


# --------------------------------------------------------------------- parser
def parse_bib(text: str) -> list[dict]:
    """Parser BibTeX mínimo: @tipo{clave, campo = {…} | "…" | número, …}."""
    entries, i, n = [], 0, len(text)
    while True:
        at = text.find("@", i)
        if at < 0:
            break
        m = re.match(r"@(\w+)\s*\{\s*([^,\s]+)\s*,", text[at:])
        if not m:
            i = at + 1
            continue
        etype, key = m.group(1).lower(), m.group(2)
        if etype in ("comment", "string", "preamble"):
            i = at + 1
            continue
        j = at + m.end()
        fields: dict[str, str] = {}
        while j < n:
            while j < n and text[j] in " \t\r\n,":
                j += 1
            if j < n and text[j] == "}":
                j += 1
                break
            fm = re.match(r"([\w\-]+)\s*=\s*", text[j:])
            if not fm:
                raise ValueError(f"{key}: campo mal formado cerca de «{text[j:j+30]}»")
            name = fm.group(1).lower()
            j += fm.end()
            if text[j] == "{":
                depth, k = 0, j
                while k < n:
                    if text[k] == "{":
                        depth += 1
                    elif text[k] == "}":
                        depth -= 1
                        if depth == 0:
                            break
                    k += 1
                value, j = text[j + 1 : k], k + 1
            elif text[j] == '"':
                k = text.index('"', j + 1)
                value, j = text[j + 1 : k], k + 1
            else:
                vm = re.match(r"[^,}\s]+", text[j:])
                value, j = vm.group(0), j + vm.end()
            fields[name] = " ".join(value.split())
        entries.append({"type": etype, "key": key, **fields})
        i = j
    return entries


# ------------------------------------------------------------------ utilidades
def norm_title(s: str) -> str:
    s = re.sub(r"\\[a-zA-Z]+\s*", " ", s)  # órdenes LaTeX
    s = re.sub(r"<[^>]+>", " ", s)  # etiquetas (JATS en Crossref)
    s = unicodedata.normalize("NFKD", s)
    s = "".join(c for c in s if not unicodedata.combining(c))
    s = re.sub(r"[^a-z0-9 ]", " ", s.lower())
    return " ".join(s.split())


def similarity(a: str, b: str) -> float:
    return difflib.SequenceMatcher(None, norm_title(a), norm_title(b)).ratio()


def isbn_ok(raw: str) -> bool:
    d = re.sub(r"[\s\-]", "", raw).upper()
    if len(d) == 13 and d.isdigit():
        return sum(int(c) * (1 if k % 2 == 0 else 3) for k, c in enumerate(d)) % 10 == 0
    if len(d) == 10 and d[:9].isdigit() and (d[9].isdigit() or d[9] == "X"):
        vals = [int(c) for c in d[:9]] + [10 if d[9] == "X" else int(d[9])]
        return sum((10 - k) * v for k, v in enumerate(vals)) % 11 == 0
    return False


def http_get(url: str, accept: str = "application/json") -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": accept})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=20) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            if e.code in (429, 503) and attempt < 2:
                time.sleep(2 * (attempt + 1))
                continue
            raise
    raise RuntimeError("inalcanzable")


# ------------------------------------------------------------------- consultas
def lookup_doi(doi: str) -> tuple[str, str | None]:
    data = json.loads(http_get("https://api.crossref.org/works/" + urllib.parse.quote(doi)))
    msg = data["message"]
    title = (msg.get("title") or [""])[0]
    year = None
    for k in ("published-print", "published-online", "issued"):
        parts = msg.get(k, {}).get("date-parts")
        if parts and parts[0] and parts[0][0]:
            year = str(parts[0][0])
            break
    return title, year


def lookup_arxiv(aid: str) -> tuple[str, str | None]:
    url = "https://export.arxiv.org/api/query?id_list=" + urllib.parse.quote(aid)
    root = ET.fromstring(http_get(url, accept="application/atom+xml"))
    ns = {"a": "http://www.w3.org/2005/Atom"}
    entry = root.find("a:entry", ns)
    if entry is None or entry.find("a:title", ns) is None:
        raise LookupError("arXiv no devuelve la entrada")
    title = " ".join(entry.find("a:title", ns).text.split())
    pub = entry.find("a:published", ns)
    return title, (pub.text[:4] if pub is not None else None)


def lookup_isbn(isbn: str) -> tuple[str, str | None]:
    d = re.sub(r"[\s\-]", "", isbn)
    data = json.loads(http_get(f"https://openlibrary.org/isbn/{d}.json"))
    title = data.get("title", "")
    if data.get("subtitle"):
        title += ": " + data["subtitle"]
    ym = re.search(r"\d{4}", data.get("publish_date", ""))
    return title, (ym.group(0) if ym else None)


# ---------------------------------------------------------------- verificación
def identifiers(e: dict) -> list[tuple[str, str]]:
    ids = []
    if "doi" in e:
        ids.append(("doi", re.sub(r"^(https?://(dx\.)?doi\.org/|doi:)", "", e["doi"], flags=re.I)))
    if "eprint" in e and e.get("archiveprefix", "arxiv").lower() == "arxiv":
        ids.append(("arxiv", e["eprint"]))
    if "isbn" in e:
        ids.append(("isbn", e["isbn"]))
    return ids


def check_entry(e: dict, offline: bool) -> tuple[bool, list[str], list[dict]]:
    msgs, log = [], []
    ids = identifiers(e)
    if not ids:
        return False, ["sin DOI, arXiv ni ISBN"], log
    ok = True
    for kind, value in ids:
        fmt = {"doi": DOI_RE.match(value), "arxiv": ARXIV_RE.match(value), "isbn": isbn_ok(value)}[kind]
        if not fmt:
            ok = False
            msgs.append(f"{kind} con formato inválido: {value}")
            continue
        if offline:
            msgs.append(f"{kind} {value}: formato válido (sin consulta)")
            continue
        try:
            title, year = {"doi": lookup_doi, "arxiv": lookup_arxiv, "isbn": lookup_isbn}[kind](value)
        except Exception as exc:  # red, 404, formato inesperado
            ok = False
            msgs.append(f"{kind} {value}: consulta fallida ({exc})")
            continue
        sim = similarity(e.get("title", ""), title)
        year_ok = not (year and e.get("year")) or year == e["year"]
        good = sim >= TITLE_THRESHOLD and (year_ok or kind == "isbn")
        ok &= good
        flag = "OK" if good else "DISCREPANCIA"
        extra = "" if year_ok else f"; año registro {year} ≠ {e.get('year')}"
        msgs.append(f"{kind} {value}: {flag} (similitud {sim:.2f}{extra}) «{title}»")
        log.append({"key": e["key"], "kind": kind, "id": value, "title": title,
                    "year": year or "", "sim": sim, "status": flag})
    return ok, msgs, log


def write_log(path: Path, rows: list[dict]) -> None:
    today = dt.date.today().isoformat()
    lines = [
        "# Registro de verificación bibliográfica",
        "",
        f"Generado por `scripts/verify_bib.py` el {today}. No editar a mano.",
        "",
        "| Clave | Tipo | Identificador | Título en el registro | Año | Similitud | Estado |",
        "|---|---|---|---|---|---|---|",
    ]
    for r in rows:
        t = r["title"].replace("|", "\\|")
        lines.append(f"| `{r['key']}` | {r['kind']} | {r['id']} | {t} | {r['year']} | {r['sim']:.2f} | {r['status']} |")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("bib", nargs="?", default="bib/references.bib")
    ap.add_argument("--offline", action="store_true")
    ap.add_argument("--log", type=Path)
    a = ap.parse_args()
    path = Path(a.bib)
    if not path.is_file():
        print(f"verify_bib: no existe {path}", file=sys.stderr)
        return 2
    try:
        entries = parse_bib(path.read_text(encoding="utf-8"))
    except ValueError as exc:
        print(f"verify_bib: {exc}", file=sys.stderr)
        return 2
    keys = [e["key"] for e in entries]
    dups = sorted({k for k in keys if keys.count(k) > 1})
    failures, rows = 0, []
    if dups:
        failures += 1
        print(f"✗ claves duplicadas: {', '.join(dups)}")
    for e in entries:
        ok, msgs, log = check_entry(e, a.offline)
        rows += log
        failures += not ok
        print(f"{'✓' if ok else '✗'} {e['key']}")
        for m in msgs:
            print(f"    {m}")
        if not a.offline:
            time.sleep(0.5)  # cortesía con las API públicas
    if a.log and not a.offline:
        write_log(a.log, rows)
        print(f"Registro escrito en {a.log}")
    print(f"{len(entries)} entradas, {failures} con fallos.")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
