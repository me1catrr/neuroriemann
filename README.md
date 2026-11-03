# NeuroRiemann

**NeuroRiemann** es un proyecto científico dedicado al estudio de señales neurofisiológicas (EEG) mediante herramientas de **geometría de Riemann**: matrices de covarianza simétricas definidas positivas, variedades SPD, métricas y medias riemannianas, espacio tangente y métodos de clasificación y análisis estadístico sobre variedades.

> Estado: fase inicial de planificación. La arquitectura matemática, las herramientas computacionales y la estructura del proyecto se definirán próximamente.

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
