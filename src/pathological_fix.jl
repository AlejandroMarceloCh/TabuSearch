# pathological_fix.jl
# Solución completa para instancias patológicas - Factores adaptativos

# ========================================
# 1. DETECCIÓN DE INSTANCIAS PATOLÓGICAS
# ========================================

"""
Detecta si una instancia es patológica según criterios establecidos
"""
function es_instancia_patologica(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int)
    O, I, P = size(roi, 1), size(roi, 2), size(upi, 1)
    
    # Criterio 1: Ratio UB/LB > 4.0
    ratio_ub_lb = UB / LB
    
    # Criterio 2: Muchos pasillos relativos a órdenes
    ratio_pasillos_ordenes = P / O
    
    # Criterio 3: Estimación de eficiencia esperada muy baja
    demanda_total_posible = sum(roi)
    eficiencia_estimada = demanda_total_posible / P
    umbral_eficiencia = LB * 0.2  # 20% del LB
    
    # Es patológica si cumple al menos 2 de 3 criterios
    criterios_cumplidos = 0
    
    if ratio_ub_lb > 4.0
        criterios_cumplidos += 1
    end
    
    if ratio_pasillos_ordenes > 0.15  # Más de 15% pasillos vs órdenes
        criterios_cumplidos += 1
    end
    
    if eficiencia_estimada < umbral_eficiencia
        criterios_cumplidos += 1
    end
    
    es_patologica = criterios_cumplidos >= 2
    
    # Calcular factor de gravedad (1.5 a 3.0)
    factor_gravedad = if es_patologica
        base = 1.5
        incremento_ratio = min(1.0, (ratio_ub_lb - 4.0) / 6.0)  # 0-1 para ratio 4-10
        incremento_eficiencia = min(0.5, (umbral_eficiencia - eficiencia_estimada) / umbral_eficiencia)
        min(3.0, base + incremento_ratio + incremento_eficiencia)
    else
        1.0
    end
    
    return es_patologica, factor_gravedad
end



# LÍNEA ~50 en pathological_fix.jl - REEMPLAZAR COMPLETA
function calcular_limites_adaptativos(O::Int, P::Int, ordenes_count::Int, es_patologica::Bool, factor::Float64)
    if !es_patologica
        # Límites originales para instancias normales
        return (
            max_ordenes_normal = min(O ÷ 4, max(800, O ÷ 6)),
            max_ordenes_masiva = min(O ÷ 3, max(2000, O ÷ 8)),
            max_pasillos_normal = min(P ÷ 4, max(25, ordenes_count ÷ 15)),
            max_pasillos_masiva = min(P ÷ 3, max(50, ordenes_count ÷ 20)),
            pasillos_fallback = 3,
            max_iter_gigante = 80,
            max_no_improve_gigante = 12,
            max_vecinos_gigante = 20,
            intentos_reparacion = 3,
            iteraciones_reparacion = 5,
            umbral_perturbacion = 2,
            usar_todos_movimientos = false
        )
    else
        # LÍMITES REALMENTE ADAPTATIVOS PARA PATOLÓGICAS
        # Usar porcentajes del total en lugar de números fijos
        max_ordenes_adaptativo = Int(ceil(O * min(0.9, 0.4 + factor * 0.2)))  # 40-90% según factor
        max_pasillos_adaptativo = Int(ceil(P * min(0.8, 0.3 + factor * 0.25))) # 30-80% según factor
        
        return (
            max_ordenes_normal = max_ordenes_adaptativo,
            max_ordenes_masiva = min(O, Int(ceil(max_ordenes_adaptativo * 1.2))),
            max_pasillos_normal = max_pasillos_adaptativo,
            max_pasillos_masiva = min(P, Int(ceil(max_pasillos_adaptativo * 1.3))),
            pasillos_fallback = min(20, P ÷ 15),
            max_iter_gigante = 200,
            max_no_improve_gigante = 50,
            max_vecinos_gigante = 100,
            intentos_reparacion = 10,
            iteraciones_reparacion = 20,
            umbral_perturbacion = 1,
            usar_todos_movimientos = true
        )
    end
end


# ========================================
# 3. SOBRESCRIBIR FUNCIONES CRÍTICAS
# ========================================

# Variable global para almacenar el estado de la instancia
if !(@isdefined INSTANCIA_STATE)
    global INSTANCIA_STATE = Dict{String, Any}()
end
"""
Función para inicializar el estado de la instancia
"""
function inicializar_instancia_state(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int)
    es_patologica, factor = es_instancia_patologica(roi, upi, LB, UB)
    O, P = size(roi, 1), size(upi, 1)
    
    INSTANCIA_STATE["es_patologica"] = es_patologica
    INSTANCIA_STATE["factor_gravedad"] = factor
    INSTANCIA_STATE["limites"] = calcular_limites_adaptativos(O, P, 0, es_patologica, factor)
    
    if es_patologica
        println("🚨 INSTANCIA PATOLÓGICA DETECTADA")
        println("   Factor de gravedad: $(round(factor, digits=2))")
        println("   Aplicando límites relajados...")
    else
        println("✅ Instancia normal detectada")
    end
    
    return es_patologica, factor
end




"""
SOBRESCRIBIR: Parámetros de Tabu Search para patológicas
"""
function obtener_parametros_tabu_adaptativos(tipo_instancia::Symbol, es_gigante::Bool)
    limites = get(INSTANCIA_STATE, "limites", nothing)
    
    if limites === nothing || !get(INSTANCIA_STATE, "es_patologica", false)
        # Parámetros originales para instancias normales
        if es_gigante
            if tipo_instancia == :gigante
                return (max_iter = 80, max_no_improve = 12, max_vecinos = 20)
            else  # masiva
                return (max_iter = 150, max_no_improve = 25, max_vecinos = 35)
            end
        elseif tipo_instancia == :grande
            return (max_iter = 150, max_no_improve = 20, max_vecinos = 30)
        else
            return (max_iter = 175, max_no_improve = 25, max_vecinos = 45)
        end
    else
        # Parámetros adaptativos para patológicas
        return (
            max_iter = limites.max_iter_gigante,
            max_no_improve = limites.max_no_improve_gigante,
            max_vecinos = limites.max_vecinos_gigante
        )
    end
end

# ========================================
# 5. FUNCIÓN DE INICIALIZACIÓN
# ========================================

"""
Función principal que debe llamarse al inicio para configurar toda la instancia
"""
function configurar_instancia_patologica(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int)
    es_patologica, factor = inicializar_instancia_state(roi, upi, LB, UB)
    
    if es_patologica
        println("🔧 Configuración adaptativa activada:")
        limites = INSTANCIA_STATE["limites"]
        println("   • Límite órdenes: $(limites.max_ordenes_normal) (normal) / $(limites.max_ordenes_masiva) (masiva)")
        println("   • Límite pasillos: $(limites.max_pasillos_normal) (normal) / $(limites.max_pasillos_masiva) (masiva)")
        println("   • Pasillos fallback: $(limites.pasillos_fallback)")
        println("   • Tabu Search: iter=$(limites.max_iter_gigante), no_improve=$(limites.max_no_improve_gigante), vecinos=$(limites.max_vecinos_gigante)")
        println("   • Todos los movimientos habilitados: $(limites.usar_todos_movimientos)")
    end
    
    return es_patologica, factor
end

println("✅ Sistema de detección y corrección de instancias patológicas cargado")
println("📝 Para usar: llamar configurar_instancia_patologica(roi, upi, LB, UB) al inicio")