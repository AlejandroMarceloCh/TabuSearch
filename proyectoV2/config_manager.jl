# config_manager.jl
# ========================================
# CONFIGURACIÓN DINÁMICA Y DETECCIÓN AUTOMÁTICA - PROYECTO 20/20
# ========================================

include("solution.jl")

# ========================================
# CONFIGURACIÓN DE INSTANCIA
# ========================================

struct InstanceConfig
    tipo::Symbol              # :pequeña, :mediana, :grande, :gigante
    es_gigante::Bool
    es_patologica::Bool
    factor_gravedad::Float64
    parametros::NamedTuple    # Todos los parámetros calculados dinámicamente
    mostrar_detalles::Bool    # Control simple de prints
end

"""
Crea configuración completa para cualquier instancia de forma automática
"""
function crear_configuracion_automatica(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int; 
                                       mostrar_detalles::Bool=false)
    
    O, I, P = size(roi, 1), size(roi, 2), size(upi, 1)
    tipo = clasificar_instancia(roi, upi)
    
    # ARREGLAR: Detección correcta de gigantes
    es_gigante = (tipo == :gigante) || (O > 1000 || I > 2000 || O * I > 5_000_000)
    
    es_patologica, factor = es_instancia_patologica(roi, upi, LB, UB)
    
    # Calcular parámetros dinámicamente
    parametros = calcular_parametros_dinamicos(O, I, P, tipo, es_gigante, es_patologica, factor)
    
    return InstanceConfig(tipo, es_gigante, es_patologica, factor, parametros, mostrar_detalles)
end



"""
Calcula TODOS los parámetros de forma dinámica según características de la instancia
"""

# 1. En config_manager.jl - Parámetros más adaptativos basados en el objetivo potencial
function calcular_parametros_dinamicos(O::Int, I::Int, P::Int, tipo::Symbol, 
                                     es_gigante::Bool, es_patologica::Bool, factor::Float64)
    
    # Calcular densidad de la instancia para ajustes más finos
    densidad = (O * I) / (O + I + P)^2
    es_densa = densidad > 100
    
    # PARÁMETROS PARA TABU SEARCH
    if es_gigante
        if es_patologica
            max_iter = Int(ceil(200 * factor))
            max_no_improve = Int(ceil(50 * factor))
            max_vecinos = Int(ceil(100 * factor))
        else
            # Ajuste basado en densidad y tamaño
            if es_densa
                max_iter = 150
                max_no_improve = 30
                max_vecinos = 35
            else
                max_iter = 100
                max_no_improve = 20
                max_vecinos = 25
            end
        end
    else
        # Sin cambios para normales
        if tipo == :mediana
            max_iter = 175
            max_no_improve = 25
            max_vecinos = 45
        elseif tipo == :grande
            max_iter = 150
            max_no_improve = 20
            max_vecinos = 30
        else # pequeña
            max_iter = 100
            max_no_improve = 20
            max_vecinos = 40
        end
    end
    
    # PARÁMETROS PARA GENERACIÓN INICIAL - CRÍTICO
    if es_patologica
        max_ordenes = Int(ceil(O * min(0.9, 0.4 + factor * 0.2)))
        max_pasillos = Int(ceil(P * min(0.8, 0.3 + factor * 0.25)))
        max_intentos_inicial = 50 + Int(ceil(factor * 30))
    else
        if es_gigante
            # Ajuste dinámico basado en relación O/P para estimar objetivo
            ratio_op = O / P
            if ratio_op > 10  # Muchas órdenes por pasillo (potencial objetivo alto)
                max_ordenes = Int(ceil(O * 0.6))  # Permitir hasta 60%
            elseif ratio_op > 5
                max_ordenes = Int(ceil(O * 0.4))  # Permitir hasta 40%
            else
                max_ordenes = Int(ceil(O * 0.3))  # Permitir hasta 30%
            end
            max_ordenes = min(max_ordenes, 3000)  # Límite práctico
            
            # Pasillos basado en P
            max_pasillos = min(P, max(50, Int(ceil(P * 0.6))))
        else
            max_ordenes = min(O ÷ 4, max(800, O ÷ 6))
            max_pasillos = min(P ÷ 4, max(25, min(50, O ÷ 15)))
        end
        max_intentos_inicial = es_gigante ? 40 : 60
    end
    
    # Resto de parámetros
    tabu_size = max(5, min(100, O ÷ (es_gigante ? 20 : 10)))
    intensidad_perturbacion = es_patologica ? 0.4 : (es_gigante ? 0.3 : 0.25)
    log_interval = es_gigante ? 50 : 25
    
    return (
        # Tabu Search
        max_iter = max_iter,
        max_no_improve = max_no_improve,
        max_vecinos = max_vecinos,
        tabu_size = tabu_size,
        
        # Generación inicial
        max_ordenes = max_ordenes,
        max_pasillos = max_pasillos,
        max_intentos_inicial = max_intentos_inicial,
        
        # Vecindarios y perturbación
        intensidad_perturbacion = intensidad_perturbacion,
        max_intercambios = es_gigante ? 20 : 25,
        max_crecimientos = es_gigante ? 15 : 20,
        max_reducciones = es_gigante ? 10 : 15,
        
        # Control de logging
        log_interval = log_interval,
        mostrar_evolucion = !es_gigante,
        
        # Estrategias especiales
        usar_reparacion_agresiva = es_patologica,
        permitir_todos_movimientos = es_patologica,
        usar_escape_temprano = es_gigante,
        
        # Nuevo parámetro
        factor_llenado_objetivo = es_gigante ? 0.85 : 0.7  # Llenar más cerca del UB
    )
