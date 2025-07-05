# solvers/grandes/grandes.jl
# ========================================
# SOLVER PRINCIPAL VNS + LNS HÍBRIDO SÚPER AGRESIVO
# ========================================

include("../../core/base.jl")
include("../../core/classifier.jl")
include("grandes_constructivas.jl")
include("grandes_vecindarios.jl")

using Combinatorics

using Random

# ========================================
# FUNCIÓN PRINCIPAL SOLVER GRANDES
# ========================================

"""
🔥 SOLVER PRINCIPAL PARA INSTANCIAS GRANDES 🔥
Estrategia híbrida: Constructiva Multistart → VNS → LNS → Post-optimización
"""
function resolver_grande(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int; semilla=nothing, mostrar_detalles=true)
    
    # 1. CLASIFICAR AUTOMÁTICAMENTE usando la base
    config = clasificar_instancia(roi, upi, LB, UB)
    
    if mostrar_detalles
        println("\n" * "🔥"^60)
        println("🔥 SOLVER GRANDES - MODO DESTRUCCIÓN TOTAL 🔥")
        println("🔥"^60)
        mostrar_info_instancia(config)
        println("\n🎯 CONFIGURACIÓN AUTOMÁTICA APLICADA:")
        println("   📦 Constructiva: $(config.estrategia_constructiva)")
        println("   ✅ Factibilidad: $(config.estrategia_factibilidad)")
        println("   🚪 Pasillos: $(config.estrategia_pasillos)")
        println("   🔄 Vecindarios: $(config.estrategia_vecindarios)")
        println("   ⚙️ Max iter: $(config.max_iteraciones) | Max vecinos: $(config.max_vecinos)")
        println("   ⏰ Timeout: $(config.timeout_adaptativo)s")
        if config.es_patologica
            println("   🚨 MODO PATOLÓGICO ACTIVADO - MÁXIMA AGRESIVIDAD")
        end
    end
    
    tiempo_inicio = time()
    
    # 2. FASE 1: CONSTRUCTIVA MULTISTART AGRESIVA (15% del tiempo)
    tiempo_constructiva = config.timeout_adaptativo * 0.15
    if mostrar_detalles
        println("\n🚀 FASE 1: CONSTRUCTIVA MULTISTART AGRESIVA")
        println("   ⏰ Tiempo asignado: $(round(tiempo_constructiva, digits=1))s")
    end
    
    solucion_inicial = generar_solucion_inicial_grande(roi, upi, LB, UB, config; semilla=semilla)
    
    if solucion_inicial === nothing
        error("❌ No se pudo generar solución inicial para instancia grande")
    end
    
    valor_inicial = evaluar(solucion_inicial, roi)
    
    if mostrar_detalles
        println("\n✅ CONSTRUCTIVA COMPLETADA:")
        mostrar_solucion(solucion_inicial, roi, "CONSTRUCTIVA")
        println("📊 Factible: $(es_factible(solucion_inicial, roi, upi, LB, UB, config))")
    end
    
    # 3. FASE 2: VNS - EXPLORACIÓN SISTEMÁTICA (60% del tiempo - MÁXIMA PRIORIDAD)
    tiempo_vns = config.timeout_adaptativo * 0.6
    if mostrar_detalles
        println("\n🔄 FASE 2: VARIABLE NEIGHBORHOOD SEARCH")
        println("   ⏰ Tiempo asignado: $(round(tiempo_vns, digits=1))s")
    end
    
    solucion_vns = variable_neighborhood_search(solucion_inicial, roi, upi, LB, UB, config; 
                                              max_tiempo=tiempo_vns, mostrar_progreso=mostrar_detalles)
    
    valor_vns = evaluar(solucion_vns, roi)
    mejora_vns = valor_vns - valor_inicial
    
    if mostrar_detalles
        println("\n✅ VNS COMPLETADO:")
        mostrar_solucion(solucion_vns, roi, "VNS")
        println("📈 Mejora VNS: +$(round(mejora_vns, digits=3)) ($(round((mejora_vns/valor_inicial)*100, digits=1))%)")
    end
    
    # 4. FASE 3: LNS - INTENSIFICACIÓN AGRESIVA (20% del tiempo)
    tiempo_lns = config.timeout_adaptativo * 0.2
    if mostrar_detalles
        println("\n🔨 FASE 3: LARGE NEIGHBORHOOD SEARCH")
        println("   ⏰ Tiempo asignado: $(round(tiempo_lns, digits=1))s")
    end
    
    solucion_lns = large_neighborhood_search(solucion_vns, roi, upi, LB, UB, config; 
                                           max_tiempo=tiempo_lns, mostrar_progreso=mostrar_detalles)
    
    valor_lns = evaluar(solucion_lns, roi)
    mejora_lns = valor_lns - valor_vns
    
    if mostrar_detalles
        println("\n✅ LNS COMPLETADO:")
        mostrar_solucion(solucion_lns, roi, "LNS")
        println("📈 Mejora LNS: +$(round(mejora_lns, digits=3)) ($(round((mejora_lns/valor_vns)*100, digits=1))%)")
    end
    
    # 5. FASE 4: POST-OPTIMIZACIÓN FINAL (5% del tiempo)
    tiempo_post = config.timeout_adaptativo * 0.05
    if mostrar_detalles
        println("\n⚡ FASE 4: POST-OPTIMIZACIÓN FINAL")
        println("   ⏰ Tiempo asignado: $(round(tiempo_post, digits=1))s")
    end
    
    # GUARDAR BACKUP DE SOLUCIÓN FACTIBLE ANTES DE POST-OPTIMIZACIÓN
    solucion_backup = copiar_solucion(solucion_lns)
    valor_backup = valor_lns
    
    solucion_final = post_optimizacion_grandes(solucion_lns, roi, upi, LB, UB, config; 
                                             max_tiempo=tiempo_post, mostrar_progreso=mostrar_detalles)
    
    valor_final = evaluar(solucion_final, roi)
    mejora_post = valor_final - valor_lns
    
    # VERIFICACIÓN OBLIGATORIA DE FACTIBILIDAD FINAL
    if !es_factible(solucion_final, roi, upi, LB, UB, config)
        if mostrar_detalles
            println("   ⚠️ POST-OPTIMIZACIÓN GENERÓ SOLUCIÓN NO FACTIBLE - RESTAURANDO BACKUP")
        end
        solucion_final = solucion_backup
        valor_final = valor_backup
        mejora_post = 0.0  # Sin mejora de post-optimización
    end
    
    # 6. ESTADÍSTICAS FINALES
    tiempo_total = time() - tiempo_inicio
    mejora_total = valor_final - valor_inicial
    
    if mostrar_detalles
        println("\n" * "🏆"^60)
        println("🏆 RESULTADO FINAL GRANDES - MODO DESTRUCCIÓN")
        println("🏆"^60)
        mostrar_solucion(solucion_final, roi, "RESULTADO FINAL")
        
        println("\n📊 RESUMEN DE MEJORAS:")
        println("   🚀 Constructiva → VNS: +$(round(mejora_vns, digits=3)) ($(round((mejora_vns/valor_inicial)*100, digits=1))%)")
        println("   🔄 VNS → LNS: +$(round(mejora_lns, digits=3)) ($(round((mejora_lns/valor_vns)*100, digits=1))%)")
        println("   ⚡ LNS → Final: +$(round(mejora_post, digits=3)) ($(round((mejora_post/valor_lns)*100, digits=1))%)")
        println("   🎯 MEJORA TOTAL: +$(round(mejora_total, digits=3)) ($(round((mejora_total/valor_inicial)*100, digits=1))%)")
        
        println("\n⏱️ DISTRIBUCIÓN DE TIEMPO:")
        println("   📊 Tiempo total: $(round(tiempo_total, digits=2))s")
        println("   🚀 Constructiva: $(round(tiempo_constructiva, digits=1))s (15%)")
        println("   🔄 VNS: $(round(tiempo_vns, digits=1))s (60%)")
        println("   🔨 LNS: $(round(tiempo_lns, digits=1))s (20%)")
        println("   ⚡ Post-opt: $(round(tiempo_post, digits=1))s (5%)")
        
        println("\n🔍 ANÁLISIS DE SOLUCIÓN:")
        unidades_totales = sum(sum(roi[o, :]) for o in solucion_final.ordenes)
        utilizacion_ub = (unidades_totales / UB) * 100
        eficiencia_pasillos = unidades_totales / length(solucion_final.pasillos)
        
        println("   📦 Órdenes seleccionadas: $(length(solucion_final.ordenes))/$(size(roi,1)) ($(round((length(solucion_final.ordenes)/size(roi,1))*100, digits=1))%)")
        println("   🚪 Pasillos utilizados: $(length(solucion_final.pasillos))/$(size(upi,1)) ($(round((length(solucion_final.pasillos)/size(upi,1))*100, digits=1))%)")
        println("   💰 Unidades totales: $unidades_totales")
        println("   📊 Utilización UB: $(round(utilizacion_ub, digits=1))%")
        println("   ⚡ Eficiencia (unidades/pasillo): $(round(eficiencia_pasillos, digits=2))")
        
        # Verificación final usando la base
        factible = es_factible(solucion_final, roi, upi, LB, UB, config)
        println("\n$(factible ? "✅" : "❌") Solución $(factible ? "FACTIBLE" : "NO FACTIBLE")")
        
        if config.es_patologica
            println("\n🚨 INSTANCIA PATOLÓGICA CONQUISTADA 🚨")
        end
        
        println("🏆"^60)
    end
    
    return (
        solucion = solucion_final,
        valor = valor_final,
        tiempo = tiempo_total,
        mejora = mejora_total,
        config = config,
        factible = es_factible(solucion_final, roi, upi, LB, UB, config),
        mejoras_por_fase = (
            constructiva = valor_inicial,
            vns = mejora_vns,
            lns = mejora_lns,
            post = mejora_post
        )
    )
end

# ========================================
# POST-OPTIMIZACIÓN FINAL
# ========================================

