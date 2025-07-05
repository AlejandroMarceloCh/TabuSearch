# solvers/enormes/enormes_vecindarios.jl
# ========================================
# VNS + LNS ULTRA-ESCALABLES PARA ENORMES
# OBJETIVO: MANEJAR 12,000+ ÓRDENES CON LÍMITES ESTRICTOS
# ========================================

using Random
using StatsBase: sample

# ========================================
# VNS ESCALABLE PARA ENORMES
# ========================================

"""
VNS Escalable para Enormes - Máximo 50 vecindarios, sampling en cada movimiento
"""
function variable_neighborhood_search_enorme(solucion_inicial::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia; max_tiempo=600.0, mostrar_progreso=true)
    
    tiempo_inicio = time()
    mejor_global = copiar_solucion(solucion_inicial)
    mejor_valor_global = evaluar(mejor_global, roi)
    
    O = size(roi, 1)
    I = size(roi, 2)
    P = size(upi, 1)
    
    # PARÁMETROS ULTRA-AGRESIVOS para enormes
    max_k = min(100, max(20, O ÷ 50))  # Máximo 100 vecindarios, más agresivo
    max_iter_sin_mejora = min(200, max(60, O ÷ 25))  # Más iteraciones sin mejora
    
    # LÍMITES DE SAMPLING AGRESIVOS para mejor calidad
    max_ordenes_evaluar = min(500, O ÷ 5)  # Máximo 500 órdenes por operación - 2.5x más
    max_pasillos_evaluar = min(100, P ÷ 3)   # Máximo 100 pasillos por operación - 2x más
    
    k = 1
    iteraciones_sin_mejora = 0
    iteracion_total = 0
    
    if mostrar_progreso
        println("🔄 VNS ENORMES INICIADO - k_max=$max_k")
        println("   ⚡ Solución inicial: ratio=$(round(mejor_valor_global, digits=3))")
        println("   📊 Límites sampling: max_ordenes=$max_ordenes_evaluar, max_pasillos=$max_pasillos_evaluar")
    end
    
    while time() - tiempo_inicio < max_tiempo && k <= max_k && iteraciones_sin_mejora < max_iter_sin_mejora
        iteracion_total += 1
        
        # SHAKE: Perturbar en vecindario k con sampling
        solucion_perturbada = shake_vecindario_k_enorme(mejor_global, k, roi, upi, LB, UB, config, max_ordenes_evaluar, max_pasillos_evaluar)
        
        if solucion_perturbada !== nothing
            # LOCAL SEARCH: Mejora local con sampling
            solucion_mejorada = busqueda_local_sampling_enorme(solucion_perturbada, roi, upi, LB, UB, config, max_ordenes_evaluar)
            
            if solucion_mejorada !== nothing
                valor_mejorado = evaluar(solucion_mejorada, roi)
                
                # MOVE OR NOT
                if valor_mejorado > mejor_valor_global
                    mejor_global = solucion_mejorada
                    mejor_valor_global = valor_mejorado
                    k = 1  # Reset a primer vecindario
                    iteraciones_sin_mejora = 0
                    
                    if mostrar_progreso
                        println("   🚀 MEJORA VNS-ENORMES k=$k: ratio=$(round(valor_mejorado, digits=3))")
                    end
                else
                    k += 1
                    iteraciones_sin_mejora += 1
                end
            else
                k += 1
                iteraciones_sin_mejora += 1
            end
        else
            k += 1
            iteraciones_sin_mejora += 1
        end
        
        # Restart menos frecuente para enormes
        if config.es_patologica && iteraciones_sin_mejora >= 80
            k = 1
            iteraciones_sin_mejora = 0
            if mostrar_progreso
                println("   🔄 VNS-ENORMES RESTART agresivo")
            end
        end
    end
    
    tiempo_total = time() - tiempo_inicio
    if mostrar_progreso
        println("   ✅ VNS-ENORMES COMPLETADO: $(iteracion_total) iteraciones, $(round(tiempo_total, digits=2))s")
        println("   🏆 Ratio final: $(round(mejor_valor_global, digits=3))")
    end
    
    return mejor_global
end

# ========================================
# SHAKE ESCALABLE CON SAMPLING
# ========================================

"""
Shake escalable para enormes - Todos los vecindarios usan sampling
"""
function shake_vecindario_k_enorme(solucion::Solucion, k::Int, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_ordenes::Int, max_pasillos::Int)
    
    if k == 1
        return shake_k1_intercambio_sampling(solucion, roi, upi, LB, UB, config, max_ordenes)
    elseif k == 2
        return shake_k2_batch_sampling(solucion, roi, upi, LB, UB, config, max_ordenes)
    elseif k == 3
        return shake_k3_multiple_sampling(solucion, roi, upi, LB, UB, config, max_ordenes)
    elseif k == 4
        return shake_k4_pasillos_sampling(solucion, roi, upi, LB, UB, config, max_pasillos)
    elseif k == 5
        return shake_k5_clusters_sampling(solucion, roi, upi, LB, UB, config, max_ordenes)
    elseif k >= 6
        # Para k >= 6, usar perturbaciones incrementalmente más agresivas
        intensidad = min(0.3, (k - 5) * 0.05)  # 5%, 10%, 15%, ... hasta 30%
        return shake_k_agresivo_sampling(solucion, k, intensidad, roi, upi, LB, UB, config, max_ordenes)
    end
    
    return nothing
