# main.jl
# ========================================
# INTERFACE PRINCIPAL UNIFICADA - PROYECTO 20/20
# ========================================

include("solution.jl")
include("config_manager.jl")
include("initial_solution.jl")
include("neighborhood.jl")
include("tabu_search.jl")
include("data_loader.jl")

using Printf
using Random
using Statistics

# ========================================
# FUNCIÓN PRINCIPAL UNIFICADA
# ========================================

"""
Resuelve una instancia completa con configuración automática
"""
function resolver_instancia(path_instancia::String; 
                           mostrar_detalles::Bool=false,
                           semilla::Union{Int,Nothing}=nothing,
                           devolver_evolucion::Bool=false)
    
    println("🔬 Resolviendo: $path_instancia")
    println("="^60)
    
    # Cargar datos
    roi, upi, LB, UB = cargar_datos(path_instancia)
    
    # Crear configuración automática
    config = crear_configuracion_automatica(roi, upi, LB, UB; mostrar_detalles=mostrar_detalles)
    
    # Resolver usando Tabu Search unificado
    tiempo_inicio = time()
    
    if devolver_evolucion
        solucion, valor_obj, evolucion, vecinos_vacios, mejores = tabu_search_unificado(
            roi, upi, LB, UB; 
            config=config, 
            semilla=semilla,
            devolver_evolucion=true
        )
    else
        solucion, vecinos_vacios = tabu_search_unificado(
            roi, upi, LB, UB; 
            config=config, 
            semilla=semilla
        )
        valor_obj = evaluar(solucion, roi)
    end
    
    tiempo_total = time() - tiempo_inicio
    
    # Mostrar resumen final
    mostrar_resumen_final(solucion, roi, upi, LB, UB, tiempo_total, config)
    
    if devolver_evolucion
        return (solucion=solucion, valor=valor_obj, tiempo=tiempo_total, 
               evolucion=evolucion, vecinos_vacios=vecinos_vacios, mejores=mejores)
    else
        return (solucion=solucion, valor=valor_obj, tiempo=tiempo_total, 
               vecinos_vacios=vecinos_vacios)
    end
end

# ========================================
# EXPERIMENTACIÓN MÚLTIPLE
# ========================================

"""
Ejecuta múltiples experimentos sobre una instancia
"""
function experimentos_multiples(path_instancia::String, repeticiones::Int; 
                               mostrar_detalles::Bool=false,
                               semilla_base::Union{Int,Nothing}=nothing,
                               guardar_evolucion::Bool=false)
    
    println("🧪 EXPERIMENTOS MÚLTIPLES")
    println("📁 Instancia: $path_instancia")
    println("🔁 Repeticiones: $repeticiones")
    println("="^60)
    
    # Cargar datos una vez
    roi, upi, LB, UB = cargar_datos(path_instancia)
    config = crear_configuracion_automatica(roi, upi, LB, UB; mostrar_detalles=false)
    
    # Almacenar resultados
    resultados = Float64[]
    tiempos_ejecucion = Float64[]
    contador_vecinos_vacios_total = 0
    evoluciones = []
    mejores_por_iteracion = []
    
    println("🚀 Iniciando experimentos...\n")
    
    for i in 1:repeticiones
        print("▶️ Experimento $i/$repeticiones... ")
        
        semilla = semilla_base !== nothing ? semilla_base + i : nothing
        tiempo_inicio = time()
        
        try
            if guardar_evolucion
                resultado = resolver_instancia(path_instancia; 
                                             mostrar_detalles=false,
                                             semilla=semilla,
                                             devolver_evolucion=true)
                push!(evoluciones, resultado.evolucion)
                push!(mejores_por_iteracion, resultado.mejores)
            else
                resultado = resolver_instancia(path_instancia; 
                                             mostrar_detalles=false,
                                             semilla=semilla)
            end
            
            tiempo_total = time() - tiempo_inicio
            
            push!(resultados, resultado.valor)
            push!(tiempos_ejecucion, tiempo_total)
            contador_vecinos_vacios_total += resultado.vecinos_vacios
            
            println("✅ Valor: $(round(resultado.valor, digits=3)) | " *
                   "Tiempo: $(round(tiempo_total, digits=2))s | " *
                   "Vecinos vacíos: $(resultado.vecinos_vacios)")
            
        catch e
            println("❌ ERROR: $e")
            push!(resultados, 0.0)
            push!(tiempos_ejecucion, 0.0)
        end
    end
    
    # Calcular estadísticas
    mostrar_estadisticas_experimentos(resultados, tiempos_ejecucion, 
                                    contador_vecinos_vacios_total, repeticiones,
                                    mejores_por_iteracion, config)
    
    return (
        resultados = resultados,
        tiempos = tiempos_ejecucion,
        evoluciones = evoluciones,
        mejores_por_iteracion = mejores_por_iteracion
    )