"""
Post-optimización final: Pulir detalles y buscar últimas mejoras
"""
function post_optimizacion_grandes(solucion::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia; max_tiempo=60.0, mostrar_progreso=true)
    
    tiempo_inicio = time()
    mejor = copiar_solucion(solucion)
    mejor_valor = evaluar(mejor, roi)
    
    if mostrar_progreso
        println("   🔧 Iniciando post-optimización...")
    end
    
    # 1. RE-OPTIMIZACIÓN FINAL DE PASILLOS
    pasillos_finales = calcular_pasillos_optimos(mejor.ordenes, roi, upi, LB, UB, config)
    if pasillos_finales != mejor.pasillos
        candidato = Solucion(mejor.ordenes, pasillos_finales)
        if es_factible(candidato, roi, upi, LB, UB, config)
            valor_candidato = evaluar(candidato, roi)
            if valor_candidato > mejor_valor
                mejora = valor_candidato - mejor_valor
                mejor = candidato
                mejor_valor = valor_candidato
                if mostrar_progreso
                    println("   ✅ Pasillos re-optimizados: +$(round(mejora, digits=3))")
                end
            end
        end
    end
    
    # 2. BÚSQUEDA LOCAL INTENSIVA FINAL
    tiempo_restante = max_tiempo - (time() - tiempo_inicio)
    if tiempo_restante > 10.0
        mejor_local = busqueda_local_intensiva_final(mejor, roi, upi, LB, UB, config, tiempo_restante)
        valor_local = evaluar(mejor_local, roi)
        
        if valor_local > mejor_valor
            mejora_local = valor_local - mejor_valor
            mejor = mejor_local
            mejor_valor = valor_local
            
            if mostrar_progreso
                println("   🚀 Búsqueda local final: +$(round(mejora_local, digits=3))")
            end
        end
    end
    
    # 3. FASE DE OPTIMIZACIÓN CONSERVADORA CON FACTIBILIDAD GARANTIZADA
    tiempo_restante = max_tiempo - (time() - tiempo_inicio)
    if tiempo_restante > 15.0
        # GUARDAR solución factible actual como backup
        mejor_backup = copiar_solucion(mejor)
        valor_backup = mejor_valor
        
        mejor_optimizado = optimizacion_conservadora_factible(mejor, roi, upi, LB, UB, config, tiempo_restante * 0.7)
        
        # VERIFICACIÓN ESTRICTA: Solo aceptar si es factible Y mejora
        if es_factible(mejor_optimizado, roi, upi, LB, UB, config)
            valor_optimizado = evaluar(mejor_optimizado, roi)
            if valor_optimizado > mejor_valor
                mejora_optimizada = valor_optimizado - mejor_valor
                mejor = mejor_optimizado
                mejor_valor = valor_optimizado
                
                if mostrar_progreso
                    println("   🚀 Optimización conservadora: +$(round(mejora_optimizada, digits=3))")
                end
            else
                # No mejoró el ratio, mantener backup
                mejor = mejor_backup
                mejor_valor = valor_backup
                if mostrar_progreso
                    println("   ↩️ Manteniendo solución anterior (sin mejora)")
                end
            end
        else
            # No es factible, restaurar backup
            mejor = mejor_backup
            mejor_valor = valor_backup
            if mostrar_progreso
                println("   ⚠️ Optimización rechazada (no factible) - Restaurando backup")
            end
        end
    end

    # 4. INTERCAMBIOS FINALES DE ALTO VALOR
    tiempo_restante = max_tiempo - (time() - tiempo_inicio)
    if tiempo_restante > 5.0
        mejor_intercambio = intercambios_finales_alto_valor(mejor, roi, upi, LB, UB, config, tiempo_restante)
        valor_intercambio = evaluar(mejor_intercambio, roi)
        
        if valor_intercambio > mejor_valor
            mejora_intercambio = valor_intercambio - mejor_valor
            mejor = mejor_intercambio
            mejor_valor = valor_intercambio
            
            if mostrar_progreso
                println("   ⚡ Intercambios finales: +$(round(mejora_intercambio, digits=3))")
            end
        end
    end
    
    tiempo_total = time() - tiempo_inicio
    if mostrar_progreso
        println("   ✅ Post-optimización completada en $(round(tiempo_total, digits=2))s")
    end
    
    return mejor
end

"""
Búsqueda local intensiva final
"""
function busqueda_local_intensiva_final(solucion::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_tiempo::Float64)
    tiempo_inicio = time()
    mejor = copiar_solucion(solucion)
    mejor_valor = evaluar(mejor, roi)
    
    O = size(roi, 1)
    mejoro = true
    iteraciones = 0
    
    while mejoro && (time() - tiempo_inicio) < max_tiempo
        mejoro = false
        iteraciones += 1
        
        ordenes_actuales = collect(mejor.ordenes)
        candidatos_externos = setdiff(1:O, mejor.ordenes)
        
        # Intercambios 1-1 con evaluación completa
        for o_out in ordenes_actuales
            for o_in in candidatos_externos
                if (time() - tiempo_inicio) > max_tiempo
                    break
                end
                
                valor_out = sum(roi[o_out, :])
                valor_in = sum(roi[o_in, :])
                valor_actual = sum(sum(roi[o, :]) for o in mejor.ordenes)
                nuevo_valor_total = valor_actual - valor_out + valor_in
                
                if LB <= nuevo_valor_total <= UB
                    nuevas_ordenes = copy(mejor.ordenes)
                    delete!(nuevas_ordenes, o_out)
                    push!(nuevas_ordenes, o_in)
                    
                    nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
                    candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
                    
                    if es_factible(candidato, roi, upi, LB, UB, config)
                        valor_candidato = evaluar(candidato, roi)
                        if valor_candidato > mejor_valor
                            mejor = candidato
                            mejor_valor = valor_candidato
                            mejoro = true
                            break
                        end
                    end
                end
            end
            if mejoro
                break
            end
        end
        
        # Limitar iteraciones para no consumir todo el tiempo
        if iteraciones >= 10
            break
        end
    end
    
    return mejor
end

"""
Intercambios finales de alto valor
"""
function intercambios_finales_alto_valor(solucion::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_tiempo::Float64)
    tiempo_inicio = time()
    mejor = copiar_solucion(solucion)
    mejor_valor = evaluar(mejor, roi)
    
    O = size(roi, 1)
    
    # Identificar órdenes de muy alto valor no seleccionadas
    candidatos_externos = setdiff(1:O, mejor.ordenes)
    ordenes_alto_valor = []
    
    for o in candidatos_externos
        valor = sum(roi[o, :])
        if valor >= 10  # Solo órdenes muy valiosas
            push!(ordenes_alto_valor, (o, valor))
        end
    end
    
    sort!(ordenes_alto_valor, by=x -> x[2], rev=true)
    
    # Probar intercambios con órdenes de alto valor
    ordenes_actuales = collect(mejor.ordenes)
    
    for (o_in, valor_in) in ordenes_alto_valor[1:min(10, length(ordenes_alto_valor))]
        if (time() - tiempo_inicio) > max_tiempo
            break
        end
        
        # Buscar la mejor orden para intercambiar
        mejor_intercambio = nothing
        mejor_ganancia = 0.0
        
        for o_out in ordenes_actuales
            valor_out = sum(roi[o_out, :])
            ganancia_bruta = valor_in - valor_out
            
            if ganancia_bruta > mejor_ganancia
                valor_actual = sum(sum(roi[o, :]) for o in mejor.ordenes)
                nuevo_valor_total = valor_actual - valor_out + valor_in
                
                if LB <= nuevo_valor_total <= UB
                    nuevas_ordenes = copy(mejor.ordenes)
                    delete!(nuevas_ordenes, o_out)
                    push!(nuevas_ordenes, o_in)
                    
                    nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
                    candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
                    
                    if es_factible(candidato, roi, upi, LB, UB, config)
                        valor_candidato = evaluar(candidato, roi)
                        ganancia_real = valor_candidato - mejor_valor
                        
                        if ganancia_real > mejor_ganancia
                            mejor_intercambio = candidato
                            mejor_ganancia = ganancia_real
                        end
                    end
                end
            end
        end
        
        if mejor_intercambio !== nothing
            mejor = mejor_intercambio
            mejor_valor = evaluar(mejor, roi)
        end
    end
    
    return mejor
end

# ========================================
# FUNCIONES AUXILIARES ESPECIALIZADAS
# ========================================