end

"""
K=1: Intercambio 1-1 con sampling
"""
function shake_k1_intercambio_sampling(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_ordenes::Int)
    O = size(roi, 1)
    
    ordenes_actuales = collect(sol.ordenes)
    candidatos_externos = setdiff(1:O, sol.ordenes)
    
    if isempty(ordenes_actuales) || isempty(candidatos_externos)
        return nothing
    end
    
    # SAMPLING para escalabilidad
    n_actuales = min(max_ordenes ÷ 2, length(ordenes_actuales))
    n_externos = min(max_ordenes ÷ 2, length(candidatos_externos))
    
    ordenes_sample = sample(ordenes_actuales, min(n_actuales, length(ordenes_actuales)), replace=false)
    candidatos_sample = sample(candidatos_externos, min(n_externos, length(candidatos_externos)), replace=false)
    
    # Intercambio aleatorio dentro del sample
    o_out = rand(ordenes_sample)
    o_in = rand(candidatos_sample)
    
    valor_out = sum(roi[o_out, :])
    valor_in = sum(roi[o_in, :])
    valor_actual = sum(sum(roi[o, :]) for o in sol.ordenes)
    nuevo_valor = valor_actual - valor_out + valor_in
    
    if LB <= nuevo_valor <= UB
        nuevas_ordenes = copy(sol.ordenes)
        delete!(nuevas_ordenes, o_out)
        push!(nuevas_ordenes, o_in)
        
        nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
        candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
        
        if es_factible(candidato, roi, upi, LB, UB, config)
            return candidato
        end
    end
    
    return nothing
end

"""
K=2: Batch con sampling
"""
function shake_k2_batch_sampling(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_ordenes::Int)
    O = size(roi, 1)
    
    valor_actual = sum(sum(roi[o, :]) for o in sol.ordenes)
    margen = UB - valor_actual
    candidatos_externos = setdiff(1:O, sol.ordenes)
    
    if margen <= 0 || isempty(candidatos_externos)
        return nothing
    end
    
    # SAMPLING de candidatos
    n_candidatos = min(max_ordenes, length(candidatos_externos))
    candidatos_sample = sample(candidatos_externos, min(n_candidatos, length(candidatos_externos)), replace=false)
    
    # Decidir aleatoriamente: agregar o quitar lote
    if margen > 50 && rand() < 0.6
        return agregar_lote_sampling(sol, candidatos_sample, roi, upi, LB, UB, config)
    else
        return quitar_lote_sampling(sol, roi, upi, LB, UB, config, max_ordenes)
    end
end

"""
K=3: Intercambio múltiple con sampling
"""
function shake_k3_multiple_sampling(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_ordenes::Int)
    O = size(roi, 1)
    
    ordenes_actuales = collect(sol.ordenes)
    candidatos_externos = setdiff(1:O, sol.ordenes)
    
    if length(ordenes_actuales) < 2 || isempty(candidatos_externos)
        return nothing
    end
    
    # SAMPLING para escalabilidad
    n_actuales = min(max_ordenes ÷ 3, length(ordenes_actuales))
    n_externos = min(max_ordenes ÷ 3, length(candidatos_externos))
    
    ordenes_sample = sample(ordenes_actuales, min(n_actuales, length(ordenes_actuales)), replace=false)
    candidatos_sample = sample(candidatos_externos, min(n_externos, length(candidatos_externos)), replace=false)
    
    # Intentar 2-1: Quitar 2, agregar 1
    if rand() < 0.5 && length(ordenes_sample) >= 2
        ordenes_quitar = sample(ordenes_sample, 2, replace=false)
        if !isempty(candidatos_sample)
            orden_agregar = rand(candidatos_sample)
            
            valor_quitar = sum(sum(roi[o, :]) for o in ordenes_quitar)
            valor_agregar = sum(roi[orden_agregar, :])
            valor_actual = sum(sum(roi[o, :]) for o in sol.ordenes)
            nuevo_valor = valor_actual - valor_quitar + valor_agregar
            
            if LB <= nuevo_valor <= UB
                nuevas_ordenes = setdiff(sol.ordenes, Set(ordenes_quitar))
                push!(nuevas_ordenes, orden_agregar)
                
                nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
                candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
                
                if es_factible(candidato, roi, upi, LB, UB, config)
                    return candidato
                end
            end
        end
    end
    
    # Intentar 1-2: Quitar 1, agregar 2
    if length(candidatos_sample) >= 2
        orden_quitar = rand(ordenes_sample)
        ordenes_agregar = sample(candidatos_sample, 2, replace=false)
        
        valor_quitar = sum(roi[orden_quitar, :])
        valor_agregar = sum(sum(roi[o, :]) for o in ordenes_agregar)
        valor_actual = sum(sum(roi[o, :]) for o in sol.ordenes)
        nuevo_valor = valor_actual - valor_quitar + valor_agregar
        
        if LB <= nuevo_valor <= UB
            nuevas_ordenes = setdiff(sol.ordenes, [orden_quitar])
            for o in ordenes_agregar
                push!(nuevas_ordenes, o)
            end
            
            nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
            candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
            
            if es_factible(candidato, roi, upi, LB, UB, config)
                return candidato
            end
        end
    end
    
    return nothing
