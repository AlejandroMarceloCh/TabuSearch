# solvers/medianas/medianas_vecindarios.jl
# ========================================
# GENERACIÓN DE VECINDARIOS PARA MEDIANAS
# INTEGRADOS - USA COMPLETAMENTE LA BASE CAMALEÓNICA
# ========================================

using Random

"""
Generador principal de vecinos para medianas
USA ConfigInstancia para determinar estrategia
"""
function generar_vecinos_mediana_inteligente(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    
    # Usar estrategia configurada automáticamente
    if config.estrategia_vecindarios == :vecindarios_inteligentes
        return generar_vecinos_inteligentes_mediana(sol, roi, upi, LB, UB, config)
    else
        # Fallback a vecindarios inteligentes
        return generar_vecinos_inteligentes_mediana(sol, roi, upi, LB, UB, config)
    end
end

"""
Vecindarios inteligentes para medianas usando ConfigInstancia
"""
function generar_vecinos_inteligentes_mediana(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    vecinos = Solucion[]
    max_vecinos = config.max_vecinos
    
    # Distribución inteligente para medianas CON EXPANSIÓN DE PASILLOS 🔥
    if config.es_patologica
        # Para patológicas: más conservador PERO con expansión
        append!(vecinos, intercambio_multiple_mediana(sol, roi, upi, LB, UB, config, Int(ceil(max_vecinos * 0.3))))
        append!(vecinos, agregar_quitar_inteligente_mediana(sol, roi, upi, LB, UB, config, Int(ceil(max_vecinos * 0.2))))
        append!(vecinos, expansion_pasillos_mediana(sol, roi, upi, LB, UB, config, Int(ceil(max_vecinos * 0.3))))  # 🔥 NUEVO
        append!(vecinos, reoptimizar_pasillos_mediana(sol, roi, upi, LB, UB, config, Int(ceil(max_vecinos * 0.2))))
    else
        # Para normales: más agresivo CON expansión
        append!(vecinos, intercambio_multiple_mediana(sol, roi, upi, LB, UB, config, Int(ceil(max_vecinos * 0.3))))
        append!(vecinos, agregar_quitar_inteligente_mediana(sol, roi, upi, LB, UB, config, Int(ceil(max_vecinos * 0.2))))
        append!(vecinos, expansion_pasillos_mediana(sol, roi, upi, LB, UB, config, Int(ceil(max_vecinos * 0.3))))  # 🔥 NUEVO
        append!(vecinos, busqueda_local_avanzada_mediana(sol, roi, upi, LB, UB, config, Int(ceil(max_vecinos * 0.2))))
    end
    
    return filtrar_vecinos_mediana(vecinos, roi, upi, LB, UB, config)
end

"""
Intercambio múltiple para medianas USANDO LA BASE
"""
function intercambio_multiple_mediana(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_vecinos::Int)
    vecinos = Solucion[]
    O = size(roi, 1)
    
    ordenes_actuales = collect(sol.ordenes)
    candidatos_externos = setdiff(1:O, sol.ordenes)
    
    if isempty(ordenes_actuales) || isempty(candidatos_externos)
        return vecinos
    end
    
    contador = 0
    
    # Intercambio 1-1 inteligente
    for o_out in ordenes_actuales
        valor_out = sum(roi[o_out, :])
        
        for o_in in candidatos_externos
            valor_in = sum(roi[o_in, :])
            
            # Pre-filtro por valor
            ordenes_restantes = [o for o in sol.ordenes if o != o_out]
            valor_sin_out = isempty(ordenes_restantes) ? 0 : sum(sum(roi[o, :]) for o in ordenes_restantes)
            nuevo_valor_total = valor_sin_out + valor_in
            
            if LB <= nuevo_valor_total <= UB
                nuevas_ordenes = copy(sol.ordenes)
                delete!(nuevas_ordenes, o_out)
                push!(nuevas_ordenes, o_in)
                
                # USAR BASE para calcular pasillos óptimos
                nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
                candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
                
                # USAR BASE para verificar factibilidad
                if es_factible(candidato, roi, upi, LB, UB, config)
                    push!(vecinos, candidato)
                    contador += 1
                    
                    if contador >= max_vecinos * 0.6  # 60% para intercambio 1-1
                        break
                    end
                end
            end
        end
        if contador >= max_vecinos * 0.6
            break
        end
    end
    
    # Intercambio 2-1 para medianas (más agresivo que pequeñas)
    if contador < max_vecinos && length(ordenes_actuales) >= 2
        for i in 1:min(5, length(ordenes_actuales)-1)  # Limitar búsqueda
            for j in (i+1):min(i+3, length(ordenes_actuales))  # Búsqueda local
                o_out1, o_out2 = ordenes_actuales[i], ordenes_actuales[j]
                valor_out = sum(roi[o_out1, :]) + sum(roi[o_out2, :])
                
                for o_in in candidatos_externos[1:min(10, length(candidatos_externos))]  # Top 10 candidatos
                    valor_in = sum(roi[o_in, :])
                    
                    ordenes_restantes = [o for o in sol.ordenes if o != o_out1 && o != o_out2]
                    valor_sin_outs = isempty(ordenes_restantes) ? 0 : sum(sum(roi[o, :]) for o in ordenes_restantes)
                    nuevo_valor_total = valor_sin_outs + valor_in
                    
                    if LB <= nuevo_valor_total <= UB
                        nuevas_ordenes = copy(sol.ordenes)
                        delete!(nuevas_ordenes, o_out1)
                        delete!(nuevas_ordenes, o_out2)
                        push!(nuevas_ordenes, o_in)
                        
                        # USAR BASE
                        nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
                        candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
                        
                        if es_factible(candidato, roi, upi, LB, UB, config)
                            push!(vecinos, candidato)
                            contador += 1
                            
                            if contador >= max_vecinos
                                return vecinos
                            end
                        end
                    end
                end
            end
        end
    end
    
    return vecinos
end

"""
Agregar/quitar inteligente para medianas USANDO LA BASE
"""
function agregar_quitar_inteligente_mediana(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_vecinos::Int)
    vecinos = Solucion[]
    O = size(roi, 1)
    
    valor_actual = sum(sum(roi[o, :]) for o in sol.ordenes)
    margen_disponible = UB - valor_actual
    
    contador = 0
    
    # AGREGAR órdenes con criterio inteligente
    if margen_disponible > 0
        candidatos_externos = setdiff(1:O, sol.ordenes)
        
        # Evaluar candidatos por eficiencia
        candidatos_evaluados = []
        for o_nuevo in candidatos_externos
            valor_nuevo = sum(roi[o_nuevo, :])
            items = count(roi[o_nuevo, :] .> 0)
            eficiencia = items > 0 ? valor_nuevo / items : 0
            
            if valor_nuevo <= margen_disponible
                push!(candidatos_evaluados, (o_nuevo, valor_nuevo, eficiencia))
            end
        end
        
        # Ordenar por eficiencia y probar mejores
        if !isempty(candidatos_evaluados)
            sort!(candidatos_evaluados, by=x -> x[3], rev=true)
            
            for (o_nuevo, valor_nuevo, eficiencia) in candidatos_evaluados[1:min(15, length(candidatos_evaluados))]
                nuevas_ordenes = copy(sol.ordenes)
                push!(nuevas_ordenes, o_nuevo)
                
                # USAR BASE
                nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
                candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
                
                if es_factible(candidato, roi, upi, LB, UB, config)
                    push!(vecinos, candidato)
                    contador += 1
                    
                    if contador >= max_vecinos ÷ 2
                        break
                    end
                end
            end
        end
    end
    
    # QUITAR órdenes con criterio inteligente
    ordenes_actuales = collect(sol.ordenes)
    
    # Evaluar órdenes por eficiencia (quitar las menos eficientes)
    ordenes_evaluadas = []
    for o_quitar in ordenes_actuales
        valor_quitar = sum(roi[o_quitar, :])
        items = count(roi[o_quitar, :] .> 0)
        eficiencia = items > 0 ? valor_quitar / items : 0
        push!(ordenes_evaluadas, (o_quitar, valor_quitar, eficiencia))
    end
    
    # Ordenar por eficiencia ascendente (peores primero)
    if !isempty(ordenes_evaluadas)
        sort!(ordenes_evaluadas, by=x -> x[3])
        
        for (o_quitar, valor_quitar, eficiencia) in ordenes_evaluadas[1:min(5, length(ordenes_evaluadas))]
            if length(sol.ordenes) > 1  # No dejar solución vacía
                nuevo_valor = valor_actual - valor_quitar
                
                if nuevo_valor >= LB
                    nuevas_ordenes = setdiff(sol.ordenes, [o_quitar])
                    
                    # USAR BASE
                    nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
                    candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
                    
                    if es_factible(candidato, roi, upi, LB, UB, config)
                        push!(vecinos, candidato)
                        contador += 1
                        
                        if contador >= max_vecinos
                            break
                        end
                    end
                end
            end
        end
    end
    
    return vecinos
end

"""
Búsqueda local avanzada para medianas USANDO LA BASE
"""
function busqueda_local_avanzada_mediana(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_vecinos::Int)
    vecinos = Solucion[]
    P = size(upi, 1)
    
    contador = 0
    
    # 1. Re-optimización de pasillos
    pasillos_optimizados = calcular_pasillos_optimos(sol.ordenes, roi, upi, LB, UB, config)  # USAR BASE
    if pasillos_optimizados != sol.pasillos
        candidato = Solucion(sol.ordenes, pasillos_optimizados)
        if es_factible(candidato, roi, upi, LB, UB, config)  # USAR BASE
            push!(vecinos, candidato)
            contador += 1
        end
    end
    
    # 2. Intercambio inteligente de pasillos
    pasillos_actuales = collect(sol.pasillos)
    candidatos_pasillos = setdiff(1:P, sol.pasillos)
    
    # Evaluar pasillos por capacidad total
    pasillos_evaluados = [(p, sum(upi[p, :])) for p in candidatos_pasillos]
    if !isempty(pasillos_evaluados)
        sort!(pasillos_evaluados, by=x -> x[2], rev=true)
        
        for p_out in pasillos_actuales[1:min(3, length(pasillos_actuales))]  # Top 3 actuales
            for (p_in, capacidad) in pasillos_evaluados[1:min(5, length(pasillos_evaluados))]  # Top 5 candidatos
                nuevos_pasillos = copy(sol.pasillos)
                delete!(nuevos_pasillos, p_out)
                push!(nuevos_pasillos, p_in)
                
                candidato = Solucion(sol.ordenes, nuevos_pasillos)
                if es_factible(candidato, roi, upi, LB, UB, config)  # USAR BASE
                    push!(vecinos, candidato)
                    contador += 1
                    
                    if contador >= max_vecinos
                        return vecinos
                    end
                end
            end
        end
    end
    
    # 3. Reducción inteligente de pasillos
    if length(sol.pasillos) > 2
        # Evaluar pasillos por utilización
        utilizaciones = []
        for p in sol.pasillos
            utilizacion = 0
            for o in sol.ordenes
                for i in 1:size(roi, 2)
                    if roi[o, i] > 0
                        utilizacion += min(upi[p, i], roi[o, i])
                    end
                end
            end
            push!(utilizaciones, (p, utilizacion))
        end
        
        # Intentar remover pasillos menos utilizados
        if !isempty(utilizaciones)
            sort!(utilizaciones, by=x -> x[2])
            
            for (p_remover, utilizacion) in utilizaciones[1:min(2, length(utilizaciones))]
                pasillos_reducidos = setdiff(sol.pasillos, [p_remover])
                candidato = Solucion(sol.ordenes, pasillos_reducidos)
                
                if es_factible(candidato, roi, upi, LB, UB, config)  # USAR BASE
                    push!(vecinos, candidato)
                    contador += 1
                    
                    if contador >= max_vecinos
                        break
                    end
                end
            end
        end
    end
    
    return vecinos
end

"""
Re-optimización de pasillos para medianas USANDO LA BASE
"""
function reoptimizar_pasillos_mediana(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_vecinos::Int)
    vecinos = Solucion[]
    
    # USAR BASE para recalcular pasillos óptimos
    pasillos_optimizados = calcular_pasillos_optimos(sol.ordenes, roi, upi, LB, UB, config)
    
    if pasillos_optimizados != sol.pasillos
        candidato = Solucion(sol.ordenes, pasillos_optimizados)
        
        # USAR BASE para verificar factibilidad
        if es_factible(candidato, roi, upi, LB, UB, config)
            push!(vecinos, candidato)
        end
    end
    
    return vecinos
end

"""
Filtra vecinos eliminando duplicados y verificando factibilidad USANDO LA BASE
"""
function filtrar_vecinos_mediana(vecinos::Vector{Solucion}, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    if isempty(vecinos)
        return vecinos
    end
    
    # Eliminar duplicados usando hash de órdenes
    vecinos_unicos = []
    hashes_vistos = Set{UInt64}()
    
    for vecino in vecinos
        if !isempty(vecino.ordenes) && !isempty(vecino.pasillos)
            # Hash basado en órdenes para detectar duplicados
            ordenes_sorted = collect(vecino.ordenes)
            if !isempty(ordenes_sorted)
                hash_vecino = hash(sort(ordenes_sorted))
                
                if !(hash_vecino in hashes_vistos)
                    push!(hashes_vistos, hash_vecino)
                    
                    # Verificación final de factibilidad USANDO LA BASE
                    if es_factible(vecino, roi, upi, LB, UB, config)
                        push!(vecinos_unicos, vecino)
                        
                        # Limitar según configuración
                        if length(vecinos_unicos) >= config.max_vecinos
                            break
                        end
                    end
                end
            end
        end
    end
    
    return vecinos_unicos
end

# ========================================
# 🔥🔥🔥 EXPANSIÓN DE PASILLOS - CLAVE PARA ESCAPAR ÓPTIMO LOCAL 🔥🔥🔥
# ========================================

"""
NUEVA FUNCIÓN: Expansión de pasillos para escapar de óptimos locales
ESTO ES LO QUE FALTABA - EXPLORAR CON MÁS PASILLOS PARA ÓRDENES DE ALTO VALOR
"""
function expansion_pasillos_mediana(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_vecinos::Int)
    vecinos = Solucion[]
    O = size(roi, 1)
    P = size(upi, 1)
    
    println("         🔥 EXPANSIÓN DE PASILLOS: Buscando órdenes de alto valor...")
    
    # Encontrar órdenes NO seleccionadas con ALTO VALOR
    ordenes_disponibles = setdiff(1:O, sol.ordenes)
    ordenes_alto_valor = []
    
    for o in ordenes_disponibles
        valor_o = sum(roi[o, :])
        if valor_o >= 8  # Solo órdenes valiosas
            push!(ordenes_alto_valor, (o, valor_o))
        end
    end
    
    # Ordenar por valor descendente
    sort!(ordenes_alto_valor, by=x -> x[2], rev=true)
    
    if !isempty(ordenes_alto_valor)
        println("         📈 Órdenes alto valor encontradas: $(length(ordenes_alto_valor))")
        println("         🏆 Top 3: $(ordenes_alto_valor[1:min(3, end)])")
    end
    
    unidades_actuales = sum(sum(roi[o, :]) for o in sol.ordenes)
    contador = 0
    
    # Para cada orden de alto valor, intentar EXPANDIR PASILLOS
    for (orden_target, valor_target) in ordenes_alto_valor[1:min(8, length(ordenes_alto_valor))]
        
        if unidades_actuales + valor_target <= UB
            println("         🔍 Analizando orden $orden_target (valor=$valor_target)...")
            
            # Encontrar pasillos ADICIONALES necesarios para esta orden
            pasillos_nuevos_necesarios = Set{Int}()
            
            for i in 1:size(roi, 2)
                demanda = roi[orden_target, i]
                if demanda > 0
                    # Verificar si pasillos actuales pueden satisfacer
                    puede_satisfacer = false
                    for p in sol.pasillos
                        if upi[p, i] >= demanda
                            puede_satisfacer = true
                            break
                        end
                    end
                    
                    # Si no puede satisfacer, buscar nuevo pasillo
                    if !puede_satisfacer
                        mejor_pasillo_nuevo = 0
                        mejor_capacidad = 0
                        
                        for p in 1:P
                            if p ∉ sol.pasillos && upi[p, i] >= demanda && upi[p, i] > mejor_capacidad
                                mejor_pasillo_nuevo = p
                                mejor_capacidad = upi[p, i]
                            end
                        end
                        
                        if mejor_pasillo_nuevo > 0
                            push!(pasillos_nuevos_necesarios, mejor_pasillo_nuevo)
                        end
                    end
                end
            end
            
            # Si necesitamos pasillos nuevos, crear vecino EXPANDIDO
            if !isempty(pasillos_nuevos_necesarios)
                pasillos_expandidos = union(sol.pasillos, pasillos_nuevos_necesarios)
                
                println("           🚪 Pasillos actuales: $(length(sol.pasillos)), expandidos: $(length(pasillos_expandidos))")
                
                # Ser permisivo en expansión - hasta +4 pasillos
                if length(pasillos_expandidos) <= length(sol.pasillos) + 4
                    
                    # VECINO 1: Solo agregar la orden target
                    ordenes_expandidas = copy(sol.ordenes)
                    push!(ordenes_expandidas, orden_target)
                    
                    vecino_simple = Solucion(ordenes_expandidas, pasillos_expandidos)
                    
                    if es_factible(vecino_simple, roi, upi, LB, UB, config)
                        push!(vecinos, vecino_simple)
                        contador += 1
                        
                        ratio_vecino = evaluar(vecino_simple, roi)
                        println("           ✅ Vecino simple: +$(length(pasillos_nuevos_necesarios)) pasillos, ratio=$(round(ratio_vecino, digits=3))")
                        
                        if contador >= max_vecinos ÷ 2
                            return vecinos
                        end
                    end
                    
                    # VECINO 2: Agregar orden target + otras compatibles (GREEDY EXPANSION)
                    ordenes_extra_compatibles = []
                    
                    for o_extra in ordenes_disponibles
                        if o_extra != orden_target
                            valor_extra = sum(roi[o_extra, :])
                            if unidades_actuales + valor_target + valor_extra <= UB
                                # Verificar compatibilidad con pasillos expandidos
                                if verificar_compatibilidad_pasillos(o_extra, pasillos_expandidos, roi, upi)
                                    push!(ordenes_extra_compatibles, (o_extra, valor_extra))
                                end
                            end
                        end
                    end
                    
                    # Ordenar compatibles por valor
                    sort!(ordenes_extra_compatibles, by=x -> x[2], rev=true)
                    
                    if !isempty(ordenes_extra_compatibles)
                        println("           🎯 Órdenes extra compatibles: $(length(ordenes_extra_compatibles))")
                        
                        # Crear vecino con 1-2 órdenes extra
                        for num_extra in 1:min(2, length(ordenes_extra_compatibles))
                            ordenes_mega_expandidas = copy(ordenes_expandidas)
                            unidades_test = unidades_actuales + valor_target
                            
                            for i in 1:num_extra
                                o_extra, valor_extra = ordenes_extra_compatibles[i]
                                if unidades_test + valor_extra <= UB
                                    push!(ordenes_mega_expandidas, o_extra)
                                    unidades_test += valor_extra
                                end
                            end
                            
                            if length(ordenes_mega_expandidas) > length(ordenes_expandidas)
                                vecino_mega = Solucion(ordenes_mega_expandidas, pasillos_expandidos)
                                
                                if es_factible(vecino_mega, roi, upi, LB, UB, config)
                                    push!(vecinos, vecino_mega)
                                    contador += 1
                                    
                                    ratio_mega = evaluar(vecino_mega, roi)
                                    println("           🚀 Vecino mega: +$(length(ordenes_mega_expandidas) - length(sol.ordenes)) órdenes, ratio=$(round(ratio_mega, digits=3))")
                                    
                                    if contador >= max_vecinos
                                        return vecinos
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    println("         🏁 Expansión completada: $(contador) vecinos generados")
    return vecinos
end