"""
Análisis de calidad de solución para grandes
"""
function analizar_calidad_solucion_grande(solucion::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    
    # Métricas básicas
    unidades_totales = sum(sum(roi[o, :]) for o in solucion.ordenes)
    num_ordenes = length(solucion.ordenes)
    num_pasillos = length(solucion.pasillos)
    ratio = evaluar(solucion, roi)
    
    # Métricas de eficiencia
    utilizacion_ub = (unidades_totales / UB) * 100
    densidad_ordenes = num_ordenes > 0 ? unidades_totales / num_ordenes : 0
    eficiencia_pasillos = num_pasillos > 0 ? unidades_totales / num_pasillos : 0
    
    # Métricas de distribución
    valores_ordenes = [sum(roi[o, :]) for o in solucion.ordenes]
    valor_promedio = length(valores_ordenes) > 0 ? sum(valores_ordenes) / length(valores_ordenes) : 0
    
    # Análisis de pasillos
    capacidades_pasillos = [sum(upi[p, :]) for p in solucion.pasillos]
    capacidad_promedio = length(capacidades_pasillos) > 0 ? sum(capacidades_pasillos) / length(capacidades_pasillos) : 0
    
    return (
        ratio = ratio,
        unidades_totales = unidades_totales,
        utilizacion_ub = utilizacion_ub,
        densidad_ordenes = densidad_ordenes,
        eficiencia_pasillos = eficiencia_pasillos,
        valor_promedio_orden = valor_promedio,
        capacidad_promedio_pasillo = capacidad_promedio,
        num_ordenes = num_ordenes,
        num_pasillos = num_pasillos
    )
end

"""
Verificar si una solución es prometedora para continuar optimización
"""
function es_solucion_prometedora(solucion::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia; umbral_calidad=0.7)
    
    analisis = analizar_calidad_solucion_grande(solucion, roi, upi, LB, UB, config)
    
    # Criterios de promesa
    buena_utilizacion = analisis.utilizacion_ub > 70.0
    buena_eficiencia = analisis.eficiencia_pasillos > 5.0
    ratio_decente = analisis.ratio > 1.0
    
    # Para patológicas, ser más permisivo
    if config.es_patologica
        return ratio_decente && (buena_utilizacion || buena_eficiencia)
    else
        return buena_utilizacion && buena_eficiencia && ratio_decente
    end
end

"""
Generar estadísticas detalladas del proceso de optimización
"""
function generar_estadisticas_grandes(resultado)
    estadisticas = Dict()
    
    estadisticas["valor_final"] = resultado.valor
    estadisticas["tiempo_total"] = resultado.tiempo
    estadisticas["mejora_total"] = resultado.mejora
    estadisticas["factible"] = resultado.factible
    
    # Mejoras por fase
    if haskey(resultado, :mejoras_por_fase)
        estadisticas["mejora_vns"] = resultado.mejoras_por_fase.vns
        estadisticas["mejora_lns"] = resultado.mejoras_por_fase.lns
        estadisticas["mejora_post"] = resultado.mejoras_por_fase.post
    end
    
    # Análisis de la solución final
    if resultado.solucion !== nothing
        estadisticas["num_ordenes"] = length(resultado.solucion.ordenes)
        estadisticas["num_pasillos"] = length(resultado.solucion.pasillos)
    end
    
    return estadisticas
end

# ========================================
# FUNCIONES DE DEBUGGING PARA GRANDES
# ========================================

"""
Debug específico para instancias grandes problemáticas
"""
function debug_instancia_grande(solucion::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, numero_instancia::Int)
    println("\n🔬 DEBUG INSTANCIA GRANDE $numero_instancia")
    println("="^60)
    
    analisis = analizar_calidad_solucion_grande(solucion, roi, upi, LB, UB, clasificar_instancia(roi, upi, LB, UB))
    
    println("📊 MÉTRICAS DE CALIDAD:")
    println("   🎯 Ratio: $(round(analisis.ratio, digits=3))")
    println("   💰 Unidades: $(analisis.unidades_totales)/$UB ($(round(analisis.utilizacion_ub, digits=1))%)")
    println("   📦 Órdenes: $(analisis.num_ordenes) (promedio: $(round(analisis.valor_promedio_orden, digits=2)) unidades/orden)")
    println("   🚪 Pasillos: $(analisis.num_pasillos) (promedio: $(round(analisis.capacidad_promedio_pasillo, digits=2)) capacidad/pasillo)")
    println("   ⚡ Eficiencia: $(round(analisis.eficiencia_pasillos, digits=2)) unidades/pasillo")
    
    # Identificar oportunidades de mejora
    println("\n💡 OPORTUNIDADES IDENTIFICADAS:")
    
    if analisis.utilizacion_ub < 80.0
        println("   📈 BAJA UTILIZACIÓN UB: Agregar más órdenes ($(round(100-analisis.utilizacion_ub, digits=1))% margen)")
    end
    
    if analisis.eficiencia_pasillos < 10.0
        println("   🚪 BAJA EFICIENCIA PASILLOS: Consolidar pasillos o mejorar selección")
    end
    
    if analisis.num_pasillos > 20
        println("   ⚠️ MUCHOS PASILLOS: Intentar consolidación (actual: $(analisis.num_pasillos))")
    end
    
    println("="^60)
end

# ========================================
# FASE DE LLENADO DE CAPACIDAD COMPLETA
# ========================================

"""
FASE COMPLETA DE LLENADO DE CAPACIDAD - Todos los movimientos implementados
Objetivo: Aprovechar al máximo el margen UB disponible
"""
# ========================================
# LLENAR UB MÁXIMO AGRESIVO - QUIRÚRGICO
# ========================================

"""
🛡️ OPTIMIZACIÓN CONSERVADORA FACTIBLE - PRIORIDAD MÁXIMA: FACTIBILIDAD
SOLUCIÓN AL PROBLEMA: VNS logra 11.667 FACTIBLE, post-optimización lo vuelve NO FACTIBLE
ESTRATEGIA: Intercambios conservadores 1-1 que mantengan factibilidad garantizada
"""
function optimizacion_conservadora_factible(solucion::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_tiempo::Float64)
    tiempo_inicio = time()
    mejor = copiar_solucion(solucion)
    mejor_valor = evaluar(mejor, roi)
    
    # VERIFICAR QUE LA SOLUCIÓN INICIAL SEA FACTIBLE
    if !es_factible(mejor, roi, upi, LB, UB, config)
        return mejor  # No tocar soluciones no factibles
    end
    
    O = size(roi, 1)
    candidatos_externos = setdiff(1:O, mejor.ordenes)
    
    if isempty(candidatos_externos)
        return mejor
    end
    
    # ESTRATEGIA HÍBRIDA 1: INTERCAMBIOS AGRESIVOS CON VERIFICACIÓN
    # Intercambios N-1, 2-1, 1-1 verificando factibilidad en cada paso
    if (time() - tiempo_inicio) < max_tiempo * 0.4
        mejor = intercambios_agresivos_verificados(mejor, candidatos_externos, roi, upi, LB, UB, config)
    end
    
    # ESTRATEGIA HÍBRIDA 2: LLENADO UB INTELIGENTE PASO A PASO
    # Agregar órdenes al límite del UB verificando factibilidad incremental
    if (time() - tiempo_inicio) < max_tiempo * 0.8
        valor_actual = sum(sum(roi[o, :]) for o in mejor.ordenes)
        margen_disponible = UB - valor_actual
        
        if margen_disponible > 0
            mejor = llenado_ub_paso_a_paso(mejor, candidatos_externos, roi, upi, LB, UB, config, margen_disponible)
        end
    end
    
    # ESTRATEGIA HÍBRIDA 3: OPTIMIZACIÓN FINAL DE PASILLOS AGRESIVA
    # Re-optimizar pasillos para maximizar ratio manteniendo factibilidad
    if (time() - tiempo_inicio) < max_tiempo
        mejor = optimizar_pasillos_agresivo(mejor, roi, upi, LB, UB, config)
    end
    
    return mejor
end

"""
🚀 LLENAR_UB_MAXIMO_AGRESIVO - FUNCIÓN QUIRÚRGICA PARA MAXIMIZAR UB
Implementa las soluciones específicas identificadas:
- Instancia 3: Llenar 33 unidades restantes (68.9% → 100%)
- Instancia 17: Llenar manteniendo los 3 pasillos clave (55.4% → 80%+)
- Instancia 12: Intercambios conservadores (ya cerca del objetivo)
"""
function llenar_ub_maximo_agresivo(solucion::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_tiempo::Float64)
    tiempo_inicio = time()
    mejor = copiar_solucion(solucion)
    mejor_valor = evaluar(mejor, roi)
    
    # Calcular margen exacto disponible
    valor_actual = sum(sum(roi[o, :]) for o in mejor.ordenes)
    margen_disponible = UB - valor_actual
    utilizacion_actual = (valor_actual / UB) * 100
    
    if margen_disponible <= 0
        return mejor  # Ya está al máximo
    end
    
    O = size(roi, 1)
    candidatos_externos = setdiff(1:O, mejor.ordenes)
    
    if isempty(candidatos_externos)
        return mejor
    end
    
    # ESTRATEGIA 1: LLENAR CAPACIDAD RESTANTE SIN AGREGAR PASILLOS (Para instancia 17)
    # Mantener los pasillos actuales y maximizar órdenes compatibles
    if length(mejor.pasillos) <= 5  # Instancias con pocos pasillos (como 17 con 3 pasillos)
        mejor = llenar_manteniendo_pasillos_actuales(mejor, candidatos_externos, roi, upi, LB, UB, config, margen_disponible)
        valor_nuevo = evaluar(mejor, roi)
        if valor_nuevo > mejor_valor
            mejor_valor = valor_nuevo
            valor_actual = sum(sum(roi[o, :]) for o in mejor.ordenes)
            margen_disponible = UB - valor_actual
        end
    end
    
    # ESTRATEGIA 2: INTERCAMBIOS N-1 MASIVOS (Para instancia 3)
    # Reemplazar múltiples órdenes por una grande que llene mejor el margen
    if margen_disponible > 10 && (time() - tiempo_inicio) < max_tiempo * 0.4
        mejor = intercambios_n_a_1_masivos(mejor, candidatos_externos, roi, upi, LB, UB, config, margen_disponible)
        valor_nuevo = evaluar(mejor, roi)
        if valor_nuevo > mejor_valor
            mejor_valor = valor_nuevo
            valor_actual = sum(sum(roi[o, :]) for o in mejor.ordenes)
            margen_disponible = UB - valor_actual
        end
    end
    
    # ESTRATEGIA 3: AGREGADO GREEDY ULTRAAGRESIVO
    # Agregar todas las órdenes posibles priorizando por ratio/pasillo
    if margen_disponible > 5 && (time() - tiempo_inicio) < max_tiempo * 0.7
        mejor = agregado_greedy_ultraagresivo(mejor, candidatos_externos, roi, upi, LB, UB, config, margen_disponible)
        valor_nuevo = evaluar(mejor, roi)
        if valor_nuevo > mejor_valor
            mejor_valor = valor_nuevo
            valor_actual = sum(sum(roi[o, :]) for o in mejor.ordenes)
            margen_disponible = UB - valor_actual
        end
    end
    
    # ESTRATEGIA 4: REFINAMIENTO FINAL QUIRÚRGICO
    # Intercambios 1-1 de alta precisión para aprovechar hasta la última unidad
    if margen_disponible > 0 && (time() - tiempo_inicio) < max_tiempo
        tiempo_restante = max_tiempo - (time() - tiempo_inicio)
        mejor = refinamiento_quirurgico_final(mejor, candidatos_externos, roi, upi, LB, UB, config, margen_disponible, tiempo_restante)
    end
    
    return mejor
end

"""
ESTRATEGIA 1: Llenar manteniendo pasillos actuales (CRÍTICO para instancia 17)
"""
function llenar_manteniendo_pasillos_actuales(solucion::Solucion, candidatos::Vector{Int}, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, margen_disponible::Int)
    mejor = copiar_solucion(solucion)
    mejoro = true
    
    while mejoro && margen_disponible > 0
        mejoro = false
        mejor_candidato = nothing
        mejor_ganancia = 0.0
        
        # Evaluar todos los candidatos compatibles con pasillos actuales
        for o in candidatos
            if !(o in mejor.ordenes)
                valor_o = sum(roi[o, :])
                
                # Verificar que quepa en el margen UB
                if valor_o <= margen_disponible
                    # Verificar compatibilidad con pasillos actuales
                    if es_orden_compatible(o, mejor.pasillos, roi, upi)
                        nuevas_ordenes = copy(mejor.ordenes)
                        push!(nuevas_ordenes, o)
                        
                        candidato = Solucion(nuevas_ordenes, mejor.pasillos)
                        if es_factible(candidato, roi, upi, LB, UB, config)
                            # Calcular ganancia en ratio (mantener mismos pasillos)
                            valor_candidato = evaluar(candidato, roi)
                            valor_actual = evaluar(mejor, roi)
                            ganancia = valor_candidato - valor_actual
                            
                            if ganancia > mejor_ganancia
                                mejor_candidato = candidato
                                mejor_ganancia = ganancia
                            end
                        end
                    end
                end
            end
        end
        
        if mejor_candidato !== nothing
            mejor = mejor_candidato
            valor_nuevo = sum(sum(roi[o, :]) for o in mejor.ordenes)
            valor_previo = sum(sum(roi[o, :]) for o in solucion.ordenes)
            margen_disponible = UB - valor_nuevo
            mejoro = true
        end
    end
    
    return mejor
end

"""
ESTRATEGIA 2: Intercambios N-1 masivos (CRÍTICO para instancia 3)
"""
function intercambios_n_a_1_masivos(solucion::Solucion, candidatos::Vector{Int}, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, margen_disponible::Int)
    mejor = copiar_solucion(solucion)
    mejor_valor = evaluar(mejor, roi)
    
    ordenes_actuales = collect(mejor.ordenes)
    
    # Buscar órdenes externas de alto valor que quepan en el margen
    candidatos_alto_valor = []
    for o in candidatos
        if !(o in mejor.ordenes)
            valor_o = sum(roi[o, :])
            if valor_o >= 5 && valor_o <= margen_disponible + 20  # Permitir intercambios
                push!(candidatos_alto_valor, (o, valor_o))
            end
        end
    end
    
    sort!(candidatos_alto_valor, by=x -> x[2], rev=true)
    
    # Para cada candidato de alto valor, buscar conjunto de órdenes a remover
    for (o_nuevo, valor_nuevo) in candidatos_alto_valor[1:min(10, length(candidatos_alto_valor))]
        
        # Probar intercambios 2-1, 3-1, 4-1
        for n_remover in 2:min(4, length(ordenes_actuales))
            
            # Generar combinaciones de órdenes a remover
            for combinacion in combinations(ordenes_actuales, n_remover)
                valor_removido = sum(sum(roi[o, :]) for o in combinacion)
                valor_actual_total = sum(sum(roi[o, :]) for o in mejor.ordenes)
                nuevo_valor_total = valor_actual_total - valor_removido + valor_nuevo
                
                # Verificar que quede dentro de límites UB/LB
                if LB <= nuevo_valor_total <= UB
                    nuevas_ordenes = setdiff(mejor.ordenes, Set(combinacion))
                    push!(nuevas_ordenes, o_nuevo)
                    
                    # Recalcular pasillos óptimos para el nuevo conjunto
                    nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
                    candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
                    
                    if es_factible(candidato, roi, upi, LB, UB, config)
                        valor_candidato = evaluar(candidato, roi)
                        if valor_candidato > mejor_valor
                            mejor = candidato
                            mejor_valor = valor_candidato
                        end
                    end
                end
            end
        end
    end
    
    return mejor
end

"""
ESTRATEGIA 3: Agregado greedy ultra-agresivo
"""
function agregado_greedy_ultraagresivo(solucion::Solucion, candidatos::Vector{Int}, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, margen_disponible::Int)
    mejor = copiar_solucion(solucion)
    
    # Evaluar todos los candidatos por eficiencia
    candidatos_eficiencia = []
    for o in candidatos
        if !(o in mejor.ordenes)
            valor_o = sum(roi[o, :])
            if valor_o <= margen_disponible
                # Estimar pasillos adicionales necesarios
                pasillos_necesarios = calcular_pasillos_adicionales_necesarios(o, mejor.pasillos, roi, upi)
                if pasillos_necesarios == 0  # Compatible con pasillos actuales
                    eficiencia = valor_o  # Máxima eficiencia si no necesita pasillos extra
                else
                    eficiencia = valor_o / (pasillos_necesarios + 0.1)  # Penalizar pasillos adicionales
                end
                push!(candidatos_eficiencia, (o, valor_o, eficiencia))
            end
        end
    end
    
    sort!(candidatos_eficiencia, by=x -> x[3], rev=true)
    
    # Agregar candidatos de mayor a menor eficiencia
    valor_actual = sum(sum(roi[o, :]) for o in mejor.ordenes)
    for (o, valor_o, eficiencia) in candidatos_eficiencia
        if valor_actual + valor_o <= UB
            nuevas_ordenes = copy(mejor.ordenes)
            push!(nuevas_ordenes, o)
            
            # Probar primero con pasillos actuales
            candidato_pasillos_actuales = Solucion(nuevas_ordenes, mejor.pasillos)
            if es_factible(candidato_pasillos_actuales, roi, upi, LB, UB, config)
                mejor = candidato_pasillos_actuales
                valor_actual += valor_o
                continue
            end
            
            # Si no funciona, recalcular pasillos
            nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
            candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
            if es_factible(candidato, roi, upi, LB, UB, config)
                valor_candidato = evaluar(candidato, roi)
                valor_anterior = evaluar(mejor, roi)
                if valor_candidato > valor_anterior  # Solo si mejora el ratio
                    mejor = candidato
                    valor_actual += valor_o
                end
            end
        end
    end
    
    return mejor
end

"""
ESTRATEGIA 4: Refinamiento quirúrgico final
"""
function refinamiento_quirurgico_final(solucion::Solucion, candidatos::Vector{Int}, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, margen_disponible::Int, max_tiempo::Float64)
    tiempo_inicio = time()
    mejor = copiar_solucion(solucion)
    mejor_valor = evaluar(mejor, roi)
    
    ordenes_actuales = collect(mejor.ordenes)
    
    # Intercambios 1-1 de precisión quirúrgica
    for o_out in ordenes_actuales
        for o_in in candidatos
            if (time() - tiempo_inicio) > max_tiempo
                break
            end
            
            if !(o_in in mejor.ordenes)
                valor_out = sum(roi[o_out, :])
                valor_in = sum(roi[o_in, :])
                diferencia = valor_in - valor_out
                
                # Solo si mejora y queda dentro del margen
                if diferencia > 0 && diferencia <= margen_disponible
                    valor_actual = sum(sum(roi[o, :]) for o in mejor.ordenes)
                    nuevo_valor_total = valor_actual - valor_out + valor_in
                    
                    if LB <= nuevo_valor_total <= UB
                        nuevas_ordenes = copy(mejor.ordenes)
                        delete!(nuevas_ordenes, o_out)
                        push!(nuevas_ordenes, o_in)
                        
                        # Probar primero con pasillos actuales
                        candidato_pasillos_actuales = Solucion(nuevas_ordenes, mejor.pasillos)
                        if es_factible(candidato_pasillos_actuales, roi, upi, LB, UB, config)
                            valor_candidato = evaluar(candidato_pasillos_actuales, roi)
                            if valor_candidato > mejor_valor
                                mejor = candidato_pasillos_actuales
                                mejor_valor = valor_candidato
                                margen_disponible -= diferencia
                                ordenes_actuales = collect(mejor.ordenes)
                                break
                            end
                        else
                            # Recalcular pasillos si es necesario
                            nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
                            candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
                            if es_factible(candidato, roi, upi, LB, UB, config)
                                valor_candidato = evaluar(candidato, roi)
                                if valor_candidato > mejor_valor
                                    mejor = candidato
                                    mejor_valor = valor_candidato
                                    margen_disponible -= diferencia
                                    ordenes_actuales = collect(mejor.ordenes)
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    return mejor
end

"""
🔥 INTERCAMBIOS AGRESIVOS VERIFICADOS - MÁXIMA AGRESIVIDAD + VERIFICACIÓN PASO A PASO
Intercambios N-1, 2-1, 1-1 con verificación de factibilidad en cada movimiento
"""
function intercambios_agresivos_verificados(solucion::Solucion, candidatos::Vector{Int}, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    mejor = copiar_solucion(solucion)
    mejor_valor = evaluar(mejor, roi)
    
    ordenes_actuales = collect(mejor.ordenes)
    mejoro = true
    
    # FASE 1: INTERCAMBIOS 2-1 AGRESIVOS (Reemplazar 2 órdenes por 1 grande)
    while mejoro
        mejoro = false
        
        for o_in in candidatos
            if !(o_in in mejor.ordenes)
                valor_in = sum(roi[o_in, :])
                
                # Probar todas las combinaciones de 2 órdenes para remover
                for i in 1:length(ordenes_actuales)
                    for j in (i+1):length(ordenes_actuales)
                        o_out1, o_out2 = ordenes_actuales[i], ordenes_actuales[j]
                        valor_out = sum(roi[o_out1, :]) + sum(roi[o_out2, :])
                        
                        # Solo si la orden nueva vale más que las 2 que saca
                        if valor_in > valor_out * 1.2  # Bonus del 20% para justificar el cambio
                            valor_actual = sum(sum(roi[o, :]) for o in mejor.ordenes)
                            nuevo_valor_total = valor_actual - valor_out + valor_in
                            
                            if LB <= nuevo_valor_total <= UB
                                nuevas_ordenes = copy(mejor.ordenes)
                                delete!(nuevas_ordenes, o_out1)
                                delete!(nuevas_ordenes, o_out2)
                                push!(nuevas_ordenes, o_in)
                                
                                # VERIFICACIÓN PASO A PASO: Probar con pasillos actuales primero
                                candidato = Solucion(nuevas_ordenes, mejor.pasillos)
                                
                                if es_factible(candidato, roi, upi, LB, UB, config)
                                    valor_candidato = evaluar(candidato, roi)
                                    if valor_candidato > mejor_valor
                                        mejor = candidato
                                        mejor_valor = valor_candidato
                                        ordenes_actuales = collect(mejor.ordenes)
                                        mejoro = true
                                        break
                                    end
                                else
                                    # Si no es factible con pasillos actuales, re-optimizar pasillos
                                    nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
                                    candidato_reopt = Solucion(nuevas_ordenes, nuevos_pasillos)
                                    
                                    if es_factible(candidato_reopt, roi, upi, LB, UB, config)
                                        valor_candidato = evaluar(candidato_reopt, roi)
                                        if valor_candidato > mejor_valor
                                            mejor = candidato_reopt
                                            mejor_valor = valor_candidato
                                            ordenes_actuales = collect(mejor.ordenes)
                                            mejoro = true
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if mejoro
                        break
                    end
                end
                if mejoro
                    break
                end
            end
        end
    end
    
    # FASE 2: INTERCAMBIOS 1-1 AGRESIVOS (Backup si no funcionó 2-1)
    mejoro = true
    while mejoro
        mejoro = false
        
        for o_out in ordenes_actuales
            for o_in in candidatos
                if !(o_in in mejor.ordenes)
                    valor_out = sum(roi[o_out, :])
                    valor_in = sum(roi[o_in, :])
                    
                    # Aceptar cualquier mejora, no importa cuán pequeña
                    if valor_in > valor_out
                        valor_actual = sum(sum(roi[o, :]) for o in mejor.ordenes)
                        nuevo_valor_total = valor_actual - valor_out + valor_in
                        
                        if LB <= nuevo_valor_total <= UB
                            nuevas_ordenes = copy(mejor.ordenes)
                            delete!(nuevas_ordenes, o_out)
                            push!(nuevas_ordenes, o_in)
                            
                            # VERIFICACIÓN PASO A PASO
                            candidato = Solucion(nuevas_ordenes, mejor.pasillos)
                            
                            if es_factible(candidato, roi, upi, LB, UB, config)
                                valor_candidato = evaluar(candidato, roi)
                                if valor_candidato > mejor_valor
                                    mejor = candidato
                                    mejor_valor = valor_candidato
                                    ordenes_actuales = collect(mejor.ordenes)
                                    mejoro = true
                                    break
                                end
                            end
                        end
                    end
                end
            end
            if mejoro
                break
            end
        end
    end
    
    return mejor
end

"""
🔥 LLENADO UB PASO A PASO - LLENAR HASTA EL LÍMITE VERIFICANDO CADA ORDEN
"""
function llenado_ub_paso_a_paso(solucion::Solucion, candidatos::Vector{Int}, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, margen_disponible::Int)
    mejor = copiar_solucion(solucion)
    mejor_valor = evaluar(mejor, roi)
    
    # Evaluar TODOS los candidatos por eficiencia ratio/pasillo
    candidatos_evaluados = []
    for o in candidatos
        if !(o in mejor.ordenes)
            valor_o = sum(roi[o, :])
            
            if valor_o <= margen_disponible
                # Estimar ratio si se agrega esta orden
                pasillos_necesarios = calcular_pasillos_adicionales_necesarios(o, mejor.pasillos, roi, upi)
                if pasillos_necesarios == 0
                    # Compatible con pasillos actuales = máxima eficiencia
                    eficiencia = valor_o * 10  # Bonus enorme por compatibilidad
                else
                    # Necesita pasillos adicionales = penalizar pero considerar
                    eficiencia = valor_o / (pasillos_necesarios + 1)
                end
                push!(candidatos_evaluados, (o, valor_o, eficiencia))
            end
        end
    end
    
    # Ordenar por eficiencia (los más eficientes primero)
    sort!(candidatos_evaluados, by=x -> x[3], rev=true)
    
    # LLENADO AGRESIVO: Agregar candidatos hasta llenar el UB
    for (o, valor_o, eficiencia) in candidatos_evaluados
        valor_actual = sum(sum(roi[ord, :]) for ord in mejor.ordenes)
        
        if valor_actual + valor_o <= UB
            nuevas_ordenes = copy(mejor.ordenes)
            push!(nuevas_ordenes, o)
            
            # ESTRATEGIA DOBLE: Probar con pasillos actuales Y con re-optimización
            
            # Opción 1: Mantener pasillos actuales
            candidato1 = Solucion(nuevas_ordenes, mejor.pasillos)
            if es_factible(candidato1, roi, upi, LB, UB, config)
                valor_candidato1 = evaluar(candidato1, roi)
                if valor_candidato1 > mejor_valor
                    mejor = candidato1
                    mejor_valor = valor_candidato1
                    continue
                end
            end
            
            # Opción 2: Re-optimizar pasillos (más agresivo)
            nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
            candidato2 = Solucion(nuevas_ordenes, nuevos_pasillos)
            if es_factible(candidato2, roi, upi, LB, UB, config)
                valor_candidato2 = evaluar(candidato2, roi)
                if valor_candidato2 > mejor_valor
                    mejor = candidato2
                    mejor_valor = valor_candidato2
                end
            end
        end
    end
    
    return mejor
end

"""
🔥 OPTIMIZAR PASILLOS AGRESIVO - RE-OPTIMIZACIÓN FINAL PARA MÁXIMO RATIO
"""
function optimizar_pasillos_agresivo(solucion::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    mejor = copiar_solucion(solucion)
    mejor_valor = evaluar(mejor, roi)
    
    # ESTRATEGIA 1: Re-optimizar pasillos desde cero
    pasillos_optimizados = calcular_pasillos_optimos(mejor.ordenes, roi, upi, LB, UB, config)
    candidato1 = Solucion(mejor.ordenes, pasillos_optimizados)
    
    if es_factible(candidato1, roi, upi, LB, UB, config)
        valor_candidato1 = evaluar(candidato1, roi)
        if valor_candidato1 > mejor_valor
            mejor = candidato1
            mejor_valor = valor_candidato1
        end
    end
    
    # ESTRATEGIA 2: Intentar reducir pasillos manteniendo factibilidad
    pasillos_actuales = collect(mejor.pasillos)
    
    for p in pasillos_actuales
        pasillos_reducidos = copy(mejor.pasillos)
        delete!(pasillos_reducidos, p)
        
        if !isempty(pasillos_reducidos)
            candidato2 = Solucion(mejor.ordenes, pasillos_reducidos)
            if es_factible(candidato2, roi, upi, LB, UB, config)
                valor_candidato2 = evaluar(candidato2, roi)
                if valor_candidato2 > mejor_valor
                    mejor = candidato2
                    mejor_valor = valor_candidato2
                    break  # Encontramos una reducción que funciona
                end
            end
        end
    end
    
    return mejor
end

"""
🛡️ INTERCAMBIOS 1-1 ULTRA-SEGUROS - Factibilidad garantizada
Solo intercambios que mejoren ratio sin comprometer factibilidad
"""
function intercambios_1_a_1_ultra_seguros(solucion::Solucion, candidatos::Vector{Int}, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    mejor = copiar_solucion(solucion)
    mejor_valor = evaluar(mejor, roi)
    
    ordenes_actuales = collect(mejor.ordenes)
    mejoro = true
    
    while mejoro
        mejoro = false
        
        for o_out in ordenes_actuales
            for o_in in candidatos
                if !(o_in in mejor.ordenes)
                    valor_out = sum(roi[o_out, :])
                    valor_in = sum(roi[o_in, :])
                    
                    # Solo considerar si mejora el valor total
                    if valor_in > valor_out
                        valor_actual = sum(sum(roi[o, :]) for o in mejor.ordenes)
                        nuevo_valor_total = valor_actual - valor_out + valor_in
                        
                        # Verificar límites UB/LB
                        if LB <= nuevo_valor_total <= UB
                            nuevas_ordenes = copy(mejor.ordenes)
                            delete!(nuevas_ordenes, o_out)
                            push!(nuevas_ordenes, o_in)
                            
                            # CRÍTICO: Probar primero con pasillos actuales (mantener estructura)
                            candidato = Solucion(nuevas_ordenes, mejor.pasillos)
                            
                            # VERIFICACIÓN ESTRICTA DE FACTIBILIDAD
                            if es_factible(candidato, roi, upi, LB, UB, config)
                                valor_candidato = evaluar(candidato, roi)
                                if valor_candidato > mejor_valor
                                    mejor = candidato
                                    mejor_valor = valor_candidato
                                    ordenes_actuales = collect(mejor.ordenes)
                                    mejoro = true
                                    break
                                end
                            end
                        end
                    end
                end
            end
            if mejoro
                break
            end
        end
    end
    
    return mejor
end

"""
🛡️ AGREGADO MÍNIMO VERIFICADO - Solo órdenes que caben perfectamente
"""
function agregado_minimo_verificado(solucion::Solucion, candidatos::Vector{Int}, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, margen_disponible::Int)
    mejor = copiar_solucion(solucion)
    mejor_valor = evaluar(mejor, roi)
    
    # Evaluar candidatos por compatibilidad con pasillos actuales
    candidatos_compatibles = []
    for o in candidatos
        if !(o in mejor.ordenes)
            valor_o = sum(roi[o, :])
            
            # Solo considerar si cabe en el margen UB
            if valor_o <= margen_disponible
                # Verificar compatibilidad TOTAL con pasillos actuales
                if es_orden_totalmente_compatible(o, mejor.pasillos, roi, upi)
                    push!(candidatos_compatibles, (o, valor_o))
                end
            end
        end
    end
    
    # Ordenar por valor (agregar primero las más valiosas)
    sort!(candidatos_compatibles, by=x -> x[2], rev=true)
    
    # Agregar de una en una, verificando factibilidad en cada paso
    for (o, valor_o) in candidatos_compatibles
        nuevas_ordenes = copy(mejor.ordenes)
        push!(nuevas_ordenes, o)
        
        # Mantener mismos pasillos (clave para factibilidad)
        candidato = Solucion(nuevas_ordenes, mejor.pasillos)
        
        # VERIFICACIÓN ESTRICTA
        if es_factible(candidato, roi, upi, LB, UB, config)
            valor_candidato = evaluar(candidato, roi)
            if valor_candidato > mejor_valor
                mejor = candidato
                mejor_valor = valor_candidato
                margen_disponible -= valor_o
            end
        end
    end
    
    return mejor
end

"""
Verificar compatibilidad TOTAL de una orden con pasillos actuales
"""
function es_orden_totalmente_compatible(orden::Int, pasillos_actuales::Set{Int}, roi::Matrix{Int}, upi::Matrix{Int})
    I = size(roi, 2)
    
    for i in 1:I
        if roi[orden, i] > 0
            capacidad_disponible = sum(upi[p, i] for p in pasillos_actuales)
            if capacidad_disponible < roi[orden, i]
                return false  # No cabe en los pasillos actuales
            end
        end
    end
    
    return true  # Compatible totalmente
end

"""
Función auxiliar: Calcular pasillos adicionales necesarios para una orden
"""
function calcular_pasillos_adicionales_necesarios(orden::Int, pasillos_actuales::Set{Int}, roi::Matrix{Int}, upi::Matrix{Int})
    I = size(roi, 2)
    
    for i in 1:I
        if roi[orden, i] > 0
            capacidad_disponible = sum(upi[p, i] for p in pasillos_actuales)
            if capacidad_disponible < roi[orden, i]
                return 1  # Necesita al menos un pasillo adicional
            end
        end
    end
    
    return 0  # Compatible con pasillos actuales
end

function fase_llenado_capacidad_completa(solucion::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_tiempo::Float64)
    tiempo_inicio = time()
    mejor = copiar_solucion(solucion)
    mejor_valor = evaluar(mejor, roi)
    
    valor_actual = sum(sum(roi[o, :]) for o in mejor.ordenes)
    margen_disponible = UB - valor_actual
    
    if margen_disponible <= 0
        return mejor  # Ya está al máximo
    end
    
    O = size(roi, 1)
    tiempo_por_fase = max_tiempo / 5.0  # 5 fases principales
    
    # FASE 1: ADD MOVEMENTS (Compatible, Batch, Greedy)
    if (time() - tiempo_inicio) < tiempo_por_fase
        mejor_add = movimientos_add_completos(mejor, roi, upi, LB, UB, config, tiempo_por_fase)
        valor_add = evaluar(mejor_add, roi)
        if valor_add > mejor_valor
            mejor = mejor_add
            mejor_valor = valor_add
        end
    end
    
    # FASE 2: REPLACE MOVEMENTS (Upgrade, 2to1, 3to2)
    if (time() - tiempo_inicio) < tiempo_por_fase * 2
        mejor_replace = movimientos_replace_completos(mejor, roi, upi, LB, UB, config, tiempo_por_fase)
        valor_replace = evaluar(mejor_replace, roi)
        if valor_replace > mejor_valor
            mejor = mejor_replace
            mejor_valor = valor_replace
        end
    end
    
    # FASE 3: EXPAND MOVEMENTS (Corridor, Smart Expand)
    if (time() - tiempo_inicio) < tiempo_por_fase * 3
        mejor_expand = movimientos_expand_completos(mejor, roi, upi, LB, UB, config, tiempo_por_fase)
        valor_expand = evaluar(mejor_expand, roi)
        if valor_expand > mejor_valor
            mejor = mejor_expand
            mejor_valor = valor_expand
        end
    end
    
    # FASE 4: HYBRID MOVEMENTS (Repack, Consolidate)
    if (time() - tiempo_inicio) < tiempo_por_fase * 4
        mejor_hybrid = movimientos_hybrid_completos(mejor, roi, upi, LB, UB, config, tiempo_por_fase)
        valor_hybrid = evaluar(mejor_hybrid, roi)
        if valor_hybrid > mejor_valor
            mejor = mejor_hybrid
            mejor_valor = valor_hybrid
        end
    end
    
    # FASE 5: OPTIMIZACIÓN FINAL AGRESIVA
    if (time() - tiempo_inicio) < max_tiempo
        tiempo_restante = max_tiempo - (time() - tiempo_inicio)
        mejor_final = optimizacion_final_agresiva(mejor, roi, upi, LB, UB, config, tiempo_restante)
        valor_final = evaluar(mejor_final, roi)
        if valor_final > mejor_valor
            mejor = mejor_final
            mejor_valor = valor_final
        end
    end
    
    return mejor
end

# ========================================
# MOVIMIENTOS ADD (Agregar órdenes)
# ========================================

"""
MOVIMIENTOS ADD COMPLETOS: Compatible, Batch, Greedy
"""
function movimientos_add_completos(solucion::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_tiempo::Float64)
    tiempo_inicio = time()
    mejor = copiar_solucion(solucion)
    mejor_valor = evaluar(mejor, roi)
    
    O = size(roi, 1)
    candidatos_externos = setdiff(1:O, mejor.ordenes)
    
    if isempty(candidatos_externos)
        return mejor
    end
    
    # 1. ADD_COMPATIBLE: Órdenes que encajan perfectamente
    mejor = add_compatible_orders(mejor, candidatos_externos, roi, upi, LB, UB, config)
    mejor_valor = evaluar(mejor, roi)
    
    if (time() - tiempo_inicio) > max_tiempo * 0.5
        return mejor
    end
    
    # 2. ADD_BATCH: Múltiples órdenes en lote
    mejor = add_batch_orders(mejor, candidatos_externos, roi, upi, LB, UB, config)
    mejor_valor = evaluar(mejor, roi)
    
    if (time() - tiempo_inicio) > max_tiempo * 0.8
        return mejor
    end
    
    # 3. ADD_GREEDY: Llenar agresivamente hasta UB
    mejor = add_greedy_orders(mejor, candidatos_externos, roi, upi, LB, UB, config)
    
    return mejor
end

"""
ADD_COMPATIBLE: Agregar órdenes compatibles con pasillos actuales
"""
function add_compatible_orders(solucion::Solucion, candidatos::Vector{Int}, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    mejor = copiar_solucion(solucion)
    mejor_valor = evaluar(mejor, roi)
    
    # Evaluar cada candidato por compatibilidad y valor
    candidatos_evaluados = []
    for o in candidatos
        if es_orden_compatible(o, mejor.pasillos, roi, upi)
            valor_o = sum(roi[o, :])
            valor_actual = sum(sum(roi[ord, :]) for ord in mejor.ordenes)
            
            if valor_actual + valor_o <= UB
                ratio_estimado = (mejor_valor * length(mejor.pasillos) + valor_o) / length(mejor.pasillos)
                push!(candidatos_evaluados, (o, valor_o, ratio_estimado))
            end
        end
    end
    
    # Ordenar por ratio estimado
    sort!(candidatos_evaluados, by=x -> x[3], rev=true)
    
    # Agregar órdenes de mayor a menor ratio
    for (o, valor_o, ratio_est) in candidatos_evaluados
        nuevas_ordenes = copy(mejor.ordenes)
        push!(nuevas_ordenes, o)
        
        candidato = Solucion(nuevas_ordenes, mejor.pasillos)
        if es_factible(candidato, roi, upi, LB, UB, config)
            valor_candidato = evaluar(candidato, roi)
            if valor_candidato > mejor_valor
                mejor = candidato
                mejor_valor = valor_candidato
            end
        end
    end
    
    return mejor
end

"""
ADD_BATCH: Agregar múltiples órdenes en lote
"""
function add_batch_orders(solucion::Solucion, candidatos::Vector{Int}, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    mejor = copiar_solucion(solucion)
    mejor_valor = evaluar(mejor, roi)
    
    if length(candidatos) < 2
        return mejor
    end
    
    # Probar combinaciones de 2-4 órdenes
    for batch_size in [2, 3, 4]
        if length(candidatos) >= batch_size
            # Evaluar todas las combinaciones posibles (limitado para eficiencia)
            max_combinaciones = min(50, div(length(candidatos) * (length(candidatos) - 1), 2))
            combinaciones_probadas = 0
            
            for combo in combinations(candidatos, batch_size)
                if combinaciones_probadas >= max_combinaciones
                    break
                end
                combinaciones_probadas += 1
                
                # Verificar si el batch cabe en UB
                valor_batch = sum(sum(roi[o, :]) for o in combo)
                valor_actual = sum(sum(roi[ord, :]) for ord in mejor.ordenes)
                
                if valor_actual + valor_batch <= UB
                    # Probar agregar todo el batch
                    nuevas_ordenes = copy(mejor.ordenes)
                    for o in combo
                        push!(nuevas_ordenes, o)
                    end
                    
                    nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
                    candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
                    
                    if es_factible(candidato, roi, upi, LB, UB, config)
                        valor_candidato = evaluar(candidato, roi)
                        if valor_candidato > mejor_valor
                            mejor = candidato
                            mejor_valor = valor_candidato
                        end
                    end
                end
            end
        end
    end
    
    return mejor
end

"""
ADD_GREEDY: Llenar agresivamente hasta UB
"""
function add_greedy_orders(solucion::Solucion, candidatos::Vector{Int}, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    mejor = copiar_solucion(solucion)
    valor_actual = sum(sum(roi[o, :]) for o in mejor.ordenes)
    
    # Ordenar candidatos por eficiencia (valor/items)
    candidatos_eficiencia = []
    for o in candidatos
        valor_o = sum(roi[o, :])
        items_o = count(roi[o, :] .> 0)
        eficiencia = items_o > 0 ? valor_o / items_o : 0
        push!(candidatos_eficiencia, (o, valor_o, eficiencia))
    end
    
    sort!(candidatos_eficiencia, by=x -> x[3], rev=true)
    
    # Agregar greedily hasta llenar UB
    nuevas_ordenes = copy(mejor.ordenes)
    for (o, valor_o, eficiencia) in candidatos_eficiencia
        if valor_actual + valor_o <= UB
            nuevas_ordenes_candidato = copy(nuevas_ordenes)
            push!(nuevas_ordenes_candidato, o)
            
            nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes_candidato, roi, upi, LB, UB, config)
            candidato = Solucion(nuevas_ordenes_candidato, nuevos_pasillos)
            
            if es_factible(candidato, roi, upi, LB, UB, config)
                nuevas_ordenes = nuevas_ordenes_candidato
                mejor = candidato
                valor_actual += valor_o
            end
        end
    end
    
    return mejor
end

# ========================================
# MOVIMIENTOS REPLACE (Reemplazar órdenes)
# ========================================

"""
MOVIMIENTOS REPLACE COMPLETOS: Upgrade, 2to1, 3to2
"""
function movimientos_replace_completos(solucion::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_tiempo::Float64)
    tiempo_inicio = time()
    mejor = copiar_solucion(solucion)
    
    O = size(roi, 1)
    candidatos_externos = setdiff(1:O, mejor.ordenes)
    
    # 1. REPLACE_UPGRADE: 1 pequeña → 1 grande
    mejor = replace_upgrade_orders(mejor, candidatos_externos, roi, upi, LB, UB, config)
    
    if (time() - tiempo_inicio) > max_tiempo * 0.4
        return mejor
    end
    
    # 2. REPLACE_2TO1: 2 pequeñas → 1 grande
    mejor = replace_2to1_orders(mejor, candidatos_externos, roi, upi, LB, UB, config)
    
    if (time() - tiempo_inicio) > max_tiempo * 0.7
        return mejor
    end
    
    # 3. REPLACE_3TO2: 3 pequeñas → 2 medianas
    mejor = replace_3to2_orders(mejor, candidatos_externos, roi, upi, LB, UB, config)
    
    return mejor
end

"""
REPLACE_UPGRADE: Reemplazar orden pequeña por una grande
"""
function replace_upgrade_orders(solucion::Solucion, candidatos::Vector{Int}, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    mejor = copiar_solucion(solucion)
    mejor_valor = evaluar(mejor, roi)
    
    ordenes_actuales = collect(mejor.ordenes)
    
    # Encontrar órdenes pequeñas para reemplazar
    ordenes_pequeñas = []
    for o in ordenes_actuales
        valor_o = sum(roi[o, :])
        if valor_o <= 5  # Consideramos "pequeñas" las de ≤5 unidades
            push!(ordenes_pequeñas, (o, valor_o))
        end
    end
    
    sort!(ordenes_pequeñas, by=x -> x[2])  # Más pequeñas primero
    
    # Buscar órdenes grandes para reemplazar
    ordenes_grandes = []
    for o in candidatos
        valor_o = sum(roi[o, :])
        if valor_o >= 10  # Consideramos "grandes" las de ≥10 unidades
            push!(ordenes_grandes, (o, valor_o))
        end
    end
    
    sort!(ordenes_grandes, by=x -> x[2], rev=true)  # Más grandes primero
    
    # Intentar reemplazos 1→1
    for (o_pequeña, valor_pequeña) in ordenes_pequeñas
        for (o_grande, valor_grande) in ordenes_grandes
            valor_actual = sum(sum(roi[o, :]) for o in mejor.ordenes)
            nuevo_valor_total = valor_actual - valor_pequeña + valor_grande
            
            if LB <= nuevo_valor_total <= UB && valor_grande > valor_pequeña * 1.5
                nuevas_ordenes = copy(mejor.ordenes)
                delete!(nuevas_ordenes, o_pequeña)
                push!(nuevas_ordenes, o_grande)
                
                nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
                candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
                
                if es_factible(candidato, roi, upi, LB, UB, config)
                    valor_candidato = evaluar(candidato, roi)
                    if valor_candidato > mejor_valor
                        mejor = candidato
                        mejor_valor = valor_candidato
                        break  # Solo un reemplazo por iteración
                    end
                end
            end
        end
    end
    
    return mejor
end

"""
REPLACE_2TO1: Reemplazar 2 órdenes pequeñas por 1 grande
"""
function replace_2to1_orders(solucion::Solucion, candidatos::Vector{Int}, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    mejor = copiar_solucion(solucion)
    mejor_valor = evaluar(mejor, roi)
    
    ordenes_actuales = collect(mejor.ordenes)
    
    if length(ordenes_actuales) < 2
        return mejor
    end
    
    # Buscar pares de órdenes pequeñas
    for i in 1:length(ordenes_actuales)-1
        for j in i+1:length(ordenes_actuales)
            o1, o2 = ordenes_actuales[i], ordenes_actuales[j]
            valor1, valor2 = sum(roi[o1, :]), sum(roi[o2, :])
            valor_par = valor1 + valor2
            
            if valor_par <= 10  # Solo reemplazar pares pequeños
                # Buscar orden grande que los reemplace
                for o_grande in candidatos
                    valor_grande = sum(roi[o_grande, :])
                    
                    if valor_grande > valor_par * 1.3  # Al menos 30% mejor
                        valor_actual = sum(sum(roi[o, :]) for o in mejor.ordenes)
                        nuevo_valor_total = valor_actual - valor_par + valor_grande
                        
                        if LB <= nuevo_valor_total <= UB
                            nuevas_ordenes = copy(mejor.ordenes)
                            delete!(nuevas_ordenes, o1)
                            delete!(nuevas_ordenes, o2)
                            push!(nuevas_ordenes, o_grande)
                            
                            nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
                            candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
                            
                            if es_factible(candidato, roi, upi, LB, UB, config)
                                valor_candidato = evaluar(candidato, roi)
                                if valor_candidato > mejor_valor
                                    mejor = candidato
                                    mejor_valor = valor_candidato
                                    return mejor  # Solo un reemplazo
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    return mejor
end

"""
REPLACE_3TO2: Reemplazar 3 órdenes pequeñas por 2 medianas
"""
function replace_3to2_orders(solucion::Solucion, candidatos::Vector{Int}, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    mejor = copiar_solucion(solucion)
    mejor_valor = evaluar(mejor, roi)
    
    ordenes_actuales = collect(mejor.ordenes)
    
    if length(ordenes_actuales) < 3
        return mejor
    end
    
    # Buscar tríos de órdenes pequeñas
    for i in 1:length(ordenes_actuales)-2
        for j in i+1:length(ordenes_actuales)-1
            for k in j+1:length(ordenes_actuales)
                o1, o2, o3 = ordenes_actuales[i], ordenes_actuales[j], ordenes_actuales[k]
                valor_trio = sum(roi[o1, :]) + sum(roi[o2, :]) + sum(roi[o3, :])
                
                if valor_trio <= 15  # Solo tríos pequeños
                    # Buscar par de órdenes medianas
                    for c1 in candidatos[1:min(20, length(candidatos))]  # Limitar búsqueda
                        for c2 in candidatos[1:min(20, length(candidatos))]
                            if c1 != c2
                                valor_par = sum(roi[c1, :]) + sum(roi[c2, :])
                                
                                if valor_par > valor_trio * 1.2  # Al menos 20% mejor
                                    valor_actual = sum(sum(roi[o, :]) for o in mejor.ordenes)
                                    nuevo_valor_total = valor_actual - valor_trio + valor_par
                                    
                                    if LB <= nuevo_valor_total <= UB
                                        nuevas_ordenes = copy(mejor.ordenes)
                                        delete!(nuevas_ordenes, o1)
                                        delete!(nuevas_ordenes, o2)
                                        delete!(nuevas_ordenes, o3)
                                        push!(nuevas_ordenes, c1)
                                        push!(nuevas_ordenes, c2)
                                        
                                        nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
                                        candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
                                        
                                        if es_factible(candidato, roi, upi, LB, UB, config)
                                            valor_candidato = evaluar(candidato, roi)
                                            if valor_candidato > mejor_valor
                                                mejor = candidato
                                                mejor_valor = valor_candidato
                                                return mejor  # Solo un reemplazo
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    return mejor
end

# ========================================
# MOVIMIENTOS EXPAND (Expandir pasillos)
# ========================================

"""
MOVIMIENTOS EXPAND COMPLETOS: Corridor, Smart Expand
"""
function movimientos_expand_completos(solucion::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_tiempo::Float64)
    tiempo_inicio = time()
    mejor = copiar_solucion(solucion)
    
    # 1. EXPAND_CORRIDOR: Agregar 1 pasillo estratégico
    mejor = expand_corridor_strategic(mejor, roi, upi, LB, UB, config)
    
    if (time() - tiempo_inicio) > max_tiempo * 0.6
        return mejor
    end
    
    # 2. SMART_EXPAND: Expansión inteligente múltiple
    mejor = smart_expand_multiple(mejor, roi, upi, LB, UB, config)
    
    return mejor
end

"""
EXPAND_CORRIDOR: Agregar un pasillo que maximice nuevas órdenes
"""
function expand_corridor_strategic(solucion::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    mejor = copiar_solucion(solucion)
    mejor_valor = evaluar(mejor, roi)
    
    O, I = size(roi)
    P = size(upi, 1)
    
    ordenes_externas = setdiff(1:O, mejor.ordenes)
    pasillos_disponibles = setdiff(1:P, mejor.pasillos)
    
    if isempty(pasillos_disponibles) || isempty(ordenes_externas)
        return mejor
    end
    
    # Evaluar cada pasillo por potencial de órdenes nuevas
    evaluaciones_pasillos = []
    
    for p in pasillos_disponibles
        # Contar órdenes externas compatibles con este pasillo
        ordenes_compatibles = []
        valor_total_potencial = 0
        
        for o in ordenes_externas
            compatible = true
            for i in 1:I
                if roi[o, i] > 0 && upi[p, i] < roi[o, i]
                    # Verificar si otros pasillos pueden compensar
                    capacidad_total = sum(upi[p2, i] for p2 in union(mejor.pasillos, [p]))
                    if capacidad_total < roi[o, i]
                        compatible = false
                        break
                    end
                end
            end
            
            if compatible
                valor_o = sum(roi[o, :])
                valor_actual = sum(sum(roi[ord, :]) for ord in mejor.ordenes)
                if valor_actual + valor_o <= UB
                    push!(ordenes_compatibles, o)
                    valor_total_potencial += valor_o
                end
            end
        end
        
        if !isempty(ordenes_compatibles)
            # Score = valor_potencial / costo_pasillo
            capacidad_pasillo = sum(upi[p, :])
            score = length(ordenes_compatibles) * valor_total_potencial / max(1, capacidad_pasillo)
            push!(evaluaciones_pasillos, (p, ordenes_compatibles, valor_total_potencial, score))
        end
    end
    
    if isempty(evaluaciones_pasillos)
        return mejor
    end
    
    # Ordenar por score y probar el mejor
    sort!(evaluaciones_pasillos, by=x -> x[4], rev=true)
    
    for (p_nuevo, ordenes_compatibles, valor_potencial, score) in evaluaciones_pasillos[1:min(3, length(evaluaciones_pasillos))]
        # Probar agregar este pasillo + algunas órdenes compatibles
        nuevos_pasillos = copy(mejor.pasillos)
        push!(nuevos_pasillos, p_nuevo)
        
        # Agregar las órdenes más valiosas que quepan
        nuevas_ordenes = copy(mejor.ordenes)
        valor_actual = sum(sum(roi[o, :]) for o in nuevas_ordenes)
        
        ordenes_por_valor = [(o, sum(roi[o, :])) for o in ordenes_compatibles]
        sort!(ordenes_por_valor, by=x -> x[2], rev=true)
        
        for (o, valor_o) in ordenes_por_valor
            if valor_actual + valor_o <= UB
                push!(nuevas_ordenes, o)
                valor_actual += valor_o
            end
        end
        
        if length(nuevas_ordenes) > length(mejor.ordenes)  # Solo si agregamos algo
            candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
            if es_factible(candidato, roi, upi, LB, UB, config)
                valor_candidato = evaluar(candidato, roi)
                if valor_candidato > mejor_valor
                    mejor = candidato
                    mejor_valor = valor_candidato
                    break  # Solo una expansión por vez
                end
            end
        end
    end
    
    return mejor
end

"""
SMART_EXPAND: Expansión inteligente múltiple
"""
function smart_expand_multiple(solucion::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    mejor = copiar_solucion(solucion)
    mejor_valor = evaluar(mejor, roi)
    
    # Solo expandir si tenemos pocos pasillos actualmente
    if length(mejor.pasillos) > 15
        return mejor  # Ya tenemos muchos pasillos
    end
    
    O, I = size(roi)
    P = size(upi, 1)
    
    ordenes_externas = setdiff(1:O, mejor.ordenes)
    pasillos_disponibles = setdiff(1:P, mejor.pasillos)
    
    # Probar agregar 2-3 pasillos que se complementen
    for n_pasillos in [2, 3]
        if length(pasillos_disponibles) >= n_pasillos
            # Probar combinaciones limitadas
            max_combinaciones = min(20, length(pasillos_disponibles))
            
            for combo_pasillos in combinations(sample(pasillos_disponibles, min(max_combinaciones, length(pasillos_disponibles)), replace=false), n_pasillos)
                nuevos_pasillos = union(mejor.pasillos, combo_pasillos)
                
                # Encontrar órdenes compatibles con esta expansión
                ordenes_compatibles = []
                for o in ordenes_externas
                    if es_orden_compatible(o, nuevos_pasillos, roi, upi)
                        valor_o = sum(roi[o, :])
                        valor_actual = sum(sum(roi[ord, :]) for ord in mejor.ordenes)
                        if valor_actual + valor_o <= UB
                            push!(ordenes_compatibles, (o, valor_o))
                        end
                    end
                end
                
                if length(ordenes_compatibles) >= n_pasillos * 2  # Al menos 2 órdenes por pasillo
                    # Agregar las órdenes más valiosas
                    sort!(ordenes_compatibles, by=x -> x[2], rev=true)
                    
                    nuevas_ordenes = copy(mejor.ordenes)
                    valor_actual = sum(sum(roi[o, :]) for o in nuevas_ordenes)
                    
                    for (o, valor_o) in ordenes_compatibles
                        if valor_actual + valor_o <= UB
                            push!(nuevas_ordenes, o)
                            valor_actual += valor_o
                        end
                    end
                    
                    candidato = Solucion(nuevas_ordenes, Set(nuevos_pasillos))
                    if es_factible(candidato, roi, upi, LB, UB, config)
                        valor_candidato = evaluar(candidato, roi)
                        if valor_candidato > mejor_valor
                            mejor = candidato
                            mejor_valor = valor_candidato
                            return mejor  # Solo una expansión exitosa
                        end
                    end
                end
            end
        end
    end
    
    return mejor
end

# ========================================
# MOVIMIENTOS HYBRID (Híbridos complejos)
# ========================================

"""
MOVIMIENTOS HYBRID COMPLETOS: Repack, Consolidate
"""
function movimientos_hybrid_completos(solucion::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_tiempo::Float64)
    tiempo_inicio = time()
    mejor = copiar_solucion(solucion)
    
    # 1. REPACK_OPTIMIZE: Reorganizar completamente
    mejor = repack_optimize_complete(mejor, roi, upi, LB, UB, config)
    
    if (time() - tiempo_inicio) > max_tiempo * 0.6
        return mejor
    end
    
    # 2. CONSOLIDATE_ADD: Consolidar + agregar
    mejor = consolidate_and_add(mejor, roi, upi, LB, UB, config)
    
    return mejor
end

"""
REPACK_OPTIMIZE: Reorganización completa para maximizar ratio
"""
function repack_optimize_complete(solucion::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    mejor = copiar_solucion(solucion)
    mejor_valor = evaluar(mejor, roi)
    
    O = size(roi, 1)
    
    # Mantener núcleo de mejores órdenes, reorganizar el resto
    ordenes_actuales = collect(mejor.ordenes)
    valores_ordenes = [(o, sum(roi[o, :])) for o in ordenes_actuales]
    sort!(valores_ordenes, by=x -> x[2], rev=true)
    
    # Mantener top 60% de órdenes
    n_mantener = max(1, Int(ceil(length(ordenes_actuales) * 0.6)))
    ordenes_nucleo = Set([valores_ordenes[i][1] for i in 1:n_mantener])
    ordenes_flexibles = setdiff(Set(ordenes_actuales), ordenes_nucleo)
    
    # Pool de candidatos = órdenes flexibles + órdenes externas
    candidatos_pool = union(ordenes_flexibles, setdiff(1:O, Set(ordenes_actuales)))
    
    # Construir nueva solución: núcleo + mejores candidatos hasta UB
    nuevas_ordenes = copy(ordenes_nucleo)
    valor_actual = sum(sum(roi[o, :]) for o in nuevas_ordenes)
    
    # Evaluar candidatos por eficiencia
    candidatos_evaluados = []
    for o in candidatos_pool
        valor_o = sum(roi[o, :])
        items_o = count(roi[o, :] .> 0)
        eficiencia = items_o > 0 ? valor_o / items_o : 0
        push!(candidatos_evaluados, (o, valor_o, eficiencia))
    end
    
    sort!(candidatos_evaluados, by=x -> x[3], rev=true)
    
    # Agregar candidatos hasta llenar UB
    for (o, valor_o, eficiencia) in candidatos_evaluados
        if valor_actual + valor_o <= UB
            push!(nuevas_ordenes, o)
            valor_actual += valor_o
        end
    end
    
    if length(nuevas_ordenes) != length(mejor.ordenes) || nuevas_ordenes != mejor.ordenes
        # Recalcular pasillos para la nueva configuración
        nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
        candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
        
        if es_factible(candidato, roi, upi, LB, UB, config)
            valor_candidato = evaluar(candidato, roi)
            if valor_candidato > mejor_valor
                mejor = candidato
            end
        end
    end
    
    return mejor
end

"""
CONSOLIDATE_ADD: Consolidar pasillos y agregar en espacio liberado
"""
function consolidate_and_add(solucion::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    mejor = copiar_solucion(solucion)
    mejor_valor = evaluar(mejor, roi)
    
    # Solo consolidar si tenemos muchos pasillos
    if length(mejor.pasillos) <= 5
        return mejor
    end
    
    O = size(roi, 1)
    
    # Intentar encontrar una configuración de pasillos más eficiente
    pasillos_alternativos = calcular_pasillos_optimos(mejor.ordenes, roi, upi, LB, UB, config)
    
    if length(pasillos_alternativos) < length(mejor.pasillos)
        # Consolidación exitosa, buscar órdenes para el espacio liberado
        candidato_consolidado = Solucion(mejor.ordenes, pasillos_alternativos)
        
        if es_factible(candidato_consolidado, roi, upi, LB, UB, config)
            # Buscar órdenes adicionales compatibles
            ordenes_externas = setdiff(1:O, mejor.ordenes)
            valor_actual = sum(sum(roi[o, :]) for o in mejor.ordenes)
            
            nuevas_ordenes = copy(mejor.ordenes)
            
            for o in ordenes_externas
                valor_o = sum(roi[o, :])
                if valor_actual + valor_o <= UB && es_orden_compatible(o, pasillos_alternativos, roi, upi)
                    push!(nuevas_ordenes, o)
                    valor_actual += valor_o
                end
            end
            
            if length(nuevas_ordenes) > length(mejor.ordenes)
                candidato_final = Solucion(nuevas_ordenes, pasillos_alternativos)
                if es_factible(candidato_final, roi, upi, LB, UB, config)
                    valor_final = evaluar(candidato_final, roi)
                    if valor_final > mejor_valor
                        mejor = candidato_final
                    end
                end
            end
        end
    end
    
    return mejor
end

# ========================================
# OPTIMIZACIÓN FINAL AGRESIVA
# ========================================

"""
OPTIMIZACIÓN FINAL AGRESIVA: Últimos ajustes para maximizar ratio
"""
function optimizacion_final_agresiva(solucion::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_tiempo::Float64)
    tiempo_inicio = time()
    mejor = copiar_solucion(solucion)
    mejor_valor = evaluar(mejor, roi)
    
    O = size(roi, 1)
    
    # Iteraciones de optimización agresiva
    for iter in 1:5
        if (time() - tiempo_inicio) > max_tiempo
            break
        end
        
        mejoro_iter = false
        
        # 1. Micro-ajustes de intercambios múltiples
        ordenes_actuales = collect(mejor.ordenes)
        candidatos_externos = setdiff(1:O, mejor.ordenes)
        
        if !isempty(candidatos_externos)
            # Intercambios 1-2 y 2-1
            for o_out in ordenes_actuales[1:min(5, length(ordenes_actuales))]
                valor_out = sum(roi[o_out, :])
                
                # Buscar par de candidatos que reemplacen mejor
                for c1 in candidatos_externos[1:min(10, length(candidatos_externos))]
                    for c2 in candidatos_externos[1:min(10, length(candidatos_externos))]
                        if c1 != c2
                            valor_par = sum(roi[c1, :]) + sum(roi[c2, :])
                            
                            if valor_par > valor_out * 1.4  # Al menos 40% mejor
                                valor_actual = sum(sum(roi[o, :]) for o in mejor.ordenes)
                                nuevo_valor = valor_actual - valor_out + valor_par
                                
                                if LB <= nuevo_valor <= UB
                                    nuevas_ordenes = copy(mejor.ordenes)
                                    delete!(nuevas_ordenes, o_out)
                                    push!(nuevas_ordenes, c1)
                                    push!(nuevas_ordenes, c2)
                                    
                                    nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
                                    candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
                                    
                                    if es_factible(candidato, roi, upi, LB, UB, config)
                                        valor_candidato = evaluar(candidato, roi)
                                        if valor_candidato > mejor_valor
                                            mejor = candidato
                                            mejor_valor = valor_candidato
                                            mejoro_iter = true
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if mejoro_iter
                        break
                    end
                end
                if mejoro_iter
                    break
                end
            end
        end
        
        # 2. Optimización final de pasillos
        if !mejoro_iter
            pasillos_finales = calcular_pasillos_optimos(mejor.ordenes, roi, upi, LB, UB, config)
            if pasillos_finales != mejor.pasillos
                candidato = Solucion(mejor.ordenes, pasillos_finales)
                if es_factible(candidato, roi, upi, LB, UB, config)
                    valor_candidato = evaluar(candidato, roi)
                    if valor_candidato > mejor_valor
                        mejor = candidato
                        mejor_valor = valor_candidato
                        mejoro_iter = true
                    end
                end
            end
        end
        
        # Si no mejoró, salir
        if !mejoro_iter
            break
        end
    end
    
    return mejor
end