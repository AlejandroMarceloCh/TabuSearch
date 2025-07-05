# main.jl
# ========================================
# EXPERIMENTOS MULTIPLE RUNS CON ESTADÍSTICAS
# SISTEMA CAMALEÓNICO INTEGRADO - CORREGIDO
# ========================================

include("core/classifier.jl")
include("core/base.jl")
include("solvers/pequenas/pequenas.jl")
include("solvers/medianas/medianas.jl")
include("solvers/grandes/grandes.jl")
include("solvers/enormes/enormes.jl")
include("utils/data_loader.jl")
# include("utils/visualization.jl")

# using Plots, StatsPlots, DataFrames, CSV
using Statistics
using Printf
using Dates

# ========================================
# FUNCIÓN UNIVERSAL ENCAPSULADORA
# ========================================

"""
🎯 FUNCIÓN UNIVERSAL - resolver_instancia()
"""
function resolver_instancia(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int; semilla=nothing, mostrar_detalles=false)

    # 1. CLASIFICAR AUTOMÁTICAMENTE
    config = clasificar_instancia(roi, upi, LB, UB)
    
    if mostrar_detalles
        println("🔍 CLASIFICACIÓN AUTOMÁTICA:")
        mostrar_info_instancia(config)
        println("🎯 Aplicando solver: $(uppercase(string(config.tipo)))")
    end
    
    # 2. EJECUTAR SOLVER SEGÚN TIPO
    resultado = if config.tipo == :pequeña
        resolver_pequena(roi, upi, LB, UB; semilla=semilla, mostrar_detalles=mostrar_detalles)
        
    elseif config.tipo == :mediana
        resolver_mediana(roi, upi, LB, UB; semilla=semilla, mostrar_detalles=mostrar_detalles)
        
    elseif config.tipo == :grande
        resolver_grande(roi, upi, LB, UB; semilla=semilla, mostrar_detalles=mostrar_detalles)
            
    else # :enorme
        resolver_enorme(roi, upi, LB, UB; semilla=semilla, mostrar_detalles=mostrar_detalles)
    end
    
    # 3. RETORNO CONSISTENTE
    return (
        solucion = resultado.solucion,
        valor = resultado.valor,
        tiempo = resultado.tiempo,
        mejora = resultado.mejora,
        config = resultado.config,
        factible = resultado.factible
    )
end

# ========================================
# FUNCIÓN DE EXPERIMENTOS
# ========================================

function correr_muchas_veces(nombre_instancia::String, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int;
                            veces::Int = 5, mostrar_detalles_run=false)
    
    println("\n" * "="^60)
    println("⚙️ EXPERIMENTO MÚLTIPLE: '$nombre_instancia'")
    println("🔄 Repeticiones programadas: $veces")
    println("="^60)
    
    # Mostrar info de la instancia
    config_preview = clasificar_instancia(roi, upi, LB, UB)
    println("🏷️ Tipo: $(uppercase(string(config_preview.tipo)))")
    println("🚨 Patológica: $(config_preview.es_patologica)")
    println("📊 Dimensiones: $(config_preview.ordenes)×$(config_preview.items)×$(config_preview.pasillos)")
    println("📈 Límites: LB=$LB, UB=$UB")
    
    # Arrays para estadísticas
    resultados = Float64[]
    mejoras = Float64[]
    tiempos = Float64[]
    factibles = Bool[]
    errores = 0
    config_final = nothing
    
    println("\n🚀 INICIANDO EXPERIMENTOS...")
    
    for i in 1:veces
        println("\n" * "-"^40)
        println("🚀 EXPERIMENTO $i/$veces")
        println("-"^40)
        
        try
            resultado = resolver_instancia(roi, upi, LB, UB; semilla=i*101, mostrar_detalles=mostrar_detalles_run)
            
            push!(resultados, resultado.valor)
            push!(mejoras, resultado.mejora)
            push!(tiempos, resultado.tiempo)
            push!(factibles, resultado.factible)
            config_final = resultado.config
            
            status = resultado.factible ? "✅ FACTIBLE" : "❌ NO FACTIBLE"
            println("📊 Experimento $i: Ratio=$(round(resultado.valor, digits=3)) | Tiempo=$(round(resultado.tiempo, digits=2))s | $status")
            
        catch e
            println("❌ ERROR en experimento $i: $e")
            errores += 1
        end
    end
    
    # ========================================
    # ESTADÍSTICAS FINALES
    # ========================================
    
    exitosos = veces - errores
    factibles_count = sum(factibles)
    
    # Mostrar estadísticas básicas
    if !isempty(resultados)
        println("\n📊 ESTADÍSTICAS:")
        println("   📈 Ratio promedio: $(round(mean(resultados), digits=3))")
        println("   🏆 Mejor ratio: $(round(maximum(resultados), digits=3))")
        println("   ⏰ Tiempo promedio: $(round(mean(tiempos), digits=2))s")
        println("   ✅ Factibles: $(factibles_count)/$exitosos")
    end
    
    if config_final !== nothing
        println("\n🔧 SOLVER USADO:")
        println("   🏷️ Tipo: $(uppercase(string(config_final.tipo)))")
        println("   🚨 Patológica: $(config_final.es_patologica)")
        println("   ⚙️ Estrategia: $(config_final.estrategia_constructiva)")
    end
    
    println("\n📅 Completado: $(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))")
    
    return (
        resultados = resultados,
        mejoras = mejoras, 
        tiempos = tiempos,
        factibles = factibles,
        exitosos = exitosos,
        config = config_final
    )
