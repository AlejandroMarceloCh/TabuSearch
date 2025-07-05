# ========================================
# PEQUENAS_VECINDARIOS.JL - TABU SEARCH EXHAUSTIVO
# Estrategia: Exploración completa controlada para UB pequeños
# Objetivo: Todas las instancias factibles, mejora garantizada
# ========================================

using Random

# ========================================
# GENERADOR PRINCIPAL DE VECINOS
# ========================================

"""
Genera vecinos exhaustivos pero controlados para instancias pequeñas
Estrategia adaptativa según tipo de patología
"""
function generar_vecinos_pequena(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_vecinos::Int=30)
    vecinos = Solucion[]
    
    # Estrategia según patología
    if :ratio_extremo in config.tipos_patologia && UB <= 5
        # Para UB extremos: vecindarios muy controlados
        append!(vecinos, intercambio_1_1_extremo(sol, roi, upi, LB, UB, config, Int(ceil(max_vecinos * 0.4))))
        append!(vecinos, agregar_quitar_extremo(sol, roi, upi, LB, UB, config, Int(ceil(max_vecinos * 0.3))))
        append!(vecinos, reoptimizar_pasillos_pequena(sol, roi, upi, LB, UB, config, Int(ceil(max_vecinos * 0.3))))
    else
        # Para casos normales: vecindarios completos
        append!(vecinos, intercambio_1_1_completo(sol, roi, upi, LB, UB, config, Int(ceil(max_vecinos * 0.4))))
        append!(vecinos, agregar_quitar_completo(sol, roi, upi, LB, UB, config, Int(ceil(max_vecinos * 0.3))))
        append!(vecinos, intercambio_pasillos_pequena(sol, roi, upi, LB, UB, config, Int(ceil(max_vecinos * 0.3))))
    end
    
    return filtrar_vecinos_pequena(vecinos, roi, upi, LB, UB, config, max_vecinos)
end

# ========================================
# VECINDARIOS PARA UB EXTREMOS
# ========================================

"""
Intercambio 1-1 controlado para UB muy pequeños
"""
function intercambio_1_1_extremo(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_vecinos::Int)
    vecinos = Solucion[]
    O = size(roi, 1)
    
    ordenes_actuales = collect(sol.ordenes)
    candidatos_externos = setdiff(1:O, sol.ordenes)
    
    if isempty(ordenes_actuales) || isempty(candidatos_externos)
        return vecinos
    end
    
    # Para UB extremos, ser muy selectivo
    println("   🔄 Intercambio 1-1 extremo: $(length(ordenes_actuales)) × $(length(candidatos_externos))")
    
    for o_out in ordenes_actuales
        valor_out = sum(roi[o_out, :])
        
        for o_in in candidatos_externos
            valor_in = sum(roi[o_in, :])
            
            # Calcular nuevo valor total
            valor_sin_out = sum(sum(roi[o, :]) for o in sol.ordenes if o != o_out)
            nuevo_valor_total = valor_sin_out + valor_in
            
            # Solo considerar si está en rango factible
            if LB <= nuevo_valor_total <= UB
                nuevas_ordenes = copy(sol.ordenes)
                delete!(nuevas_ordenes, o_out)
                push!(nuevas_ordenes, o_in)
                
                # Recalcular pasillos
                nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
                candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
                
                # Verificación exhaustiva obligatoria
                if es_factible(candidato, roi, upi, LB, UB, config)
                    push!(vecinos, candidato)
                    
                    if length(vecinos) >= max_vecinos
                        return vecinos
                    end
                end
            end
        end
    end
    
    return vecinos
end