end



# ========================================
# FUNCIONES DE PRINT LIMPIAS
# ========================================

"""
Print de información básica de instancia
"""
function mostrar_info_instancia(config::InstanceConfig, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int)
    O, I, P = size(roi, 1), size(roi, 2), size(upi, 1)
    
    println("🔎 Instancia detectada: $(config.tipo)")
    if config.es_patologica
        println("🚨 PATOLÓGICA (factor: $(round(config.factor_gravedad, digits=2)))")
    end
    println("📏 Tamaño: $O órdenes × $I ítems × $P pasillos")
    println("📊 Límites: LB=$LB, UB=$UB (ratio: $(round(UB/LB, digits=2)))")
    println("⚙️ Parámetros: iter=$(config.parametros.max_iter), vecinos=$(config.parametros.max_vecinos)")
end

"""
Print de solución con control de detalles
"""
function mostrar_solucion(sol::Solucion, roi::Matrix{Int}, config::InstanceConfig, 
                         etiqueta::String="Solución", es_mejor::Bool=false)
    
    obj = evaluar(sol, roi)
    symbol = es_mejor ? "🏆" : "📊"
    
    println("$symbol $etiqueta: $(round(obj, digits=3)) | Órdenes: $(length(sol.ordenes)) | Pasillos: $(length(sol.pasillos))")
    
    # Solo mostrar detalles si se solicita Y la lista no es muy larga
    if config.mostrar_detalles
        if length(sol.ordenes) <= 20
            ordenes = sort(collect(sol.ordenes))
            println("   📦 Órdenes: $ordenes")
        end
        
        if length(sol.pasillos) <= 15
            pasillos = sort(collect(sol.pasillos))
            println("   🚪 Pasillos: $pasillos")
        end
    end
end

"""
Print de progreso durante búsqueda
"""
function mostrar_progreso(iter::Int, obj_actual::Float64, mejor_obj::Float64, 
                         sin_mejora::Int, config::InstanceConfig, info_extra::String="")
    
    println("📈 Iter $iter: Actual=$(round(obj_actual, digits=3)), " *
           "Mejor=$(round(mejor_obj, digits=3)), Sin mejora=$sin_mejora $info_extra")
end

"""
Print de inicio de algoritmo
"""
function mostrar_inicio_busqueda(config::InstanceConfig)
    tipo_busqueda = config.es_gigante ? "rápida" : "estándar"
    println("🚀 Iniciando búsqueda $tipo_busqueda...")
end

"""
Print de finalización con estadísticas
"""
function mostrar_finalizacion(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int,
                             iter::Int, contador_vacios::Int, mejoras_encontradas::Int, config::InstanceConfig)
    
    println("\n🎯 Búsqueda completada!")
    mostrar_solucion(sol, roi, config, "RESULTADO FINAL", true)
    println("📊 Iteraciones: $iter | Vecinos vacíos: $contador_vacios | Mejoras: $mejoras_encontradas")
    
    # Verificación final
    if es_factible_rapido(sol, roi, upi, LB, UB)
        println("✅ Solución FACTIBLE verificada")
    else
        println("❌ ADVERTENCIA: Solución posiblemente NO FACTIBLE")
    end
    
    # Estadísticas adicionales
    stats = estadisticas_solucion(sol, roi, upi)
    println("📈 Eficiencia: $(round(stats.eficiencia, digits=3)) unidades/pasillo")
    println("💾 Utilización: $(round(stats.unidades_totales/UB*100, digits=1))% de capacidad máxima")
end

"""
Print de diagnóstico rápido (solo si hay problemas)
"""
function diagnostico_rapido(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int)
    demanda_total = sum(roi)
    capacidad_total = sum(upi)
    
    if demanda_total < UB
        println("⚠️ ADVERTENCIA: Demanda total ($demanda_total) < UB ($UB)")
    end
    
    if capacidad_total < UB
        println("❌ ERROR: Capacidad total ($capacidad_total) < UB ($UB)")
        return false
    end
    
    return true
end