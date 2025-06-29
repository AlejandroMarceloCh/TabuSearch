# main.jl
# ========================================
# SISTEMA PRINCIPAL CON ANÁLISIS ESTADÍSTICO
# ========================================

include("pathological_fix.jl")
include("solution.jl")
include("data_loader.jl")
include("initial_solution.jl")
include("tabu_structures.jl")
include("neighborhood_peque.jl")
include("neighborhood_grande.jl")
include("tabu_search_mini.jl")
include("tabu_search_grande.jl")

using Plots
using Printf
using Random
using Statistics

# ========================================
# FUNCIÓN PRINCIPAL DE EXPERIMENTACIÓN
# ========================================

function correr_repetidas_veces_mejorado(path_instancia::String, repeticiones::Int; 
                                        usar_version_mejorada=true, 
                                        guardar_evolucion=false,
                                        semilla_base=nothing)
    
    roi, upi, LB, UB = cargar_datos(path_instancia)
    configurar_instancia_patologica(roi, upi, LB, UB)
    tipo_instancia = clasificar_instancia(roi, upi)
    
    println("🔬 Analizando instancia: $path_instancia")
    println("📏 Dimensiones: $(size(roi,1)) órdenes × $(size(roi,2)) ítems × $(size(upi,1)) pasillos")
    println("🎯 Rango factible: [$LB, $UB] unidades")
    println("🏷️ Tipo: $tipo_instancia")
    println("🔁 Repeticiones: $repeticiones")
    println("⚙️ Versión: $(usar_version_mejorada ? "MEJORADA" : "ORIGINAL")")
    println("="^60)
    
    # Configurar parámetros según tipo de instancia
    if usar_version_mejorada
        if tipo_instancia == :gigante
            max_iter, max_no_improve, max_vecinos = 80, 15, 20  # ⚡ SÚPER rápido
        elseif tipo_instancia == :grande
            max_iter, max_no_improve, max_vecinos = 120, 20, 25
        elseif tipo_instancia == :mediana
            max_iter, max_no_improve, max_vecinos = 150, 25, 50
        else  # pequeña
            max_iter, max_no_improve, max_vecinos = 100, 20, 60
        end
    else
        max_iter, max_no_improve, max_vecinos = 200, 40, 100  # Parámetros originales
    end
    
    # Almacenar resultados
    resultados = Float64[]
    tiempos_ejecucion = Float64[]
    contador_vecinos_vacios_total = 0
    evoluciones = []
    mejores_por_iteracion = []
    
    println("\n🚀 Iniciando experimentos...\n")
    
    for i in 1:repeticiones
        print("▶️ Experimento $i/$repeticiones... ")
        
        semilla = semilla_base !== nothing ? semilla_base + i : nothing
        tiempo_inicio = time()
        
        try
            if usar_version_mejorada
                if tipo_instancia in [:pequeña, :mediana]
                    sol, valor, evolucion, vecinos_vacios, mejores = tabu_search(
                        roi, upi, LB, UB;
                        max_iter=max_iter,
                        max_no_improve=max_no_improve,
                        max_vecinos=max_vecinos,
                        semilla=semilla,
                        devolver_evolucion=true
                    )
                else  # :grande, :gigante
                    sol, valor, evolucion, vecinos_vacios, mejores = tabu_search_tolerante(
                        roi, upi, LB, UB;
                        max_iter=max_iter,
                        max_no_improve=max_no_improve,
                        max_vecinos=max_vecinos,
                        semilla=semilla,
                        devolver_evolucion=true
                    )
                end
                
                push!(mejores_por_iteracion, mejores)
                if guardar_evolucion
                    push!(evoluciones, evolucion)
                end
            end
            
            tiempo_total = time() - tiempo_inicio
            
            push!(resultados, valor)
            push!(tiempos_ejecucion, tiempo_total)
            contador_vecinos_vacios_total += vecinos_vacios
            
            println("✅ Valor: $(round(valor, digits=3)) | Tiempo: $(round(tiempo_total, digits=2))s | Vecinos vacíos: $vecinos_vacios")
            
        catch e
            println("❌ ERROR: $e")
            push!(resultados, 0.0)
            push!(tiempos_ejecucion, 0.0)
        end
    end
    
    # Calcular estadísticas
    resultados_validos = filter(x -> x > 0, resultados)
    n_validos = length(resultados_validos)
    
    if n_validos > 0
        mejor = maximum(resultados_validos)
        peor = minimum(resultados_validos)
        promedio = mean(resultados_validos)
        mediana = median(resultados_validos)
        desv = std(resultados_validos)
        cv = desv / promedio * 100
        
        tiempo_promedio = mean(filter(x -> x > 0, tiempos_ejecucion))
        tiempo_total = sum(tiempos_ejecucion)
    else
        mejor = peor = promedio = mediana = desv = cv = 0.0
        tiempo_promedio = tiempo_total = 0.0
    end
    
    # Mostrar resultados
    println("\n" * "="^60)
    println("📊 ESTADÍSTICAS FINALES")
    println("="^60)
    println("✅ Experimentos exitosos: $n_validos/$repeticiones")
    println("🏆 Mejor resultado: $(round(mejor, digits=3))")
    println("💔 Peor resultado: $(round(peor, digits=3))")
    println("📈 Promedio: $(round(promedio, digits=3))")
    println("📊 Mediana: $(round(mediana, digits=3))")
    println("🧮 Desviación estándar: $(round(desv, digits=3))")
    println("📏 Coeficiente de variación: $(round(cv, digits=2))%")
    println("⏱️ Tiempo promedio: $(round(tiempo_promedio, digits=2))s")
    println("⏰ Tiempo total: $(round(tiempo_total, digits=2))s")
    println("🚫 Total vecinos no factibles: $contador_vecinos_vacios_total")
    println("📉 Promedio vecinos no factibles: $(round(contador_vecinos_vacios_total/repeticiones, digits=1))")
    
    # Análisis de convergencia
    if usar_version_mejorada && !isempty(mejores_por_iteracion)
        println("\n🔄 ANÁLISIS DE CONVERGENCIA:")
        
        iteraciones_mejor = [length(mejores) > 1 ? mejores[end][2] : 0 for mejores in mejores_por_iteracion]
        iter_promedio_mejor = mean(filter(x -> x > 0, iteraciones_mejor))
        
        println("🎯 Iteración promedio del mejor: $(round(iter_promedio_mejor, digits=1))")
        
        umbral_temprano = max_iter * 0.25
        mejoras_tempranas = count(x -> x <= umbral_temprano, iteraciones_mejor)
        pct_tempranas = mejoras_tempranas / length(iteraciones_mejor) * 100
        
        println("🚀 Mejoras tempranas (< $(floor(Int, umbral_temprano)) iter): $(round(pct_tempranas, digits=1))%")
    end
    
    # Generar gráficos si se guardó evolución
    if guardar_evolucion && !isempty(evoluciones)
        generar_graficos_analisis(evoluciones, resultados_validos, path_instancia, usar_version_mejorada)
    end
    
    return (
        resultados = resultados_validos,
        estadisticas = (
            mejor = mejor,
            peor = peor,
            promedio = promedio,
            mediana = mediana,
            desviacion = desv,
            cv = cv,
            tiempo_promedio = tiempo_promedio,
            vecinos_vacios_promedio = contador_vecinos_vacios_total / repeticiones
        ),
        evoluciones = evoluciones,
        mejores_por_iteracion = mejores_por_iteracion
    )