"""
Agregar/quitar controlado para UB extremos
"""
function agregar_quitar_extremo(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_vecinos::Int)
    vecinos = Solucion[]
    O = size(roi, 1)
    
    valor_actual = sum(sum(roi[o, :]) for o in sol.ordenes)
    margen_disponible = UB - valor_actual
    
    println("   ➕ Agregar/quitar extremo: margen=$margen_disponible")
    
    # AGREGAR (solo si hay margen)
    if margen_disponible > 0
        candidatos_externos = setdiff(1:O, sol.ordenes)
        
        for o_nuevo in candidatos_externos
            valor_nuevo = sum(roi[o_nuevo, :])
            
            if valor_nuevo <= margen_disponible
                nuevas_ordenes = copy(sol.ordenes)
                push!(nuevas_ordenes, o_nuevo)
                
                nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
                candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
                
                if es_factible(candidato, roi, upi, LB, UB, config)
                    push!(vecinos, candidato)
                    
                    if length(vecinos) >= max_vecinos ÷ 2
                        break
                    end
                end
            end
        end
    end
    
    # QUITAR (solo si no rompe LB)
    ordenes_actuales = collect(sol.ordenes)
    for o_quitar in ordenes_actuales
        valor_quitar = sum(roi[o_quitar, :])
        nuevo_valor = valor_actual - valor_quitar
        
        if nuevo_valor >= LB && length(sol.ordenes) > 1
            nuevas_ordenes = setdiff(sol.ordenes, [o_quitar])
            
            nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
            candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
            
            if es_factible(candidato, roi, upi, LB, UB, config)
                push!(vecinos, candidato)
                
                if length(vecinos) >= max_vecinos
                    break
                end
            end
        end
    end
    
    return vecinos
end

# ========================================
# VECINDARIOS COMPLETOS PARA CASOS NORMALES
# ========================================

"""
Intercambio 1-1 completo para casos normales
"""
function intercambio_1_1_completo(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_vecinos::Int)
    vecinos = Solucion[]
    O = size(roi, 1)
    
    ordenes_actuales = collect(sol.ordenes)
    candidatos_externos = setdiff(1:O, sol.ordenes)
    
    if isempty(ordenes_actuales) || isempty(candidatos_externos)
        return vecinos
    end
    
    println("   🔄 Intercambio 1-1 completo: explorando $(length(ordenes_actuales)) × $(length(candidatos_externos))")
    
    # Evaluar todos los intercambios posibles
    for o_out in ordenes_actuales
        for o_in in candidatos_externos
            nuevas_ordenes = copy(sol.ordenes)
            delete!(nuevas_ordenes, o_out)
            push!(nuevas_ordenes, o_in)
            
            # Verificar límites básicos primero
            valor_total = sum(sum(roi[o, :]) for o in nuevas_ordenes)
            if LB <= valor_total <= UB
                # Recalcular pasillos
                nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
                candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
                
                if es_factible(candidato, roi, upi, LB, UB, config)
                    push!(vecinos, candidato)
                    
                    if length(vecinos) >= max_vecinos
                        return vecinos
                    end
                end
            end
        end
    end
    
    return vecinos
end

"""
Agregar/quitar completo para casos normales
"""
function agregar_quitar_completo(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_vecinos::Int)
    vecinos = Solucion[]
    O = size(roi, 1)
    
    valor_actual = sum(sum(roi[o, :]) for o in sol.ordenes)
    
    println("   ➕ Agregar/quitar completo: valor_actual=$valor_actual")
    
    # AGREGAR órdenes
    candidatos_externos = setdiff(1:O, sol.ordenes)
    for o_nuevo in candidatos_externos
        valor_nuevo = sum(roi[o_nuevo, :])
        
        if valor_actual + valor_nuevo <= UB
            nuevas_ordenes = copy(sol.ordenes)
            push!(nuevas_ordenes, o_nuevo)
            
            nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
            candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
            
            if es_factible(candidato, roi, upi, LB, UB, config)
                push!(vecinos, candidato)
                
                if length(vecinos) >= max_vecinos ÷ 2
                    break
                end
            end
        end
    end
    
    # QUITAR órdenes
    ordenes_actuales = collect(sol.ordenes)
    for o_quitar in ordenes_actuales
        if length(sol.ordenes) > 1  # No dejar solución vacía
            valor_quitar = sum(roi[o_quitar, :])
            nuevo_valor = valor_actual - valor_quitar
            
            if nuevo_valor >= LB
                nuevas_ordenes = setdiff(sol.ordenes, [o_quitar])
                
                nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
                candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
                
                if es_factible(candidato, roi, upi, LB, UB, config)
                    push!(vecinos, candidato)
                    
                    if length(vecinos) >= max_vecinos
                        break
                    end
                end
            end
        end
    end
    
    return vecinos