end

# ========================================
# ANÁLISIS DE MÚLTIPLES INSTANCIAS
# ========================================

"""
Analiza múltiples instancias de forma sistemática
"""
function analizar_instancias_multiples(paths_instancias::Vector{String}; 
                                     repeticiones_por_instancia::Int=5,
                                     mostrar_detalles::Bool=false)
    
    println("📊 ANÁLISIS DE MÚLTIPLES INSTANCIAS")
    println("🗂️ Total de instancias: $(length(paths_instancias))")
    println("🔁 Repeticiones por instancia: $repeticiones_por_instancia")
    println("="^70)
    
    resultados_globales = Dict()
    
    for (idx, path) in enumerate(paths_instancias)
        println("\n🔬 Instancia $idx/$(length(paths_instancias)): $path")
        println("-"^50)
        
        try
            resultado = experimentos_multiples(path, repeticiones_por_instancia; 
                                             mostrar_detalles=false)
            resultados_globales[path] = resultado
            
        catch e
            println("❌ Error procesando $path: $e")
            continue
        end
    end
    
    # Resumen global
    mostrar_resumen_global(resultados_globales)
    
    return resultados_globales
end

# ========================================
# FUNCIONES DE VISUALIZACIÓN Y ESTADÍSTICAS
# ========================================

"""
Muestra resumen final de una ejecución individual
"""
function mostrar_resumen_final(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, 
                              LB::Int, UB::Int, tiempo::Float64, config::InstanceConfig)
    
    println("\n📋 RESUMEN FINAL")
    println("-"^40)
    
    stats = estadisticas_solucion(sol, roi, upi)
    
    println("🏆 Valor objetivo: $(round(evaluar(sol, roi), digits=3))")
    println("📦 Órdenes seleccionadas: $(stats.ordenes_count)")
    println("🚪 Pasillos utilizados: $(stats.pasillos_count)")
    println("💾 Unidades totales: $(stats.unidades_totales)")
    println("⚡ Eficiencia: $(round(stats.eficiencia, digits=3)) unidades/pasillo")
    println("📈 Utilización capacidad: $(round(stats.unidades_totales/UB*100, digits=1))%")
    println("⏱️ Tiempo de ejecución: $(round(tiempo, digits=2)) segundos")
    
    # Mostrar detalles solo si se solicita y las listas no son muy largas
    if config.mostrar_detalles
        if length(sol.ordenes) <= 20
            ordenes = sort(collect(sol.ordenes))
            println("📦 Órdenes detalle: $ordenes")
        end
        
        if length(sol.pasillos) <= 15
            pasillos = sort(collect(sol.pasillos))
            println("🚪 Pasillos detalle: $pasillos")
        end
    end
    
    println("✅ Análisis completado")
end

