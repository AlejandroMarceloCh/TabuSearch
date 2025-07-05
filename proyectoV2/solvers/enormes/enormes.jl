# solvers/enormes/enormes.jl
# ========================================
# SOLVER PRINCIPAL PARA INSTANCIAS ENORMES
# OBJETIVO: MANEJAR 12,000+ ÓRDENES CON ESCALABILIDAD EXTREMA
# ========================================

include("../../core/config_instancia.jl")
include("../../core/base.jl")
include("../../core/classifier.jl")
include("enormes_constructivas.jl")
include("enormes_vecindarios.jl")

using Random

# ========================================
# FUNCIÓN PRINCIPAL SOLVER ENORMES
# ========================================

"""
🚀 SOLVER PRINCIPAL PARA INSTANCIAS ENORMES 🚀
Estrategia: Sampling Masivo → VNS Escalable → LNS Ultra-Rápido → Post-optimización Mínima
Límites: 30 min máximo, verificación factibilidad básica, sampling 5-10%
"""
function resolver_enorme(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int; semilla=nothing, mostrar_detalles=true)
    
    # 1. CLASIFICAR AUTOMÁTICAMENTE
    config = clasificar_instancia(roi, upi, LB, UB)
    
    if mostrar_detalles
        println("\n" * "⚡"^60)
        println("⚡ SOLVER ENORMES - ESCALABILIDAD EXTREMA ⚡")
        println("⚡"^60)
        mostrar_info_instancia(config)
        println("\n🎯 CONFIGURACIÓN ULTRA-ESCALABLE:")
        println("   📦 Constructiva: $(config.estrategia_constructiva)")
        println("   ✅ Factibilidad: $(config.estrategia_factibilidad)")
        println("   🚪 Pasillos: $(config.estrategia_pasillos)")
        println("   🔄 Vecindarios: $(config.estrategia_vecindarios)")
        println("   ⚙️ Max iter: $(config.max_iteraciones) | Max vecinos: $(config.max_vecinos)")
        println("   ⏰ Timeout: $(config.timeout_adaptativo)s (30 min MAX)")
        if config.es_patologica
            println("   🚨 MODO PATOLÓGICO - SAMPLING INTELIGENTE")
        end
    end
    
    tiempo_inicio = time()
    O, I = size(roi)
    P = size(upi, 1)
    
    # Límites de escalabilidad para enormes
    timeout_max = min(config.timeout_adaptativo, 1800.0)  # Máximo 30 minutos
    
    if mostrar_detalles
        println("   📊 Dimensiones: $(O) órdenes × $(I) ítems × $(P) pasillos")
        println("   🎯 UB Objetivo: $UB (Margen potencial alto)")
    end
    
    # 2. FASE 1: CONSTRUCTIVA SAMPLING MASIVO (20% del tiempo - MÁS TIEMPO PARA MEJOR INICIO)
    tiempo_constructiva = timeout_max * 0.20
    if mostrar_detalles
        println("\n🎯 FASE 1: CONSTRUCTIVA SAMPLING MASIVO")
        println("   ⏰ Tiempo asignado: $(round(tiempo_constructiva, digits=1))s")
        println("   📊 Estrategia: Evaluar 5-10% de órdenes, clustering inteligente")
    end
    
    solucion_inicial = generar_solucion_inicial_enorme(roi, upi, LB, UB, config; semilla=semilla)
    
    if solucion_inicial === nothing
        error("❌ No se pudo generar solución inicial para instancia enorme")
    end
    
    valor_inicial = evaluar(solucion_inicial, roi)
    
    if mostrar_detalles
        println("\n✅ CONSTRUCTIVA COMPLETADA:")
        mostrar_solucion(solucion_inicial, roi, "CONSTRUCTIVA SAMPLING")
        println("📊 Factible: $(es_factible(solucion_inicial, roi, upi, LB, UB, config))")
        utilizacion_ub = (sum(sum(roi[o, :]) for o in solucion_inicial.ordenes) / UB) * 100
        println("📈 Utilización UB: $(round(utilizacion_ub, digits=1))%")
    end
    
    # 3. FASE 2: VNS ESCALABLE (60% del tiempo - BALANCEADO)
    tiempo_vns = timeout_max * 0.60
    if mostrar_detalles
        println("\n🔄 FASE 2: VNS ESCALABLE PARA ENORMES")
        println("   ⏰ Tiempo asignado: $(round(tiempo_vns, digits=1))s")
        println("   📊 Estrategia: Max 50 vecindarios, sampling en cada movimiento")
    end
    
    solucion_vns = variable_neighborhood_search_enorme(solucion_inicial, roi, upi, LB, UB, config; 
                                                     max_tiempo=tiempo_vns, mostrar_progreso=mostrar_detalles)
    
    valor_vns = evaluar(solucion_vns, roi)
    mejora_vns = valor_vns - valor_inicial
    
    if mostrar_detalles
        println("\n✅ VNS ESCALABLE COMPLETADO:")
        mostrar_solucion(solucion_vns, roi, "VNS ENORMES")
        println("📈 Mejora VNS: +$(round(mejora_vns, digits=3)) ($(round((mejora_vns/valor_inicial)*100, digits=1))%)")
    end
    
    # 4. FASE 3: LNS ULTRA-RÁPIDO (15% del tiempo)
    tiempo_lns = timeout_max * 0.15
    if mostrar_detalles
        println("\n⚡ FASE 3: LNS ULTRA-RÁPIDO")
        println("   ⏰ Tiempo asignado: $(round(tiempo_lns, digits=1))s")
        println("   📊 Estrategia: Destroy/repair masivo, max 500 iteraciones")
    end
    
    solucion_lns = large_neighborhood_search_enorme(solucion_vns, roi, upi, LB, UB, config; 
                                                  max_tiempo=tiempo_lns, mostrar_progreso=mostrar_detalles)
    
    valor_lns = evaluar(solucion_lns, roi)
    mejora_lns = valor_lns - valor_vns
    
    if mostrar_detalles
        println("\n✅ LNS ULTRA-RÁPIDO COMPLETADO:")
        mostrar_solucion(solucion_lns, roi, "LNS ENORMES")
        println("📈 Mejora LNS: +$(round(mejora_lns, digits=3)) ($(round((mejora_lns/valor_vns)*100, digits=1))%)")
    end
    
    # 5. FASE 4: POST-OPTIMIZACIÓN MÍNIMA (5% del tiempo)
    tiempo_post = timeout_max * 0.05
    if mostrar_detalles
        println("\n🔧 FASE 4: POST-OPTIMIZACIÓN MÍNIMA")
        println("   ⏰ Tiempo asignado: $(round(tiempo_post, digits=1))s")
        println("   📊 Estrategia: Solo ajustes críticos, factibilidad garantizada")
    end
    
    # BACKUP OBLIGATORIO antes de post-optimización
    solucion_backup = copiar_solucion(solucion_lns)
    valor_backup = valor_lns
    
    solucion_final = post_optimizacion_enormes(solucion_lns, roi, upi, LB, UB, config; 
                                             max_tiempo=tiempo_post, mostrar_progreso=mostrar_detalles)
    
    valor_final = evaluar(solucion_final, roi)
    mejora_post = valor_final - valor_lns
    
    # VERIFICACIÓN CRÍTICA DE FACTIBILIDAD
    if !es_factible(solucion_final, roi, upi, LB, UB, config)
        if mostrar_detalles
            println("   ⚠️ POST-OPTIMIZACIÓN GENERÓ SOLUCIÓN NO FACTIBLE - RESTAURANDO BACKUP")
        end
        solucion_final = solucion_backup
        valor_final = valor_backup
        mejora_post = 0.0
    end
    
    # 6. ESTADÍSTICAS FINALES
    tiempo_total = time() - tiempo_inicio
    mejora_total = valor_final - valor_inicial
    
    if mostrar_detalles
        println("\n" * "🏆"^60)
        println("🏆 RESULTADO FINAL ENORMES - ESCALABILIDAD EXTREMA")
        println("🏆"^60)
        mostrar_solucion(solucion_final, roi, "RESULTADO FINAL ENORMES")
        
        println("\n📊 RESUMEN DE MEJORAS:")
        println("   🎯 Constructiva → VNS: +$(round(mejora_vns, digits=3)) ($(round((mejora_vns/valor_inicial)*100, digits=1))%)")
        println("   🔄 VNS → LNS: +$(round(mejora_lns, digits=3)) ($(round((mejora_lns/valor_vns)*100, digits=1))%)")
        println("   🔧 LNS → Final: +$(round(mejora_post, digits=3)) ($(round((mejora_post/valor_lns)*100, digits=1))%)")
        println("   ⚡ MEJORA TOTAL: +$(round(mejora_total, digits=3)) ($(round((mejora_total/valor_inicial)*100, digits=1))%)")
        
        println("\n⏱️ DISTRIBUCIÓN DE TIEMPO:")
        println("   📊 Tiempo total: $(round(tiempo_total, digits=2))s")
        println("   🎯 Constructiva: $(round(tiempo_constructiva, digits=1))s (20%)")
        println("   🔄 VNS: $(round(tiempo_vns, digits=1))s (60%)")
        println("   ⚡ LNS: $(round(tiempo_lns, digits=1))s (15%)")
        println("   🔧 Post-opt: $(round(tiempo_post, digits=1))s (5%)")
        
        println("\n🔍 ANÁLISIS DE SOLUCIÓN ENORME:")
        unidades_totales = sum(sum(roi[o, :]) for o in solucion_final.ordenes)
        utilizacion_ub = (unidades_totales / UB) * 100
        eficiencia_pasillos = unidades_totales / length(solucion_final.pasillos)
        
        println("   📦 Órdenes seleccionadas: $(length(solucion_final.ordenes))/$O ($(round((length(solucion_final.ordenes)/O)*100, digits=1))%)")
        println("   🚪 Pasillos utilizados: $(length(solucion_final.pasillos))/$P ($(round((length(solucion_final.pasillos)/P)*100, digits=1))%)")
        println("   💰 Unidades totales: $unidades_totales/$UB")
        println("   📊 Utilización UB: $(round(utilizacion_ub, digits=1))% (CRÍTICO para enormes)")
        println("   ⚡ Eficiencia (unidades/pasillo): $(round(eficiencia_pasillos, digits=2))")
        
        # Verificación final
        factible = es_factible(solucion_final, roi, upi, LB, UB, config)
        println("\n$(factible ? "✅" : "❌") Solución $(factible ? "FACTIBLE" : "NO FACTIBLE")")
        
        if config.es_patologica
            println("\n🚨 INSTANCIA ENORME PATOLÓGICA CONQUISTADA 🚨")
        else
            println("\n🎯 INSTANCIA ENORME ESTÁNDAR OPTIMIZADA 🎯")
        end
        
        # Análisis de escalabilidad
        println("\n📈 MÉTRICAS DE ESCALABILIDAD:")
        println("   ⚡ Tiempo/orden: $(round(tiempo_total/O, digits=4))s")
        println("   🎯 Órdenes/segundo: $(round(O/tiempo_total, digits=1))")
        println("   💾 Complejidad manejada: $(round(O*I*P/1000000, digits=1))M elementos")
        
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
        ),
        metricas_escalabilidad = (
            tiempo_por_orden = tiempo_total/O,
            ordenes_por_segundo = O/tiempo_total,
            complejidad_manejada = O*I*P,
            utilizacion_ub_final = (sum(sum(roi[o, :]) for o in solucion_final.ordenes) / UB) * 100
        )
    )