end

# Función para comparar versiones (original vs mejorada)
function comparar_versiones(path_instancia::String, repeticiones::Int; semilla_base=42)
    println("🔬 COMPARACIÓN: VERSIÓN ORIGINAL vs MEJORADA")
    println("="^70)
    
    println("\n2️⃣ PROBANDO VERSIÓN MEJORADA...")
    resultado_mejorado = correr_repetidas_veces_mejorado(
        path_instancia, repeticiones; 
        usar_version_mejorada=true, 
        guardar_evolucion=true,
        semilla_base=semilla_base
    )
    
    return resultado_mejorado
end

# Función para generar gráficos de análisis
function generar_graficos_analisis(evoluciones, resultados, instancia_nombre, es_mejorado)
    if isempty(evoluciones)
        return
    end
    
    try
        # Crear directorio results si no existe
        if !isdir("results")
            mkdir("results")
        end
        
        # Gráfico 1: Evolución promedio
        max_len = maximum(length.(evoluciones))
        evolucion_promedio = zeros(max_len)
        contadores = zeros(Int, max_len)
        
        for evol in evoluciones
            for (i, val) in enumerate(evol)
                evolucion_promedio[i] += val
                contadores[i] += 1
            end
        end
        
        evolucion_promedio ./= max.(contadores, 1)
        
        p1 = plot(1:max_len, evolucion_promedio,
                 title="Evolución Promedio - $(es_mejorado ? "Mejorado" : "Original")",
                 xlabel="Iteración", ylabel="Valor Objetivo",
                 label="Promedio", linewidth=2, color=:blue)
        
        # Gráfico 2: Histograma de resultados finales
        p2 = histogram(resultados,
                      title="Distribución de Resultados Finales",
                      xlabel="Valor Objetivo", ylabel="Frecuencia",
                      label="", alpha=0.7, color=:green)
        
        # Combinar gráficos
        plot_final = plot(p1, p2, layout=(2,1), size=(800, 600))
        
        # Guardar
        nombre_archivo = replace(instancia_nombre, "/" => "_", ".txt" => "")
        sufijo = es_mejorado ? "_mejorado" : "_original"
        savefig(plot_final, "results/analisis_$(nombre_archivo)$(sufijo).png")
        
        println("📊 Gráficos guardados en: results/analisis_$(nombre_archivo)$(sufijo).png")
        
    catch e
        println("⚠️ Error generando gráficos: $e")
    end