end

"""
K=4: Re-optimización de pasillos con sampling
"""
function shake_k4_pasillos_sampling(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_pasillos::Int)
    P = size(upi, 1)
    
    # 1. Re-calcular pasillos óptimos
    pasillos_optimizados = calcular_pasillos_optimos(sol.ordenes, roi, upi, LB, UB, config)
    
    if pasillos_optimizados != sol.pasillos
        candidato = Solucion(sol.ordenes, pasillos_optimizados)
        if es_factible(candidato, roi, upi, LB, UB, config)
            return candidato
        end
    end
    
    # 2. Perturbación de pasillos con sampling
    n_cambios = max(1, min(5, Int(ceil(length(sol.pasillos) * 0.2))))  # Máximo 5 cambios
    pasillos_candidatos = setdiff(1:P, sol.pasillos)
    
    if length(pasillos_candidatos) >= n_cambios
        # SAMPLING de pasillos para escalabilidad
        n_sample = min(max_pasillos, length(pasillos_candidatos))
        pasillos_sample = sample(pasillos_candidatos, min(n_sample, length(pasillos_candidatos)), replace=false)
        
        pasillos_actuales = collect(sol.pasillos)
        pasillos_remover = sample(pasillos_actuales, min(n_cambios, length(pasillos_actuales)), replace=false)
        pasillos_agregar = sample(pasillos_sample, min(n_cambios, length(pasillos_sample)), replace=false)
        
        nuevos_pasillos = setdiff(sol.pasillos, Set(pasillos_remover))
        for p in pasillos_agregar
            push!(nuevos_pasillos, p)
        end
        
        candidato = Solucion(sol.ordenes, nuevos_pasillos)
        if es_factible(candidato, roi, upi, LB, UB, config)
            return candidato
        end
    end
    
    return nothing
end

"""
K=5: Perturbación por clusters con sampling
"""
function shake_k5_clusters_sampling(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_ordenes::Int)
    O, I = size(roi)
    
    ordenes_actuales = collect(sol.ordenes)
    
    if length(ordenes_actuales) < 3
        return nothing
    end
    
    # SAMPLING de órdenes actuales para escalabilidad
    n_sample = min(max_ordenes, length(ordenes_actuales))
    ordenes_sample = sample(ordenes_actuales, min(n_sample, length(ordenes_actuales)), replace=false)
    
    # Encontrar cluster simple por valor similar
    valores_sample = [(o, sum(roi[o, :])) for o in ordenes_sample]
    sort!(valores_sample, by=x -> x[2])
    
    # Formar cluster con órdenes de valor similar (20% medio)
    inicio = Int(ceil(length(valores_sample) * 0.4))
    fin = Int(ceil(length(valores_sample) * 0.6))
    cluster_ordenes = [valores_sample[i][1] for i in inicio:fin]
    
    if length(cluster_ordenes) >= 2
        # SAMPLING de candidatos externos
        candidatos_externos = setdiff(1:O, sol.ordenes)
        n_candidatos = min(max_ordenes, length(candidatos_externos))
        candidatos_sample = sample(candidatos_externos, min(n_candidatos, length(candidatos_externos)), replace=false)
        
        # Reemplazar cluster
        if length(candidatos_sample) >= length(cluster_ordenes)
            ordenes_reemplazo = sample(candidatos_sample, length(cluster_ordenes), replace=false)
            
            valor_cluster = sum(sum(roi[o, :]) for o in cluster_ordenes)
            valor_reemplazo = sum(sum(roi[o, :]) for o in ordenes_reemplazo)
            valor_actual = sum(sum(roi[o, :]) for o in sol.ordenes)
            nuevo_valor = valor_actual - valor_cluster + valor_reemplazo
            
            if LB <= nuevo_valor <= UB
                nuevas_ordenes = setdiff(sol.ordenes, Set(cluster_ordenes))
                for o in ordenes_reemplazo
                    push!(nuevas_ordenes, o)
                end
                
                nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
                candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
                
                if es_factible(candidato, roi, upi, LB, UB, config)
                    return candidato
                end
            end
        end
    end
    
    return nothing
end

