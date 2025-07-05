# core/classifier.jl
# ========================================
# CLASIFICADOR AUTOMÁTICO DE INSTANCIAS
# ========================================
include("config_instancia.jl")

"""
Clasifica automáticamente una instancia según sus características
Retorna una ConfigInstancia con toda la información relevante
"""
function clasificar_instancia(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int)
    O, I = size(roi)
    P = size(upi, 1)
    
    # Calcular métricas básicas
    ratio_ub_lb = LB > 0 ? UB / LB : Inf
    demanda_total = sum(roi)
    capacidad_total = sum(upi)
    pasillos_teoricos = demanda_total / (capacidad_total / P)
    tamaño_efectivo = O * I
    
    # Clasificación por tamaño
    tipo = if O <= 20 || tamaño_efectivo <= 1000
        :pequeña
    elseif O <= 150 || tamaño_efectivo <= 15000
        :mediana
    elseif O <= 1000 || tamaño_efectivo <= 100000
        :grande
    else
        :enorme
    end
    
    # Detección de patologías
    es_patologica = detectar_patologia(roi, upi, LB, UB, ratio_ub_lb, pasillos_teoricos)
    tipos_patologia = es_patologica ? [:patologica] : []
    
    # DEFINIR ESTRATEGIAS SEGÚN TIPO Y PATOLOGÍA
    if tipo == :pequeña
        estrategia_constructiva = :multiples_greedy_estandar
        estrategia_factibilidad = :verificacion_exhaustiva
        estrategia_pasillos = :algoritmo_optimo
        estrategia_vecindarios = :vecindarios_exhaustivos
        estrategia_tabu = :tabu_multiple_restart
        max_iteraciones = es_patologica ? 200 : 150
        max_sin_mejora = es_patologica ? 50 : 40
        tabu_size = es_patologica ? 8 : 6
        max_vecinos = es_patologica ? 25 : 20
        timeout_adaptativo = es_patologica ? 300.0 : 180.0
    elseif tipo == :mediana
        # Configuración para medianas
        estrategia_constructiva = :constructiva_balanceada
        estrategia_factibilidad = es_patologica ? :verificacion_robusta : :verificacion_inteligente
        estrategia_pasillos = :greedy_inteligente
        estrategia_vecindarios = :vecindarios_inteligentes
        estrategia_tabu = :tabu_adaptativo
        max_iteraciones = es_patologica ? 800 : 500
        max_sin_mejora = es_patologica ? 120 : 80
        tabu_size = es_patologica ? 15 : 12
        max_vecinos = es_patologica ? 80 : 60
        timeout_adaptativo = es_patologica ? 600.0 : 400.0
    elseif tipo == :grande
        # Configuración para grandes
        estrategia_constructiva = :constructiva_escalable
        estrategia_factibilidad = :verificacion_muestreo
        estrategia_pasillos = :sampling_optimizado
        estrategia_vecindarios = :vecindarios_escalables
        estrategia_tabu = :tabu_escalable
        max_iteraciones = 1000
        max_sin_mejora = 150
        tabu_size = 20
        max_vecinos = 100
        timeout_adaptativo = 900.0
    else # :enorme
        # Configuración para enormes
        estrategia_constructiva = :constructiva_heuristica
        estrategia_factibilidad = :verificacion_rapida
        estrategia_pasillos = :heuristicas_rapidas
        estrategia_vecindarios = :vecindarios_rapidos
        estrategia_tabu = :tabu_heuristico
        max_iteraciones = 1500
        max_sin_mejora = 200
        tabu_size = 25
        max_vecinos = 150
        timeout_adaptativo = 1800.0
    end
    
    return ConfigInstancia(
        tipo, es_patologica, tipos_patologia,
        O, I, P, ratio_ub_lb, pasillos_teoricos, tamaño_efectivo,
        estrategia_constructiva, estrategia_factibilidad, estrategia_pasillos,
        estrategia_vecindarios, estrategia_tabu,
        max_iteraciones, max_sin_mejora, tabu_size, max_vecinos, timeout_adaptativo
    )
end
"""
Detecta si una instancia tiene características patológicas
"""
function detectar_patologia(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, ratio_ub_lb::Float64, pasillos_teoricos::Float64)
    # Criterios de patología
    ratio_extremo = ratio_ub_lb > 10.0 || ratio_ub_lb == Inf
    muy_pocos_pasillos = pasillos_teoricos < 5.0
    pasillos_teoricos_bajo = pasillos_teoricos < 10.0
    ratio_alto = ratio_ub_lb > 5.0
    
    return ratio_extremo || muy_pocos_pasillos || (pasillos_teoricos_bajo && ratio_alto)
end

"""
Identifica el tipo específico de patología
"""
function tipo_patologia(config::ConfigInstancia)
    if !config.es_patologica
        return :normal
    end
    
    if config.ratio_ub_lb == Inf
        return :ratio_extremo
    elseif config.ratio_ub_lb > 10.0
        return :ratio_extremo
    elseif config.ratio_ub_lb > 5.0
        return :ratio_alto
    elseif config.pasillos_teoricos < 3.0
        return :muy_pocos_pasillos
    elseif config.pasillos_teoricos < 10.0
        return :pocos_pasillos
    else
        return :otra_patologia
    end
end

"""
Muestra información detallada de la clasificación
"""
function mostrar_info_instancia(config::ConfigInstancia)
    println("🏷️  CLASIFICACIÓN DE INSTANCIA")
    println("   📊 Tipo: $(uppercase(string(config.tipo)))")
    println("   🚨 Patológica: $(config.es_patologica)")
    if config.es_patologica
        println("   🔍 Tipo patología: $(tipo_patologia(config))")
    end
    println("   📏 Dimensiones: $(config.ordenes)×$(config.items) ($(config.pasillos) pasillos)")
    println("   📐 Ratio UB/LB: $(round(config.ratio_ub_lb, digits=1))")
    println("   🏢 Pasillos teóricos: $(round(config.pasillos_teoricos, digits=1))")
    println("   📈 Tamaño efectivo: $(config.tamaño_efectivo)")
end