end

# ========================================
# FUNCIÓN DE DEBUGGING
# ========================================

function resolver_una_vez(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int; semilla=nothing)
    println("🔍 EJECUCIÓN ÚNICA CON DETALLES")
    println("="^40)
    
    resultado = resolver_instancia(roi, upi, LB, UB; semilla=semilla, mostrar_detalles=true)
    
    println("\n🎯 RESULTADO:")
    println("📊 Valor: $(round(resultado.valor, digits=4))")
    println("📈 Mejora: $(round(resultado.mejora, digits=4))")
    println("⏱️ Tiempo: $(round(resultado.tiempo, digits=2))s")
    println("✅ Factible: $(resultado.factible)")
    
    return resultado
end








# ========================================
# EJECUCIÓN PRINCIPAL
# ========================================

println("🚀 SISTEMA CAMALEÓNICO DE OPTIMIZACIÓN")
println("🏗️ Arquitectura: Base Camaleónica + Solvers Especializados")
println("="^60)

# ✅ CARGAR INSTANCIA (formato correcto del data_loader)
archivo = "data/instancia05.txt"
println("📂 Cargando: $archivo")

try
    # ✅ TU data_loader retorna exactamente lo que necesita el core
    roi, upi, LB, UB = cargar_instancia(archivo)
    
    # Calcular dimensiones automáticamente (como hace el core)
    O, I = size(roi)
    P = size(upi, 1)
    
    println("✅ Instancia cargada: $(O)×$(I)×$(P), LB=$LB, UB=$UB")    
    
    # 🎯 EJECUTAR EXPERIMENTOS
    println("\n🚀 Iniciando experimentos...")
    # OPCIÓN 1: Una sola instancia (como antes)
    resultado = resolver_una_vez(roi, upi, LB, UB; semilla=123)
    




catch e
    println("❌ ERROR: $e")
    println("\n🔍 VERIFICACIONES:")
    println("1. ¿Existe el archivo 'data/instancia20.txt'?")
    println("2. ¿Existe el archivo 'solvers/pequenas/pequenas.jl'?")
    println("3. ¿Qué retorna tu función cargar_instancia()?")
    
    # Mostrar estructura de directorios
    println("\n📁 ARCHIVOS EN DIRECTORIO ACTUAL:")
    try
        for file in readdir(".")
            println("   - $file")
        end
    catch
        println("   ❌ No se puede leer directorio")
    end
    
    if isdir("solvers")
        println("\n📁 ARCHIVOS EN SOLVERS:")
        try
            for file in readdir("solvers")
                println("   - solvers/$file")
            end
        catch
            println("   ❌ No se puede leer solvers/")
        end
    end
end