end

# ========================================
# POST-OPTIMIZACIÓN MÍNIMA PARA ENORMES
# ========================================

"""
Post-optimización ultra-conservadora para enormes: Solo lo esencial
"""
function post_optimizacion_enormes(solucion::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia; max_tiempo=60.0, mostrar_progreso=true)
    
    tiempo_inicio = time()
    mejor = copiar_solucion(solucion)
    mejor_valor = evaluar(mejor, roi)
    
    if mostrar_progreso
        println("   🔧 Post-optimización mínima para enormes...")
    end
    
    # 1. RE-OPTIMIZACIÓN DE PASILLOS (50% del tiempo)
    if (time() - tiempo_inicio) < max_tiempo * 0.5
        pasillos_optimizados = calcular_pasillos_optimos(mejor.ordenes, roi, upi, LB, UB, config)
        if pasillos_optimizados != mejor.pasillos
            candidato = Solucion(mejor.ordenes, pasillos_optimizados)
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
    end
    
    # 2. INTERCAMBIOS 1-1 CRÍTICOS (40% del tiempo)
    tiempo_restante = max_tiempo - (time() - tiempo_inicio)
    if tiempo_restante > 5.0
        mejor_intercambio = intercambios_criticos_enormes(mejor, roi, upi, LB, UB, config, tiempo_restante * 0.8)
        valor_intercambio = evaluar(mejor_intercambio, roi)
        
        if valor_intercambio > mejor_valor
            mejora_intercambio = valor_intercambio - mejor_valor
            mejor = mejor_intercambio
            mejor_valor = valor_intercambio
            
            if mostrar_progreso
                println("   ⚡ Intercambios críticos: +$(round(mejora_intercambio, digits=3))")
            end
        end
    end
    
    # 3. LLENADO UB CONSERVADOR (10% del tiempo)
    tiempo_restante = max_tiempo - (time() - tiempo_inicio)
    if tiempo_restante > 2.0
        valor_actual = sum(sum(roi[o, :]) for o in mejor.ordenes)
        margen_ub = UB - valor_actual
        
        if margen_ub > 0
            mejor_llenado = llenado_ub_conservador_enormes(mejor, roi, upi, LB, UB, config, margen_ub, tiempo_restante)
            valor_llenado = evaluar(mejor_llenado, roi)
            
            if valor_llenado > mejor_valor
                mejora_llenado = valor_llenado - mejor_valor
                mejor = mejor_llenado
                mejor_valor = valor_llenado
                
                if mostrar_progreso
                    println("   📈 Llenado UB conservador: +$(round(mejora_llenado, digits=3))")
                end
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
Intercambios críticos para enormes: Solo los más prometedores
"""
function intercambios_criticos_enormes(solucion::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_tiempo::Float64)
    tiempo_inicio = time()
    mejor = copiar_solucion(solucion)
    mejor_valor = evaluar(mejor, roi)
    
    O = size(roi, 1)
    ordenes_actuales = collect(mejor.ordenes)
    candidatos_externos = setdiff(1:O, mejor.ordenes)
    
    # Limitar búsqueda para escalabilidad
    max_ordenes_actuales = min(50, length(ordenes_actuales))
    max_candidatos = min(100, length(candidatos_externos))
    
    # Evaluar solo las órdenes más prometedoras
    ordenes_evaluar = ordenes_actuales[1:min(max_ordenes_actuales, length(ordenes_actuales))]
    candidatos_evaluar = candidatos_externos[1:min(max_candidatos, length(candidatos_externos))]
    
    for o_out in ordenes_evaluar
        for o_in in candidatos_evaluar
            if (time() - tiempo_inicio) > max_tiempo
                break
            end
            
            valor_out = sum(roi[o_out, :])
            valor_in = sum(roi[o_in, :])
            
            # Solo considerar si mejora significativamente
            if valor_in > valor_out * 1.1  # Al menos 10% mejor
                valor_actual = sum(sum(roi[o, :]) for o in mejor.ordenes)
                nuevo_valor_total = valor_actual - valor_out + valor_in
                
                if LB <= nuevo_valor_total <= UB
                    nuevas_ordenes = copy(mejor.ordenes)
                    delete!(nuevas_ordenes, o_out)
                    push!(nuevas_ordenes, o_in)
                    
                    # Probar con pasillos actuales primero (más rápido)
                    candidato = Solucion(nuevas_ordenes, mejor.pasillos)
                    
                    if es_factible(candidato, roi, upi, LB, UB, config)
                        valor_candidato = evaluar(candidato, roi)
                        if valor_candidato > mejor_valor
                            mejor = candidato
                            mejor_valor = valor_candidato
                            break
                        end
                    end
                end
            end
        end
        if (time() - tiempo_inicio) > max_tiempo
            break
        end
    end
    
    return mejor
end

"""
Llenado UB conservador para enormes: Solo órdenes compatibles
"""
function llenado_ub_conservador_enormes(solucion::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, margen_ub::Int, max_tiempo::Float64)
    tiempo_inicio = time()
    mejor = copiar_solucion(solucion)
    
    O = size(roi, 1)
    candidatos_externos = setdiff(1:O, mejor.ordenes)
    
    # Evaluar solo candidatos que caben en el margen
    candidatos_validos = []
    for o in candidatos_externos
        valor_o = sum(roi[o, :])
        if valor_o <= margen_ub && es_orden_compatible(o, mejor.pasillos, roi, upi)
            push!(candidatos_validos, (o, valor_o))
        end
    end
    
    # Ordenar por valor descendente
    sort!(candidatos_validos, by=x -> x[2], rev=true)
    
    # Agregar de a una, verificando factibilidad
    for (o, valor_o) in candidatos_validos[1:min(20, length(candidatos_validos))]  # Máximo 20 intentos
        if (time() - tiempo_inicio) > max_tiempo
            break
        end
        
        nuevas_ordenes = copy(mejor.ordenes)
        push!(nuevas_ordenes, o)
        
        candidato = Solucion(nuevas_ordenes, mejor.pasillos)
        
        if es_factible(candidato, roi, upi, LB, UB, config)
            mejor = candidato
            margen_ub -= valor_o
        end
    end
    
    return mejor
end

# ========================================
# FUNCIONES DE ANÁLISIS PARA ENORMES
# ========================================

"""
Análisis específico de rendimiento para enormes
"""
function analizar_rendimiento_enormes(resultado, roi::Matrix{Int}, upi::Matrix{Int})
    O, I = size(roi)
    P = size(upi, 1)
    
    println("\n📊 ANÁLISIS DE RENDIMIENTO ENORMES:")
    println("   📏 Dimensiones: $(O)×$(I)×$(P)")
    println("   ⏱️ Tiempo total: $(round(resultado.tiempo, digits=2))s")
    println("   🎯 Ratio final: $(round(resultado.valor, digits=3))")
    println("   📈 Mejora total: $(round(resultado.mejora, digits=3))")
    println("   ✅ Factible: $(resultado.factible)")
    
    if haskey(resultado, :metricas_escalabilidad)
        metricas = resultado.metricas_escalabilidad
        println("\n⚡ MÉTRICAS DE ESCALABILIDAD:")
        println("   🚀 Tiempo/orden: $(round(metricas.tiempo_por_orden*1000, digits=2))ms")
        println("   🔥 Órdenes/segundo: $(round(metricas.ordenes_por_segundo, digits=1))")
        println("   💾 Complejidad: $(round(metricas.complejidad_manejada/1000000, digits=1))M")
        println("   📊 Utilización UB: $(round(metricas.utilizacion_ub_final, digits=1))%")
    end
    
    return resultado
end