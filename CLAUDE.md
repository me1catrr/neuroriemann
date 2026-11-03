# NeuroRiemann — instrucciones permanentes

## Propósito
Libro científico y educativo público (Quarto) sobre geometría riemanniana y sus aplicaciones al EEG: fundamentos matemáticos rigurosos, algoritmos documentados y laboratorios reproducibles.

## Límites con NeuroMIND
- Repositorios independientes. No modificar, leer datos ni ejecutar código de NeuroMIND sin autorización explícita.
- NeuroRiemann publica métodos, código genérico y datos sintéticos. Los análisis sobre datos NeuroMIND se ejecutan en NeuroMIND; aquí solo se citan resultados agregados ya autorizados para publicación.
- Prohibido publicar datos originales o derivados sensibles de NeuroMIND (señales, covarianzas, matrices de conectividad individuales, identificadores, metadatos clínicos).

## Material protegido
- `docs/` es una carpeta local de consulta: permanentemente excluida de Git y del sitio. No mover, copiar, citar textualmente en extenso ni enlazar sus archivos.
- No publicar artículos, libros, PDF, figuras, tablas o fragmentos protegidos sin licencia compatible. Las figuras se recrean con código propio y se cita la fuente.
- Licencias: código MIT (`LICENSE`); texto y figuras originales CC BY 4.0 (`LICENSE-CONTENT.md`).

## Integridad científica
- No inventar resultados, teoremas, referencias, DOI, números de página ni datos. Si algo no se puede verificar, marcarlo `[VERIFICAR]` y avisar.
- Toda entrada de `bib/references.bib` debe tener DOI, arXiv o ISBN verificado (`scripts/verify_bib.py`).
- Antes de trasladar una ecuación de un artículo, comprobar hipótesis, convenciones y factores constantes; documentar las discrepancias.
- Distinguir siempre: matrices SPD, matrices de correlación (SPD con diagonal unitaria) y matrices de conectividad funcional (no necesariamente PSD; p. ej. wPLI tiene diagonal nula).

## Arquitectura
- `chapters/`, `appendices/`: capítulos `.qmd`; código mínimo en capítulos, que llaman a funciones del paquete.
- `julia/NeuroRiemann.jl/`: lenguaje principal; paquete con `src/` y `test/`.
- `python/validation/`: validación independiente (NumPy/SciPy, pyRiemann, MNE); no produce resultados del libro.
- `simulators/`: simuladores JS/OJS autónomos, validados contra `fixtures/` generados por Julia.
- `data/synthetic/`: solo datos sintéticos generados con semilla y script versionado.
- `bib/references.bib`, `_macros.qmd` (macros LaTeX comunes).
- `_quarto.yml` con `project.render` explícito; nunca renderizar ni declarar como recurso nada fuera de las carpetas públicas.

## Notación
- Usar exclusivamente las macros de `_macros.qmd` (`\Sym_n`, `\SPD_n`, `\Corr_n`, `\Expm`, `\Logm`, `\Exp_P`, `\Log_P`, `\dAI`, `\dLE`).
- `\exp`, `\log` matriciales ≠ `\Exp_P`, `\Log_P` riemannianos. Raíz y logaritmo siempre principales.
- Teoremas, definiciones y demostraciones con divs Quarto (`#thm-`, `#def-`, `#lem-`, `.proof`); referencias cruzadas con `@`.
- Toda convención (factores 1/2, √2 en vectorización, normalizaciones) se declara explícitamente.

## Reproducibilidad y tests
- Cada algoritmo: definición matemática, pseudocódigo, implementación Julia, test de propiedades y validación cruzada Python con tolerancia declarada.
- Tests de invariancias e identidades (p. ej. `dAI(WAWᵀ,WBWᵀ)=dAI(A,B)`, extremos de geodésicas, `det γ(t)`).
- Semillas fijas; entornos fijados (`Project.toml`/`Manifest.toml`, `pyproject.toml`).
- No instalar dependencias ni cambiar versiones sin autorización.

## Git y publicación
- Antes de cada commit y push: revisar `git status`, `git diff --staged` y la lista de archivos incluidos; ejecutar `scripts/check-publication.sh`.
- Antes de publicar el sitio: `scripts/check-publication.sh --site _book`.
- Nunca `git add .` ni `git add -A`; añadir archivos por ruta.
- No hacer push, cambiar visibilidad, publicar GitHub Pages ni crear releases sin aprobación explícita.
- No desactivar ganchos (`--no-verify`) ni el workflow `publication-guard`.