"""
K>=6: Perturbaciones agresivas con sampling
"""
function shake_k_agresivo_sampling(solucion::Solucion, k::Int, intensidad::Float64, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_ordenes::Int)
    O = size(roi, 1)
    
    ordenes_actuales = collect(solucion.ordenes)
    candidatos_externos = setdiff(1:O, solucion.ordenes)
    
    if isempty(ordenes_actuales) || isempty(candidatos_externos)
        return nothing
    end
    
    # Determinar cuántas órdenes cambiar (con límite de sampling)
    n_cambios = max(1, min(max_ordenes ÷ 4, Int(ceil(length(ordenes_actuales) * intensidad))))
    
    # SAMPLING para escalabilidad
    n_actuales = min(max_ordenes ÷ 2, length(ordenes_actuales))
    n_externos = min(max_ordenes ÷ 2, length(candidatos_externos))
    
    ordenes_sample = sample(ordenes_actuales, min(n_actuales, length(ordenes_actuales)), replace=false)
    candidatos_sample = sample(candidatos_externos, min(n_externos, length(candidatos_externos)), replace=false)
    
    # Método alternativo según k
    metodo = ((k - 6) % 3) + 1
    
    if metodo == 1
        # Reemplazo aleatorio
        return shake_reemplazo_sampling(solucion, ordenes_sample, candidatos_sample, n_cambios, roi, upi, LB, UB, config)
    elseif metodo == 2
        # Optimización por valor
        return shake_optimizacion_sampling(solucion, ordenes_sample, candidatos_sample, n_cambios, roi, upi, LB, UB, config)
    else
        # Reconstrucción parcial
        return shake_reconstruccion_sampling(solucion, ordenes_sample, candidatos_sample, intensidad, roi, upi, LB, UB, config)
    end
end

# ========================================
# BÚSQUEDA LOCAL CON SAMPLING
# ========================================

"""
Búsqueda local con sampling para enormes
"""
function busqueda_local_sampling_enorme(solucion::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_ordenes::Int)
    O = size(roi, 1)
    
    mejor_local = copiar_solucion(solucion)
    mejor_valor = evaluar(mejor_local, roi)
    mejoro = true
    iteraciones = 0
    
    while mejoro && iteraciones < 5  # Máximo 5 iteraciones para escalabilidad
        mejoro = false
        iteraciones += 1
        
        ordenes_actuales = collect(mejor_local.ordenes)
        candidatos_externos = setdiff(1:O, mejor_local.ordenes)
        
        # SAMPLING para escalabilidad
        n_actuales = min(max_ordenes ÷ 2, length(ordenes_actuales))
        n_externos = min(max_ordenes ÷ 2, length(candidatos_externos))
        
        ordenes_sample = sample(ordenes_actuales, min(n_actuales, length(ordenes_actuales)), replace=false)
        candidatos_sample = sample(candidatos_externos, min(n_externos, length(candidatos_externos)), replace=false)
        
        # Intercambios 1-1 en el sample
        for o_out in ordenes_sample
            for o_in in candidatos_sample
                valor_out = sum(roi[o_out, :])
                valor_in = sum(roi[o_in, :])
                valor_actual = sum(sum(roi[o, :]) for o in mejor_local.ordenes)
                nuevo_valor = valor_actual - valor_out + valor_in
                
                if LB <= nuevo_valor <= UB
                    nuevas_ordenes = copy(mejor_local.ordenes)
                    delete!(nuevas_ordenes, o_out)
                    push!(nuevas_ordenes, o_in)
                    
                    nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
                    candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
                    
                    if es_factible(candidato, roi, upi, LB, UB, config)
                        valor_candidato = evaluar(candidato, roi)
                        if valor_candidato > mejor_valor
                            mejor_local = candidato
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
    end
    
    return mejor_local
end

# ========================================
# LNS ULTRA-ESCALABLE PARA ENORMES
# ========================================

"""
LNS Ultra-Escalable para Enormes - Máximo 500 iteraciones, destroy/repair masivo
"""
function large_neighborhood_search_enorme(solucion_inicial::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia; max_tiempo=300.0, mostrar_progreso=true)
    
    tiempo_inicio = time()
    mejor_global = copiar_solucion(solucion_inicial)
    mejor_valor_global = evaluar(mejor_global, roi)
    
    O = size(roi, 1)
    
    # PARÁMETROS ULTRA-ESCALABLES
    max_iteraciones = min(500, max(100, O ÷ 5))  # Máximo 500 iteraciones
    removal_sizes = [0.2, 0.3, 0.4]  # Tamaños de destrucción más conservadores
    
    # LÍMITES DE SAMPLING
    max_candidatos_destroy = min(500, O ÷ 2)  # Máximo 500 candidatos por destroy
    max_candidatos_repair = min(200, O ÷ 5)   # Máximo 200 candidatos por repair
    
    if mostrar_progreso
        println("🔨 LNS-ENORMES INICIADO")
        println("   ⚡ Solución inicial: ratio=$(round(mejor_valor_global, digits=3))")
        println("   📊 Límites: max_iter=$max_iteraciones, sampling_destroy=$max_candidatos_destroy, sampling_repair=$max_candidatos_repair")
    end
    
    for iter in 1:max_iteraciones
        if time() - tiempo_inicio > max_tiempo
            break
        end
        
        # Seleccionar tamaño de destrucción
        removal_size = rand(removal_sizes)
        
        # DESTROY con sampling
        destroy_op = seleccionar_destroy_operator(iter, max_iteraciones)
        solucion_parcial = aplicar_destroy_sampling(mejor_global, destroy_op, removal_size, roi, config, max_candidatos_destroy)
        
        if solucion_parcial !== nothing
            # REPAIR con sampling
            repair_op = seleccionar_repair_operator(iter, max_iteraciones)
            solucion_nueva = aplicar_repair_sampling(solucion_parcial, repair_op, roi, upi, LB, UB, config, max_candidatos_repair)
            
            if solucion_nueva !== nothing && es_factible(solucion_nueva, roi, upi, LB, UB, config)
                valor_nuevo = evaluar(solucion_nueva, roi)
                
                # ACCEPT/REJECT más conservador para enormes
                if aceptar_solucion_enorme(valor_nuevo, mejor_valor_global, iter, max_iteraciones, config)
                    if valor_nuevo > mejor_valor_global
                        mejor_global = solucion_nueva
                        mejor_valor_global = valor_nuevo
                        
                        if mostrar_progreso
                            println("   🚀 LNS-ENORMES MEJORA iter=$iter: ratio=$(round(valor_nuevo, digits=3))")
                        end
                    end
                end
            end
        end
        
        # Intensificación cada 50 iteraciones
        if iter % 50 == 0 && config.es_patologica
            mejor_global = busqueda_local_sampling_enorme(mejor_global, roi, upi, LB, UB, config, max_candidatos_repair)
            mejor_valor_global = evaluar(mejor_global, roi)
        end
    end
    
    tiempo_total = time() - tiempo_inicio
    if mostrar_progreso
        println("   ✅ LNS-ENORMES COMPLETADO: $(round(tiempo_total, digits=2))s")
        println("   🏆 Ratio final: $(round(mejor_valor_global, digits=3))")
    end
    
    return mejor_global
