# ========================================
# PEQUENAS_CONSTRUCTIVAS.JL - SOLUCIONES INICIALES ROBUSTAS
# Estrategia: Múltiples enfoques para UB extremos (2-40)
# Instancias objetivo: 2, 4, 20 (67% patológicas)
# ========================================

using Random

# ========================================
# GENERADOR PRINCIPAL DE SOLUCIONES INICIALES
# ========================================

"""
Genera solución inicial robusta para instancias pequeñas
Estrategia adaptativa según tipo de patología detectada
"""
function generar_solucion_inicial_pequena(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia; semilla=nothing)
    if semilla !== nothing
        Random.seed!(semilla)
    end
    
    println("🔬 Generando solución inicial PEQUEÑA...")
    println("   🎯 Instancia: $(config.ordenes) órdenes, UB=$UB")
    
    # Estrategia según tipo de patología
    if :ratio_extremo in config.tipos_patologia && UB <= 5
        println("   🎯 Estrategia: Enumeración para UB extremo ($UB)")
        return enumeracion_ub_extremo(roi, upi, LB, UB, config)
    elseif :pocos_pasillos_necesarios in config.tipos_patologia
        println("   🎯 Estrategia: Múltiples greedy para sobredimensionamiento")
        return multiples_greedy_sobredimensionado(roi, upi, LB, UB, config)
    else
        println("   🎯 Estrategia: Múltiples greedy estándar")
        return multiples_greedy_estandar(roi, upi, LB, UB, config)
    end
end

# ========================================
# ENUMERACIÓN PARA UB EXTREMO (Instancia 2: UB=2)
# ========================================