end

"""
Intercambio de pasillos para pequeñas
"""
function intercambio_pasillos_pequena(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_vecinos::Int)
    vecinos = Solucion[]
    P = size(upi, 1)
    
    if length(sol.pasillos) == 0
        return vecinos
    end
    
    println("   🚪 Intercambio pasillos: $(length(sol.pasillos)) actuales")
    
    pasillos_actuales = collect(sol.pasillos)
    candidatos_pasillos = setdiff(1:P, sol.pasillos)
    
    # Intercambio 1-1 de pasillos
    for p_out in pasillos_actuales
        for p_in in candidatos_pasillos
            nuevos_pasillos = copy(sol.pasillos)
            delete!(nuevos_pasillos, p_out)
            push!(nuevos_pasillos, p_in)
            
            candidato = Solucion(sol.ordenes, nuevos_pasillos)
            
            if es_factible(candidato, roi, upi, LB, UB, config)
                push!(vecinos, candidato)
                
                if length(vecinos) >= max_vecinos
                    return vecinos
                end
            end
        end
    end
    
    return vecinos
end

"""
Re-optimización de pasillos para pequeñas
"""
function reoptimizar_pasillos_pequena(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_vecinos::Int)
    vecinos = Solucion[]
    
    println("   ⚙️ Re-optimizando pasillos")
    
    # Recalcular pasillos óptimos para órdenes actuales
    pasillos_optimizados = calcular_pasillos_optimos(sol.ordenes, roi, upi, LB, UB, config)
    
    if pasillos_optimizados != sol.pasillos
        candidato = Solucion(sol.ordenes, pasillos_optimizados)
        
        if es_factible(candidato, roi, upi, LB, UB, config)
            push!(vecinos, candidato)
        end
    end
    
    # Intentar reducir número de pasillos (si es posible)
    if length(sol.pasillos) > 1
        for p_remover in sol.pasillos
            pasillos_reducidos = setdiff(sol.pasillos, [p_remover])
            candidato = Solucion(sol.ordenes, pasillos_reducidos)
            
            if es_factible(candidato, roi, upi, LB, UB, config)
                push!(vecinos, candidato)
                
                if length(vecinos) >= max_vecinos
                    break
                end
            end
        end
    end
    
    return vecinos
end

# ========================================
# FILTRADO Y OPTIMIZACIÓN DE VECINOS
# ========================================

"""
Filtra y optimiza vecinos para pequeñas
"""
function filtrar_vecinos_pequena(vecinos::Vector{Solucion}, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_vecinos::Int)
    if isempty(vecinos)
        return vecinos
    end
    
    println("   🔍 Filtrando $(length(vecinos)) vecinos candidatos")
    
    # Eliminar duplicados usando hash de órdenes
    vecinos_unicos = []
    hashes_vistos = Set{UInt64}()
    
    for vecino in vecinos
        if !isempty(vecino.ordenes) && !isempty(vecino.pasillos)
            # Hash basado en órdenes (más rápido que hash completo)
            hash_vecino = hash(sort(collect(vecino.ordenes)))
            
            if !(hash_vecino in hashes_vistos)
                push!(hashes_vistos, hash_vecino)
                
                # Verificación final de factibilidad
                if es_factible(vecino, roi, upi, LB, UB, config)
                    push!(vecinos_unicos, vecino)
                    
                    if length(vecinos_unicos) >= max_vecinos
                        break
                    end
                end
            end
        end
    end
    
    println("   ✅ $(length(vecinos_unicos)) vecinos únicos y factibles")
    
    return vecinos_unicos
end

# ========================================
# TABU SEARCH PRINCIPAL
# ========================================