"""
Muestra estadísticas de experimentos múltiples
"""
function mostrar_estadisticas_experimentos(resultados::Vector{Float64}, 
                                         tiempos::Vector{Float64},
                                         vecinos_vacios_total::Int, 
                                         repeticiones::Int,
                                         mejores_por_iteracion::Vector,
                                         config::InstanceConfig)
    
    # Filtrar resultados válidos
    resultados_validos = filter(x -> x > 0, resultados)
    n_validos = length(resultados_validos)
    
    println("\n" * "="^60)
    println("📊 ESTADÍSTICAS FINALES")
    println("="^60)
    
    if n_validos > 0
        mejor = maximum(resultados_validos)
        peor = minimum(resultados_validos)
        promedio = mean(resultados_validos)
        mediana = median(resultados_validos)
        desv = std(resultados_validos)
        cv = desv / promedio * 100
        
        tiempo_promedio = mean(filter(x -> x > 0, tiempos))
        tiempo_total = sum(tiempos)
        
        println("✅ Experimentos exitosos: $n_validos/$repeticiones")
        println("🏆 Mejor resultado: $(round(mejor, digits=3))")
        println("💔 Peor resultado: $(round(peor, digits=3))")
        println("📈 Promedio: $(round(promedio, digits=3))")
        println("📊 Mediana: $(round(mediana, digits=3))")
        println("🧮 Desviación estándar: $(round(desv, digits=3))")
        println("📏 Coeficiente de variación: $(round(cv, digits=2))%")
        println("⏱️ Tiempo promedio: $(round(tiempo_promedio, digits=2))s")
        println("⏰ Tiempo total: $(round(tiempo_total, digits=2))s")
        println("🚫 Vecinos no factibles (promedio): $(round(vecinos_vacios_total/repeticiones, digits=1))")
        
        # Análisis de convergencia
        if !isempty(mejores_por_iteracion)
            println("\n🔄 ANÁLISIS DE CONVERGENCIA:")
            iteraciones_mejor = [length(mejores) > 1 ? mejores[end][2] : 1 for mejores in mejores_por_iteracion]
            iter_promedio_mejor = mean(filter(x -> x > 0, iteraciones_mejor))
            println("🎯 Iteración promedio del mejor: $(round(iter_promedio_mejor, digits=1))")
            
            umbral_temprano = config.parametros.max_iter * 0.25
            mejoras_tempranas = count(x -> x <= umbral_temprano, iteraciones_mejor)
            pct_tempranas = mejoras_tempranas / length(iteraciones_mejor) * 100
            println("🚀 Mejoras tempranas (< $(floor(Int, umbral_temprano)) iter): $(round(pct_tempranas, digits=1))%")
        end
    else
        println("❌ No se obtuvieron resultados válidos")
    end
end

"""
Muestra resumen global de múltiples instancias
"""
function mostrar_resumen_global(resultados_globales::Dict)
    println("\n" * "="^70)
    println("🌐 RESUMEN GLOBAL DE TODAS LAS INSTANCIAS")
    println("="^70)
    
    for (path, resultado) in resultados_globales
        resultados_validos = filter(x -> x > 0, resultado.resultados)
        if !isempty(resultados_validos)
            nombre_instancia = split(basename(path), ".")[1]
            mejor = maximum(resultados_validos)
            promedio = mean(resultados_validos)
            tiempo_promedio = mean(filter(x -> x > 0, resultado.tiempos))
            
            println("📁 $nombre_instancia: Mejor=$(round(mejor, digits=3)), " *
                   "Promedio=$(round(promedio, digits=3)), " *
                   "Tiempo=$(round(tiempo_promedio, digits=1))s")
        end
    end
    
    println("\n🎯 Análisis global completado")
end

# ========================================
# EJEMPLOS DE USO
# ========================================

"""
Ejemplo 1: Resolver una instancia individual
"""
function ejemplo_individual()
    resultado = resolver_instancia("../data/instancia01.txt"; mostrar_detalles=true)
    return resultado
end

"""
Ejemplo 2: Experimentos múltiples sobre una instancia
"""
function ejemplo_experimentos()
    resultado = experimentos_multiples("../data/instancia10.txt", 5; 
                                     semilla_base=42, guardar_evolucion=true)
    return resultado
end

"""
Ejemplo 3: Análisis de múltiples instancias
"""
function ejemplo_analisis_multiple()
    instancias = [
        "../data/instancia01.txt",
        "../data/instancia02.txt", 
        "../data/instancia03.txt",
        "../data/instancia04.txt",
        "../data/instancia05.txt"
    ]
    
    resultado = analizar_instancias_multiples(instancias; repeticiones_por_instancia=5)
    return resultado
end

# ========================================
# EJECUCIÓN PRINCIPAL
# ========================================

# Descomenta la línea que quieras ejecutar:

# Ejemplo 1: Una instancia
#println("🧪 Ejecutando ejemplo individual...")
#ejemplo_individual()

# Ejemplo 2: Experimentos múltiples
 println("🧪 Ejecutando experimentos múltiples...")
 ejemplo_experimentos()

# Ejemplo 3: Análisis múltiple
# println("🧪 Ejecutando análisis múltiple...")
# ejemplo_analisis_multiple()