end

# ========================================
# FUNCIONES AUXILIARES PARA SHAKE
# ========================================

"""
Agregar lote con sampling
"""
function agregar_lote_sampling(sol::Solucion, candidatos_sample::Vector{Int}, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    valor_actual = sum(sum(roi[o, :]) for o in sol.ordenes)
    margen = UB - valor_actual
    
    # Seleccionar 2-3 órdenes del sample
    n_agregar = min(rand(2:3), length(candidatos_sample))
    
    if n_agregar <= 0
        return nothing
    end
    
    ordenes_agregar = sample(candidatos_sample, n_agregar, replace=false)
    
    # Verificar que el lote cabe en el presupuesto
    valor_lote = sum(sum(roi[o, :]) for o in ordenes_agregar)
    
    if valor_lote <= margen
        nuevas_ordenes = copy(sol.ordenes)
        for o in ordenes_agregar
            push!(nuevas_ordenes, o)
        end
        
        nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
        candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
        
        if es_factible(candidato, roi, upi, LB, UB, config)
            return candidato
        end
    end
    
    return nothing
end

"""
Quitar lote con sampling
"""
function quitar_lote_sampling(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_ordenes::Int)
    ordenes_actuales = collect(sol.ordenes)
    
    if length(ordenes_actuales) < 2
        return nothing
    end
    
    # Sampling para escalabilidad
    n_sample = min(max_ordenes, length(ordenes_actuales))
    ordenes_sample = sample(ordenes_actuales, min(n_sample, length(ordenes_actuales)), replace=false)
    
    # Quitar 2-3 órdenes del sample
    n_quitar = min(rand(2:3), length(ordenes_sample), length(ordenes_actuales) - 1)
    
    if n_quitar <= 0
        return nothing
    end
    
    ordenes_quitar = sample(ordenes_sample, n_quitar, replace=false)
    
    nuevas_ordenes = setdiff(sol.ordenes, Set(ordenes_quitar))
    valor_nuevo = sum(sum(roi[o, :]) for o in nuevas_ordenes)
    
    if valor_nuevo >= LB && !isempty(nuevas_ordenes)
        nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
        candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
        
        if es_factible(candidato, roi, upi, LB, UB, config)
            return candidato
        end
    end
    
    return nothing
end

"""
Shake por reemplazo con sampling
"""
function shake_reemplazo_sampling(solucion::Solucion, ordenes_sample::Vector{Int}, candidatos_sample::Vector{Int}, n_cambios::Int, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    if length(ordenes_sample) < n_cambios || length(candidatos_sample) < n_cambios
        return nothing
    end
    
    ordenes_quitar = sample(ordenes_sample, n_cambios, replace=false)
    ordenes_agregar = sample(candidatos_sample, n_cambios, replace=false)
    
    valor_quitar = sum(sum(roi[o, :]) for o in ordenes_quitar)
    valor_agregar = sum(sum(roi[o, :]) for o in ordenes_agregar)
    valor_actual = sum(sum(roi[o, :]) for o in solucion.ordenes)
    nuevo_valor = valor_actual - valor_quitar + valor_agregar
    
    if LB <= nuevo_valor <= UB
        nuevas_ordenes = setdiff(solucion.ordenes, Set(ordenes_quitar))
        for o in ordenes_agregar
            push!(nuevas_ordenes, o)
        end
        
        nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
        candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
        
        if es_factible(candidato, roi, upi, LB, UB, config)
            return candidato
        end
    end
    
    return nothing
end

"""
Shake por optimización con sampling
"""
function shake_optimizacion_sampling(solucion::Solucion, ordenes_sample::Vector{Int}, candidatos_sample::Vector{Int}, n_cambios::Int, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    # Encontrar las peores órdenes del sample
    ordenes_eficiencias = []
    for o in ordenes_sample
        valor = sum(roi[o, :])
        items = count(roi[o, :] .> 0)
        eficiencia = items > 0 ? valor / items : 0
        push!(ordenes_eficiencias, (o, eficiencia))
    end
    
    sort!(ordenes_eficiencias, by=x -> x[2])
    ordenes_peores = [ordenes_eficiencias[i][1] for i in 1:min(n_cambios, length(ordenes_eficiencias))]
    
    # Encontrar las mejores órdenes candidatas
    candidatos_eficiencias = []
    for o in candidatos_sample
        valor = sum(roi[o, :])
        items = count(roi[o, :] .> 0)
        eficiencia = items > 0 ? valor / items : 0
        push!(candidatos_eficiencias, (o, eficiencia))
    end
    
    sort!(candidatos_eficiencias, by=x -> x[2], rev=true)
    ordenes_mejores = [candidatos_eficiencias[i][1] for i in 1:min(n_cambios, length(candidatos_eficiencias))]
    
    # Reemplazar peores por mejores
    valor_quitar = sum(sum(roi[o, :]) for o in ordenes_peores)
    valor_agregar = sum(sum(roi[o, :]) for o in ordenes_mejores)
    valor_actual = sum(sum(roi[o, :]) for o in solucion.ordenes)
    nuevo_valor = valor_actual - valor_quitar + valor_agregar
    
    if LB <= nuevo_valor <= UB
        nuevas_ordenes = setdiff(solucion.ordenes, Set(ordenes_peores))
        for o in ordenes_mejores
            push!(nuevas_ordenes, o)
        end
        
        nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
        candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
        
        if es_factible(candidato, roi, upi, LB, UB, config)
            return candidato
        end
    end
    
    return nothing
end

"""
Shake por reconstrucción con sampling
"""
function shake_reconstruccion_sampling(solucion::Solucion, ordenes_sample::Vector{Int}, candidatos_sample::Vector{Int}, intensidad::Float64, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    # Reconstruir una fracción de la solución
    n_reconstruir = max(1, Int(ceil(length(ordenes_sample) * intensidad)))
    
    if n_reconstruir >= length(ordenes_sample)
        return nothing
    end
    
    # Quitar órdenes aleatoriamente del sample
    ordenes_quitar = sample(ordenes_sample, n_reconstruir, replace=false)
    
    # Mantener el resto
    ordenes_mantener = setdiff(solucion.ordenes, Set(ordenes_quitar))
    
    # Agregar nuevas órdenes desde candidatos
    valor_actual = sum(sum(roi[o, :]) for o in ordenes_mantener)
    margen = UB - valor_actual
    
    candidatos_viables = []
    for o in candidatos_sample
        valor = sum(roi[o, :])
        if valor > 0 && valor <= margen
            push!(candidatos_viables, (o, valor))
        end
    end
    
    sort!(candidatos_viables, by=x -> x[2], rev=true)
    
    nuevas_ordenes = copy(ordenes_mantener)
    for (o, valor) in candidatos_viables
        if valor_actual + valor <= UB
            push!(nuevas_ordenes, o)
            valor_actual += valor
        end
    end
    
    if valor_actual >= LB && !isempty(nuevas_ordenes)
        nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
        candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
        
        if es_factible(candidato, roi, upi, LB, UB, config)
            return candidato
        end
    end
    
    return nothing
end

# ========================================
# DESTROY/REPAIR OPERATORS CON SAMPLING
# ========================================

"""
Aplicar destroy con sampling
"""
function aplicar_destroy_sampling(solucion::Solucion, destroy_op::Symbol, removal_size::Float64, roi::Matrix{Int}, config::ConfigInstancia, max_candidatos::Int)
    if destroy_op == :random
        return destroy_random_sampling(solucion, removal_size, roi, max_candidatos)
    elseif destroy_op == :worst
        return destroy_worst_sampling(solucion, removal_size, roi, max_candidatos)
    elseif destroy_op == :related
        return destroy_related_sampling(solucion, removal_size, roi, max_candidatos)
    end
    
    return nothing
end

"""
Destroy random con sampling
"""
function destroy_random_sampling(solucion::Solucion, removal_size::Float64, roi::Matrix{Int}, max_candidatos::Int)
    ordenes_actuales = collect(solucion.ordenes)
    n_remover = max(1, Int(ceil(length(ordenes_actuales) * removal_size)))
    n_remover = min(n_remover, length(ordenes_actuales) - 1)
    
    if n_remover <= 0
        return nothing
    end
    
    # SAMPLING si hay demasiadas órdenes
    if length(ordenes_actuales) > max_candidatos
        ordenes_sample = sample(ordenes_actuales, max_candidatos, replace=false)
        n_remover = min(n_remover, length(ordenes_sample) ÷ 2)
        ordenes_remover = sample(ordenes_sample, n_remover, replace=false)
    else
        ordenes_remover = sample(ordenes_actuales, n_remover, replace=false)
    end
    
    ordenes_restantes = setdiff(solucion.ordenes, Set(ordenes_remover))
    
    return (ordenes_restantes, collect(ordenes_remover))
end

"""
Destroy worst con sampling
"""
function destroy_worst_sampling(solucion::Solucion, removal_size::Float64, roi::Matrix{Int}, max_candidatos::Int)
    ordenes_actuales = collect(solucion.ordenes)
    n_remover = max(1, Int(ceil(length(ordenes_actuales) * removal_size)))
    n_remover = min(n_remover, length(ordenes_actuales) - 1)
    
    if n_remover <= 0
        return nothing
    end
    
    # SAMPLING si hay demasiadas órdenes
    if length(ordenes_actuales) > max_candidatos
        ordenes_sample = sample(ordenes_actuales, max_candidatos, replace=false)
    else
        ordenes_sample = ordenes_actuales
    end
    
    # Calcular eficiencias en el sample
    ordenes_eficiencias = []
    for o in ordenes_sample
        valor = sum(roi[o, :])
        items = count(roi[o, :] .> 0)
        eficiencia = items > 0 ? valor / items : 0
        push!(ordenes_eficiencias, (o, eficiencia))
    end
    
    sort!(ordenes_eficiencias, by=x -> x[2])  # Peores primero
    n_remover_real = min(n_remover, length(ordenes_eficiencias))
    ordenes_remover = [ordenes_eficiencias[i][1] for i in 1:n_remover_real]
    ordenes_restantes = setdiff(solucion.ordenes, Set(ordenes_remover))
    
    return (ordenes_restantes, ordenes_remover)
end

"""
Destroy related con sampling
"""
function destroy_related_sampling(solucion::Solucion, removal_size::Float64, roi::Matrix{Int}, max_candidatos::Int)
    ordenes_actuales = collect(solucion.ordenes)
    n_remover = max(1, Int(ceil(length(ordenes_actuales) * removal_size)))
    n_remover = min(n_remover, length(ordenes_actuales) - 1)
    
    if n_remover <= 0 || length(ordenes_actuales) < 2
        return nothing
    end
    
    I = size(roi, 2)
    
    # SAMPLING si hay demasiadas órdenes
    if length(ordenes_actuales) > max_candidatos
        ordenes_sample = sample(ordenes_actuales, max_candidatos, replace=false)
    else
        ordenes_sample = ordenes_actuales
    end
    
    # Seleccionar orden semilla aleatoria del sample
    orden_semilla = rand(ordenes_sample)
    items_semilla = Set(i for i in 1:I if roi[orden_semilla, i] > 0)
    
    # Encontrar órdenes relacionadas en el sample
    ordenes_similitudes = []
    for o in ordenes_sample
        if o != orden_semilla
            items_o = Set(i for i in 1:I if roi[o, i] > 0)
            interseccion = length(intersect(items_semilla, items_o))
            union_size = length(union(items_semilla, items_o))
            similitud = union_size > 0 ? interseccion / union_size : 0
            push!(ordenes_similitudes, (o, similitud))
        end
    end
    
    sort!(ordenes_similitudes, by=x -> x[2], rev=true)  # Más similares primero
    
    ordenes_remover = [orden_semilla]
    for (o, sim) in ordenes_similitudes
        if length(ordenes_remover) >= n_remover
            break
        end
        push!(ordenes_remover, o)
    end
    
    ordenes_restantes = setdiff(solucion.ordenes, Set(ordenes_remover))
    
    return (ordenes_restantes, ordenes_remover)
end

"""
Aplicar repair con sampling
"""
function aplicar_repair_sampling(solucion_parcial, repair_op::Symbol, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_candidatos::Int)
    ordenes_restantes, ordenes_removidas = solucion_parcial
    
    if repair_op == :greedy
        return repair_greedy_sampling(ordenes_restantes, ordenes_removidas, roi, upi, LB, UB, config, max_candidatos)
    elseif repair_op == :best_fit
        return repair_best_fit_sampling(ordenes_restantes, ordenes_removidas, roi, upi, LB, UB, config, max_candidatos)
    elseif repair_op == :balanced
        return repair_balanced_sampling(ordenes_restantes, ordenes_removidas, roi, upi, LB, UB, config, max_candidatos)
    end
    
    return nothing
end

"""
Repair greedy con sampling
"""
function repair_greedy_sampling(ordenes_restantes::Set{Int}, ordenes_removidas::Vector{Int}, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_candidatos::Int)
    O = size(roi, 1)
    
    valor_actual = sum(sum(roi[o, :]) for o in ordenes_restantes)
    margen_disponible = UB - valor_actual
    
    # Pool de candidatos con sampling
    candidatos = union(Set(ordenes_removidas), setdiff(1:O, ordenes_restantes))
    
    if length(candidatos) > max_candidatos
        candidatos_sample = sample(collect(candidatos), max_candidatos, replace=false)
    else
        candidatos_sample = collect(candidatos)
    end
    
    # Ordenar por valor descendente
    candidatos_valor = [(o, sum(roi[o, :])) for o in candidatos_sample if sum(roi[o, :]) > 0]
    sort!(candidatos_valor, by=x -> x[2], rev=true)
    
    # Agregar greedily
    nuevas_ordenes = copy(ordenes_restantes)
    
    for (o, valor) in candidatos_valor
        if valor <= margen_disponible
            push!(nuevas_ordenes, o)
            valor_actual += valor
            margen_disponible -= valor
        end
    end
    
    if valor_actual >= LB && !isempty(nuevas_ordenes)
        nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
        return Solucion(nuevas_ordenes, nuevos_pasillos)
    end
    
    return nothing
end

"""
Repair best fit con sampling
"""
function repair_best_fit_sampling(ordenes_restantes::Set{Int}, ordenes_removidas::Vector{Int}, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_candidatos::Int)
    O = size(roi, 1)
    
    valor_actual = sum(sum(roi[o, :]) for o in ordenes_restantes)
    margen_disponible = UB - valor_actual
    
    # Calcular pasillos actuales
    pasillos_actuales = calcular_pasillos_optimos(ordenes_restantes, roi, upi, LB, UB, config)
    
    candidatos = union(Set(ordenes_removidas), setdiff(1:O, ordenes_restantes))
    
    if length(candidatos) > max_candidatos
        candidatos_sample = sample(collect(candidatos), max_candidatos, replace=false)
    else
        candidatos_sample = collect(candidatos)
    end
    
    # Evaluar candidatos por fit con pasillos actuales
    candidatos_fit = []
    for o in candidatos_sample
        valor = sum(roi[o, :])
        if valor > 0 && valor <= margen_disponible
            # Verificar compatibilidad con pasillos actuales
            es_compatible = es_orden_compatible(o, pasillos_actuales, roi, upi)
            
            # Score: valor alto + compatibilidad
            score = valor * (es_compatible ? 2.0 : 1.0)
            push!(candidatos_fit, (o, valor, score, es_compatible))
        end
    end
    
    sort!(candidatos_fit, by=x -> x[3], rev=true)  # Mejor fit primero
    
    nuevas_ordenes = copy(ordenes_restantes)
    
    for (o, valor, score, compatible) in candidatos_fit
        if valor_actual + valor <= UB
            push!(nuevas_ordenes, o)
            valor_actual += valor
        end
    end
    
    if valor_actual >= LB && !isempty(nuevas_ordenes)
        nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
        return Solucion(nuevas_ordenes, nuevos_pasillos)
    end
    
    return nothing
end

"""
Repair balanced con sampling
"""
function repair_balanced_sampling(ordenes_restantes::Set{Int}, ordenes_removidas::Vector{Int}, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_candidatos::Int)
    O = size(roi, 1)
    
    valor_actual = sum(sum(roi[o, :]) for o in ordenes_restantes)
    margen_disponible = UB - valor_actual
    
    candidatos = union(Set(ordenes_removidas), setdiff(1:O, ordenes_restantes))
    
    if length(candidatos) > max_candidatos
        candidatos_sample = sample(collect(candidatos), max_candidatos, replace=false)
    else
        candidatos_sample = collect(candidatos)
    end
    
    # Evaluar candidatos por criterio balanceado
    candidatos_balanceados = []
    for o in candidatos_sample
        valor = sum(roi[o, :])
        items = count(roi[o, :] .> 0)
        
        if valor > 0 && valor <= margen_disponible && items > 0
            densidad = valor / items
            eficiencia = valor / sqrt(items)
            
            # Score balanceado
            score = valor * 0.6 + densidad * 0.25 + eficiencia * 0.15
            push!(candidatos_balanceados, (o, valor, score))
        end
    end
    
    sort!(candidatos_balanceados, by=x -> x[3], rev=true)
    
    nuevas_ordenes = copy(ordenes_restantes)
    
    for (o, valor, score) in candidatos_balanceados
        if valor_actual + valor <= UB
            push!(nuevas_ordenes, o)
            valor_actual += valor
        end
    end
    
    if valor_actual >= LB && !isempty(nuevas_ordenes)
        nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
        return Solucion(nuevas_ordenes, nuevos_pasillos)
    end
    
    return nothing
end

# ========================================
# FUNCIONES AUXILIARES
# ========================================

"""
Criterio de aceptación más conservador para enormes
"""
function aceptar_solucion_enorme(valor_nuevo::Float64, mejor_valor::Float64, iter::Int, max_iter::Int, config::ConfigInstancia)
    if valor_nuevo > mejor_valor
        return true  # Siempre aceptar mejoras
    end
    
    # Simulated annealing más conservador para enormes
    progreso = iter / max_iter
    temperatura = 1.0 - progreso
    
    # Menos permisivo que otras categorías
    factor_permisividad = config.es_patologica ? 0.1 : 0.05
    
    if temperatura > 0.2  # Solo en fase inicial
        diferencia = mejor_valor - valor_nuevo
        # Solo permitir degradaciones muy pequeñas
        if diferencia / mejor_valor < 0.02  # Degradación < 2%
            probabilidad = exp(-diferencia / (mejor_valor * temperatura * factor_permisividad))
            return rand() < probabilidad
        end
    end
    
    return false
end

"""
Selección de operadores destroy/repair
"""
function seleccionar_destroy_operator(iter::Int, max_iter::Int)
    # Rotar entre operadores según iteración
    operators = [:random, :worst, :related]
    return operators[((iter - 1) % length(operators)) + 1]
end

function seleccionar_repair_operator(iter::Int, max_iter::Int)
    # Rotar entre operadores según iteración
    operators = [:greedy, :best_fit, :balanced]
    return operators[((iter - 1) % length(operators)) + 1]
end