"""
Tabu Search exhaustivo para instancias pequeñas
"""
function tabu_search_pequena(solucion_inicial::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia; semilla=nothing, mostrar_progreso=true)
    if semilla !== nothing
        Random.seed!(semilla)
    end
    
    if mostrar_progreso
        println("🔍 TABU SEARCH PEQUEÑA - EXHAUSTIVO CONTROLADO")
        println("⚙️ Parámetros: max_iter=$(config.max_iteraciones), tabu_size=$(config.tabu_size)")
        println("⏰ Timeout: $(config.timeout_adaptativo)s")
    end
    
    # Inicialización
    actual = solucion_inicial
    mejor = copiar_solucion(actual)
    mejor_valor = evaluar(mejor, roi)
    
    # Lista tabú (hash de soluciones)
    tabu_lista = Vector{UInt64}()
    
    # Contadores
    iteraciones_sin_mejora = 0
    iter = 0
    tiempo_inicio = time()
    
    if mostrar_progreso
        mostrar_solucion(mejor, roi, "INICIAL")
    end
    
    while iter < config.max_iteraciones && iteraciones_sin_mejora < 20
        iter += 1
        tiempo_transcurrido = time() - tiempo_inicio
        
        # Verificar timeout
        if tiempo_transcurrido > config.timeout_adaptativo
            if mostrar_progreso
                println("⏰ Timeout alcanzado ($(config.timeout_adaptativo)s)")
            end
            break
        end
        
        # Generar vecinos
        vecinos = generar_vecinos_pequena(actual, roi, upi, LB, UB, config, config.max_vecinos)
        
        if isempty(vecinos)
            if mostrar_progreso
                println("   ⚠️ Sin vecinos en iteración $iter")
            end
            break
        end
        
        # Buscar mejor vecino no tabú
        mejor_vecino = nothing
        mejor_valor_vecino = -Inf
        
        for vecino in vecinos
            hash_vecino = hash(sort(collect(vecino.ordenes)))
            
            if !(hash_vecino in tabu_lista)
                valor_vecino = evaluar(vecino, roi)
                if valor_vecino > mejor_valor_vecino
                    mejor_vecino = vecino
                    mejor_valor_vecino = valor_vecino
                end
            end
        end
        
        # Criterio de aspiración (para pequeñas: muy sensible)
        if mejor_vecino === nothing
            for vecino in vecinos
                valor_vecino = evaluar(vecino, roi)
                if valor_vecino > mejor_valor * 1.001  # 0.1% de mejora
                    mejor_vecino = vecino
                    mejor_valor_vecino = valor_vecino
                    if mostrar_progreso
                        println("   ⭐ Aspiración: ratio=$(round(valor_vecino, digits=3))")
                    end
                    break
                end
            end
        end
        
        if mejor_vecino === nothing
            if mostrar_progreso
                println("   ⚠️ Todos los vecinos son tabú en iteración $iter")
            end
            break
        end
        
        # Actualizar solución actual
        actual = mejor_vecino
        hash_actual = hash(sort(collect(actual.ordenes)))
        
        # Actualizar lista tabú
        push!(tabu_lista, hash_actual)
        if length(tabu_lista) > config.tabu_size
            popfirst!(tabu_lista)
        end
        
        # Verificar mejora global
        if mejor_valor_vecino > mejor_valor
            mejor = copiar_solucion(actual)
            mejor_valor = mejor_valor_vecino
            iteraciones_sin_mejora = 0
            
            if mostrar_progreso
                mostrar_solucion(mejor, roi, "NUEVO MEJOR ⭐")
            end
        else
            iteraciones_sin_mejora += 1
        end
        
        # Log cada 10 iteraciones
        if mostrar_progreso && iter % 10 == 0
            println("   📊 Iter $iter | Actual: $(round(mejor_valor_vecino, digits=3)) | " *
                   "Mejor: $(round(mejor_valor, digits=3)) | Sin mejora: $iteraciones_sin_mejora")
        end
    end
    
    tiempo_total = time() - tiempo_inicio
    
    if mostrar_progreso
        println("\n🎯 TABU SEARCH PEQUEÑA COMPLETADO")
        println("⏱️ Tiempo: $(round(tiempo_total, digits=2))s | Iteraciones: $iter")
        mostrar_solucion(mejor, roi, "RESULTADO FINAL")
    end
    
    return mejor, iter, tiempo_total
end