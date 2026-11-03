# NeuroRiemann

**NeuroRiemann** es un proyecto científico dedicado al estudio de señales neurofisiológicas (EEG) mediante herramientas de **geometría de Riemann**: matrices de covarianza simétricas definidas positivas, variedades SPD, métricas y medias riemannianas, espacio tangente y métodos de clasificación y análisis estadístico sobre variedades.

> Estado: capítulo piloto «Métricas sobre SPD» disponible; el resto, en preparación.
> Libro en línea: <https://me1catrr.github.io/neuroriemann/>

## Estructura

| Ruta | Contenido |
|---|---|
| `_quarto.yml`, `index.qmd`, `parts/`, `chapters/`, `appendices/` | Libro Quarto (HTML; Typst previsto) |
| `temario.toml`, `julia/scripts/generar_indice.jl` | Estructura del libro (fuente única) y su generador |
| `assets/` | Identidad visual: `scss/marca.scss`, `css/styles.css`, `img/marca.svg` |
| `_macros.qmd` | Macros LaTeX comunes (`\SPD_n`, `\Logm`, `\Log_P`, `\dAI`…) |
| `julia/NeuroRiemann.jl/` | Paquete Julia de referencia con tests |
| `Project.toml`, `Manifest.toml` | Entorno Julia del libro (versiones fijadas) |
| `fixtures/` | Resultados de Julia con semilla fija para la validación cruzada |
| `python/validation/` | Validación independiente (SciPy, pyRiemann) |
| `bib/` | Bibliografía verificada (`scripts/verify_bib.py`) |

## Reproducir

```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
julia --project=julia/NeuroRiemann.jl -e 'using Pkg; Pkg.test()'
quarto render && scripts/check-site.sh
```

Instrucciones completas, incluida la validación en Python, en el apéndice «Entorno y reproducibilidad».

## Relación con NeuroMIND

NeuroRiemann es un proyecto **conceptualmente relacionado pero independiente** de NeuroMIND:

- NeuroMIND aporta el contexto neurocientífico, los datos y los flujos de procesamiento EEG.
- NeuroRiemann desarrolla el marco matemático riemanniano y su aplicación a dichos problemas.

Ambos repositorios se mantienen separados. La conexión entre ellos se realizará mediante referencias, enlaces e interfaces reproducibles para compartir resultados, sin copiar datos ni crear dependencias innecesarias.

## Datos y material protegido

Este repositorio **no contiene datos EEG originales**, información sensible ni artículos o libros protegidos por derechos de autor. Solo se publican datos sintéticos generados con semilla (`data/synthetic/`).

Un guardián automático (`scripts/check-publication.sh`) lo verifica antes de cada commit, antes de cada push y en GitHub Actions. Para activar los ganchos locales tras clonar:

```bash
git config core.hooksPath .githooks
```

## Licencia

- Código: [MIT](LICENSE).
- Texto y figuras originales: [CC BY 4.0](LICENSE-CONTENT.md).
- El material de terceros queda excluido y pertenece a sus titulares.

## Autor

Rafael Castro Triguero — Universidad de Córdoba