"""
Enumeración inteligente para UB muy pequeños (≤5)
Explora todas las combinaciones factibles
"""
function enumeracion_ub_extremo(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    O = size(roi, 1)
    
    println("   ⚡ Enumeración exhaustiva para UB=$UB")
    
    mejor_solucion = nothing
    mejor_ratio = 0.0
    
    # 1. ÓRDENES INDIVIDUALES
    println("   📝 Evaluando órdenes individuales...")
    for o in 1:O
        valor = sum(roi[o, :])
        if LB <= valor <= UB
            ordenes = Set([o])
            pasillos = calcular_pasillos_optimos(ordenes, roi, upi, LB, UB, config)
            
            candidato = Solucion(ordenes, pasillos)
            if es_factible(candidato, roi, upi, LB, UB, config)
                ratio = evaluar(candidato, roi)
                if ratio > mejor_ratio
                    mejor_solucion = candidato
                    mejor_ratio = ratio
                    println("   ✅ Orden $o individual: ratio=$(round(ratio, digits=3))")
                end
            end
        end
    end
    
    # 2. COMBINACIONES DE 2 ÓRDENES (si UB permite)
    if UB >= 2
        println("   📝 Evaluando combinaciones de 2 órdenes...")
        contador = 0
        for i in 1:O
            for j in (i+1):O
                valor_total = sum(roi[i, :]) + sum(roi[j, :])
                if LB <= valor_total <= UB
                    ordenes = Set([i, j])
                    pasillos = calcular_pasillos_optimos(ordenes, roi, upi, LB, UB, config)
                    
                    candidato = Solucion(ordenes, pasillos)
                    if es_factible(candidato, roi, upi, LB, UB, config)
                        ratio = evaluar(candidato, roi)
                        if ratio > mejor_ratio
                            mejor_solucion = candidato
                            mejor_ratio = ratio
                            println("   ✅ Combo [$i,$j]: ratio=$(round(ratio, digits=3))")
                        end
                    end
                    
                    contador += 1
                    if contador >= 20  # Límite de seguridad
                        break
                    end
                end
            end
            if contador >= 20
                break
            end
        end
    end
    
    # 3. COMBINACIONES DE 3 ÓRDENES (si UB permite y hay pocas órdenes)
    if UB >= 3 && O <= 10
        println("   📝 Evaluando combinaciones de 3 órdenes...")
        contador = 0
        for i in 1:O
            for j in (i+1):O
                for k in (j+1):O
                    valor_total = sum(roi[i, :]) + sum(roi[j, :]) + sum(roi[k, :])
                    if LB <= valor_total <= UB
                        ordenes = Set([i, j, k])
                        pasillos = calcular_pasillos_optimos(ordenes, roi, upi, LB, UB, config)
                        
                        candidato = Solucion(ordenes, pasillos)
                        if es_factible(candidato, roi, upi, LB, UB, config)
                            ratio = evaluar(candidato, roi)
                            if ratio > mejor_ratio
                                mejor_solucion = candidato
                                mejor_ratio = ratio
                                println("   ✅ Combo [$i,$j,$k]: ratio=$(round(ratio, digits=3))")
                            end
                        end
                        
                        contador += 1
                        if contador >= 10  # Límite más estricto para 3
                            break
                        end
                    end
                end
                if contador >= 10
                    break
                end
            end
            if contador >= 10
                break
            end
        end
    end
    
    return mejor_solucion
end

# ========================================
# MÚLTIPLES GREEDY PARA SOBREDIMENSIONAMIENTO
# ========================================

"""
Múltiples estrategias greedy para casos con muchos pasillos vs pocos necesarios
"""
function multiples_greedy_sobredimensionado(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    println("   🔄 Ejecutando múltiples greedy para sobredimensionamiento...")
    
    mejor_solucion = nothing
    mejor_ratio = 0.0
    
    # Estrategias específicas para sobredimensionamiento
    estrategias = [
        (:valor_puro, "Greedy por valor puro"),
        (:eficiencia_items, "Greedy por eficiencia (valor/items)"),
        (:densidad_optimizada, "Greedy por densidad (valor/√items)"),
        (:objetivo_90pct, "Objetivo 90% del UB"),
        (:objetivo_95pct, "Objetivo 95% del UB")
    ]
    
    for (estrategia, descripcion) in estrategias
        candidato = aplicar_estrategia_greedy_pequena(roi, upi, LB, UB, config, estrategia)
        
        if candidato !== nothing && es_factible(candidato, roi, upi, LB, UB, config)
            ratio = evaluar(candidato, roi)
            if ratio > mejor_ratio
                mejor_solucion = candidato
                mejor_ratio = ratio
                println("   ✅ $descripcion: ratio=$(round(ratio, digits=3))")
            end
        end
    end
    
    return mejor_solucion
end

# ========================================
# MÚLTIPLES GREEDY ESTÁNDAR
# ========================================

"""
Múltiples estrategias greedy para casos normales
"""
function multiples_greedy_estandar(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    println("   🔄 Ejecutando múltiples greedy estándar...")
    
    mejor_solucion = nothing
    mejor_ratio = 0.0
    
    estrategias = [
        (:valor_puro, "Greedy por valor puro"),
        (:eficiencia_items, "Greedy por eficiencia"),
        (:balanceado, "Greedy balanceado (70% valor + 30% eficiencia)"),
        (:objetivo_dinamico, "Objetivo dinámico")
    ]
    
    for (estrategia, descripcion) in estrategias
        candidato = aplicar_estrategia_greedy_pequena(roi, upi, LB, UB, config, estrategia)
        
        if candidato !== nothing && es_factible(candidato, roi, upi, LB, UB, config)
            ratio = evaluar(candidato, roi)
            if ratio > mejor_ratio
                mejor_solucion = candidato
                mejor_ratio = ratio
                println("   ✅ $descripcion: ratio=$(round(ratio, digits=3))")
            end
        end
    end
    
    return mejor_solucion
end

# ========================================
# IMPLEMENTACIÓN DE ESTRATEGIAS GREEDY
# ========================================

"""
Aplica una estrategia greedy específica
"""
function aplicar_estrategia_greedy_pequena(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, estrategia::Symbol)
    O = size(roi, 1)
    
    if estrategia == :valor_puro
        return greedy_valor_puro_pequena(roi, upi, LB, UB, config)
    elseif estrategia == :eficiencia_items
        return greedy_eficiencia_pequena(roi, upi, LB, UB, config)
    elseif estrategia == :densidad_optimizada
        return greedy_densidad_pequena(roi, upi, LB, UB, config)
    elseif estrategia == :balanceado
        return greedy_balanceado_pequena(roi, upi, LB, UB, config)
    elseif estrategia == :objetivo_90pct
        return greedy_objetivo_porcentaje_pequena(roi, upi, LB, UB, config, 0.90)
    elseif estrategia == :objetivo_95pct
        return greedy_objetivo_porcentaje_pequena(roi, upi, LB, UB, config, 0.95)
    elseif estrategia == :objetivo_dinamico
        return greedy_objetivo_dinamico_pequena(roi, upi, LB, UB, config)
    end
    
    return nothing
end

"""
Greedy por valor puro
"""
function greedy_valor_puro_pequena(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    O = size(roi, 1)
    
    # Ordenar por valor descendente
    valores = [(o, sum(roi[o, :])) for o in 1:O]
    sort!(valores, by=x -> x[2], rev=true)
    
    ordenes_seleccionadas = Set{Int}()
    valor_actual = 0
    
    for (o, valor) in valores
        if valor_actual + valor <= UB
            push!(ordenes_seleccionadas, o)
            valor_actual += valor
        end
    end
    
    if LB <= valor_actual <= UB && !isempty(ordenes_seleccionadas)
        pasillos = calcular_pasillos_optimos(ordenes_seleccionadas, roi, upi, LB, UB, config)
        return Solucion(ordenes_seleccionadas, pasillos)
    end
    
    return nothing
end

"""
Greedy por eficiencia (valor/items)
"""
function greedy_eficiencia_pequena(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    O = size(roi, 1)
    
    # Calcular eficiencias
    eficiencias = []
    for o in 1:O
        valor = sum(roi[o, :])
        items = count(roi[o, :] .> 0)
        eficiencia = items > 0 ? valor / items : 0
        push!(eficiencias, (o, valor, eficiencia))
    end
    
    sort!(eficiencias, by=x -> x[3], rev=true)
    
    ordenes_seleccionadas = Set{Int}()
    valor_actual = 0
    
    for (o, valor, eficiencia) in eficiencias
        if valor_actual + valor <= UB
            push!(ordenes_seleccionadas, o)
            valor_actual += valor
        end
    end
    
    if LB <= valor_actual <= UB && !isempty(ordenes_seleccionadas)
        pasillos = calcular_pasillos_optimos(ordenes_seleccionadas, roi, upi, LB, UB, config)
        return Solucion(ordenes_seleccionadas, pasillos)
    end
    
    return nothing
end

"""
Greedy por densidad (valor/√items)
"""
function greedy_densidad_pequena(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    O = size(roi, 1)
    
    # Calcular densidades
    densidades = []
    for o in 1:O
        valor = sum(roi[o, :])
        items = count(roi[o, :] .> 0)
        densidad = items > 0 ? valor / sqrt(items) : 0
        push!(densidades, (o, valor, densidad))
    end
    
    sort!(densidades, by=x -> x[3], rev=true)
    
    ordenes_seleccionadas = Set{Int}()
    valor_actual = 0
    
    for (o, valor, densidad) in densidades
        if valor_actual + valor <= UB
            push!(ordenes_seleccionadas, o)
            valor_actual += valor
        end
    end
    
    if LB <= valor_actual <= UB && !isempty(ordenes_seleccionadas)
        pasillos = calcular_pasillos_optimos(ordenes_seleccionadas, roi, upi, LB, UB, config)
        return Solucion(ordenes_seleccionadas, pasillos)
    end
    
    return nothing
end

"""
Greedy balanceado (70% valor + 30% eficiencia)
"""
function greedy_balanceado_pequena(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    O = size(roi, 1)
    
    # Calcular scores balanceados
    scores = []
    valores_norm = []
    eficiencias_norm = []
    
    # Normalizar valores y eficiencias
    for o in 1:O
        valor = sum(roi[o, :])
        items = count(roi[o, :] .> 0)
        eficiencia = items > 0 ? valor / items : 0
        push!(valores_norm, valor)
        push!(eficiencias_norm, eficiencia)
    end
    
    max_valor = maximum(valores_norm)
    max_eficiencia = maximum(eficiencias_norm)
    
    for o in 1:O
        valor_norm = max_valor > 0 ? valores_norm[o] / max_valor : 0
        eficiencia_norm = max_eficiencia > 0 ? eficiencias_norm[o] / max_eficiencia : 0
        
        score = valor_norm * 0.7 + eficiencia_norm * 0.3
        push!(scores, (o, valores_norm[o], score))
    end
    
    sort!(scores, by=x -> x[3], rev=true)
    
    ordenes_seleccionadas = Set{Int}()
    valor_actual = 0
    
    for (o, valor, score) in scores
        if valor_actual + valor <= UB
            push!(ordenes_seleccionadas, o)
            valor_actual += valor
        end
    end
    
    if LB <= valor_actual <= UB && !isempty(ordenes_seleccionadas)
        pasillos = calcular_pasillos_optimos(ordenes_seleccionadas, roi, upi, LB, UB, config)
        return Solucion(ordenes_seleccionadas, pasillos)
    end
    
    return nothing
end

"""
Greedy con objetivo de porcentaje específico del UB
"""
function greedy_objetivo_porcentaje_pequena(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, porcentaje::Float64)
    O = size(roi, 1)
    target_valor = UB * porcentaje
    
    valores = [(o, sum(roi[o, :])) for o in 1:O]
    sort!(valores, by=x -> x[2], rev=true)
    
    ordenes_seleccionadas = Set{Int}()
    valor_actual = 0
    
    for (o, valor) in valores
        if valor_actual + valor <= UB
            # Decidir basado en cercanía al objetivo
            distancia_actual = abs(valor_actual - target_valor)
            distancia_nueva = abs(valor_actual + valor - target_valor)
            
            if distancia_nueva <= distancia_actual || valor_actual < target_valor * 0.8
                push!(ordenes_seleccionadas, o)
                valor_actual += valor
            end
        end
    end
    
    if LB <= valor_actual <= UB && !isempty(ordenes_seleccionadas)
        pasillos = calcular_pasillos_optimos(ordenes_seleccionadas, roi, upi, LB, UB, config)
        return Solucion(ordenes_seleccionadas, pasillos)
    end
    
    return nothing
end

"""
Greedy con objetivo dinámico (adapta target según progreso)
"""
function greedy_objetivo_dinamico_pequena(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    O = size(roi, 1)
    
    valores = [(o, sum(roi[o, :])) for o in 1:O]
    sort!(valores, by=x -> x[2], rev=true)
    
    ordenes_seleccionadas = Set{Int}()
    valor_actual = 0
    
    # Target dinámico: empieza en 85% y sube según disponibilidad
    target_inicial = UB * 0.85
    
    for (o, valor) in valores
        if valor_actual + valor <= UB
            # Ajustar target dinámicamente
            progreso = valor_actual / UB
            target_actual = if progreso < 0.5
                target_inicial
            elseif progreso < 0.8
                UB * 0.90
            else
                UB * 0.98
            end
            
            if valor_actual < target_actual || 
               abs(valor_actual + valor - target_actual) <= abs(valor_actual - target_actual)
                push!(ordenes_seleccionadas, o)
                valor_actual += valor
            end
        end
    end
    
    if LB <= valor_actual <= UB && !isempty(ordenes_seleccionadas)
        pasillos = calcular_pasillos_optimos(ordenes_seleccionadas, roi, upi, LB, UB, config)
        return Solucion(ordenes_seleccionadas, pasillos)
    end
    
    return nothing
end