end

# ========================================
# EJEMPLOS DE USO
# ========================================

# Ejemplo 1: Probar solo la versión mejorada
function test_mejorado_simple()
    resultado = correr_repetidas_veces_mejorado(
        "../data/instancia10.txt", 
        5;
        usar_version_mejorada=true,
        guardar_evolucion=true,
        semilla_base=42
    )
    return resultado
end

# Ejemplo 2: Comparación completa
function test_comparacion_completa()
    return comparar_versiones("../data/instancia01.txt", 10; semilla_base=42)
end

# Ejemplo 3: Análisis de múltiples instancias
function test_multiple_instancias()
    instancias = ["../data/instancia01.txt", "../data/instancia02.txt", "../data/instancia05.txt"]
    resultados = Dict()
    
    for instancia in instancias
        println("\n🔬 Analizando $instancia...")
        try
            resultado = correr_repetidas_veces_mejorado(
                instancia, 15;
                usar_version_mejorada=true,
                guardar_evolucion=false
            )
            resultados[instancia] = resultado
        catch e
            println("❌ Error en $instancia: $e")
        end
    end
    
    return resultados
end

# ========================================
# LLAMADA PRINCIPAL
# ========================================

# Opción 1: Solo versión mejorada
println("🧪 Ejecutando test con versión mejorada...")
test_mejorado_simple()

# Opción 2: Comparación completa (comenta la línea anterior y descomenta esta)
# println("🧪 Ejecutando comparación completa...")
#test_comparacion_completa()

# Opción 3: Múltiples instancias (comenta las anteriores y descomenta esta)
# println("🧪 Ejecutando análisis de múltiples instancias...")
#test_multiple_instancias()