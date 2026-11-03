# Genera la estructura del libro a partir de temario.toml (solo biblioteca estándar).
#
# Uso (desde la raíz del repositorio):
#   julia julia/scripts/generar_indice.jl
#
# Escribe:
#   · _quarto.yml: la lista de capítulos entre «# INDICE:inicio» y «# INDICE:fin»;
#   · parts/*.qmd: la página de cada parte (se regenera entera);
#   · index.qmd: las tablas del índice entre <!-- INDICE:inicio --> y <!-- INDICE:fin -->;
#   · chapters/<slug>.qmd: una página «en preparación» SOLO si el archivo no existe.

using TOML

const ROOT = normpath(joinpath(@__DIR__, "..", ".."))
const TEMARIO = TOML.parsefile(joinpath(ROOT, "temario.toml"))

const ESTADOS = Dict(
    "disponible" => ("Disponible", "estado-disponible"),
    "borrador" => ("Borrador", "estado-borrador"),
    "en-preparacion" => ("En preparación", "estado-preparacion"),
)

etiqueta(estado) = (e = ESTADOS[estado]; "[$(e[1])]{.estado .$(e[2])}")
archivo_cap(c) = "chapters/$(c["slug"]).qmd"

"Sustituye el texto entre las líneas que contienen `ini` y `fin` (marcadores conservados)."
function reemplazar_bloque(texto, ini, fin, nuevo)
    lineas = split(texto, '\n'; keepempty = true)
    i = findfirst(l -> occursin(ini, l), lineas)
    j = findfirst(l -> occursin(fin, l), lineas)
    (i === nothing || j === nothing || j <= i) && error("marcadores «$ini» / «$fin» no encontrados")
    return join(vcat(lineas[1:i], split(nuevo, '\n'), lineas[j:end]), '\n')
end

function bloque_quarto()
    io = IOBuffer()
    println(io, "    - index.qmd")
    for p in TEMARIO["partes"]
        println(io, "    - part: ", p["archivo"])
        println(io, "      chapters:")
        for c in p["capitulos"]
            println(io, "        - ", archivo_cap(c))
        end
    end
    print(io, "    - bibliografia.qmd")
    return String(take!(io))
end

function tabla_capitulos(p; prefijo, con_resumen)
    io = IOBuffer()
    println(io, "::: {.indice-capitulos .parte-", lowercase(p["id"]), "}\n")
    println(io, con_resumen ? "| Cap. | Capítulo | Contenido | Estado |" : "| Cap. | Capítulo | Estado |")
    println(io, con_resumen ? "|---|---|---|---|" : "|---|---|---|")
    for c in p["capitulos"]
        enlace = "[$(c["titulo"])]($(prefijo)$(archivo_cap(c)))"
        celdas = con_resumen ? [string(c["num"]), enlace, c["resumen"], etiqueta(c["estado"])] :
                               [string(c["num"]), enlace, etiqueta(c["estado"])]
        println(io, "| ", join(celdas, " | "), " |")
    end
    print(io, "\n:::")
    return String(take!(io))
end

function pagina_parte(p)
    """
    {{< include /_macros.qmd >}}

    # $(p["titulo"])

    $(p["resumen"])

    $(tabla_capitulos(p; prefijo = "../", con_resumen = true))
    """
end

function bloque_indice()
    io = IOBuffer()
    for p in TEMARIO["partes"]
        println(io, "\n### [Parte ", p["id"], " · ", p["titulo"], "](", p["archivo"], ")\n")
        println(io, tabla_capitulos(p; prefijo = "", con_resumen = true))
    end
    return String(take!(io))
end

function pagina_en_preparacion(c)
    lista(v) = join(("- " * x for x in v), "\n")
    """
    {{< include /_macros.qmd >}}

    # $(c["titulo"])

    ::: {.callout-note .en-preparacion title="Capítulo en preparación"}
    Este capítulo forma parte de la hoja de ruta del libro y todavía no está escrito. Esta página resume lo que tratará.
    :::

    **Prerrequisitos.** $(c["prerrequisitos"])

    ## Objetivos

    $(lista(c["objetivos"]))

    ## Contenidos previstos

    $(lista(c["contenidos"]))
    """
end

function main()
    q = joinpath(ROOT, "_quarto.yml")
    write(q, reemplazar_bloque(read(q, String), "# INDICE:inicio", "# INDICE:fin", bloque_quarto()))
    println("Actualizado _quarto.yml")

    for p in TEMARIO["partes"]
        write(joinpath(ROOT, p["archivo"]), pagina_parte(p))
        println("Escrito ", p["archivo"])
        for c in p["capitulos"]
            f = joinpath(ROOT, archivo_cap(c))
            if !isfile(f)
                c["estado"] == "en-preparacion" || @warn "Falta $(archivo_cap(c)) con estado $(c["estado"])"
                write(f, pagina_en_preparacion(c))
                println("Creado ", archivo_cap(c), " (en preparación)")
            end
        end
    end

    idx = joinpath(ROOT, "index.qmd")
    write(idx, reemplazar_bloque(read(idx, String), "<!-- INDICE:inicio -->", "<!-- INDICE:fin -->", bloque_indice()))
    println("Actualizado index.qmd")
end

main()
