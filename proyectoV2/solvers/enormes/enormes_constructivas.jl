# solvers/enormes/enormes_constructivas.jl
# ========================================
# CONSTRUCTIVAS ULTRA-ESCALABLES PARA ENORMES
# OBJETIVO: MANEJAR 12,000+ ÓRDENES CON SAMPLING INTELIGENTE
# ========================================

using Random
using StatsBase: sample
using Statistics

# ========================================
# CONSTRUCTIVA PRINCIPAL - SAMPLING MASIVO
# ========================================

"""
🎯 CONSTRUCTIVA PRINCIPAL PARA ENORMES
ESTRATEGIA: Sampling inteligente + clustering + construcción escalable
Solo evaluar 5-10% de órdenes para mantener escalabilidad
"""
function generar_solucion_inicial_enorme(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia; semilla=nothing)
    if semilla !== nothing
        Random.seed!(semilla)
    end
    
    println("⚡ CONSTRUCTIVA ENORME - SAMPLING MASIVO")
    println("   📊 Instancia: $(config.ordenes) órdenes, $(config.items) ítems, $(config.pasillos) pasillos")
    println("   🎯 Objetivo: Maximizar unidades/pasillos con escalabilidad extrema")
    println("   📈 UB Objetivo: $UB (Margen alto para aprovechar)")
    
    O, I = size(roi)
    P = size(upi, 1)
    
    # TAMAÑO DE SAMPLING ULTRA-AGRESIVO PARA RATIO MÁXIMO
    sampling_rate = if config.es_patologica
        min(0.50, max(0.30, 1500 / O))  # 30-50% para patológicas
    else
        min(0.40, max(0.25, 1000 / O))  # 25-40% para normales - MUCHO MÁS AGRESIVO
    end
    
    n_sample = max(500, min(4000, Int(ceil(O * sampling_rate))))
    
    println("   🎲 Sampling rate: $(round(sampling_rate*100, digits=1))% ($(n_sample) órdenes)")
    
    # BANCO DE ESTRATEGIAS ESCALABLES - VERSIÓN ULTRA-AGRESIVA
    estrategias = [
        (:sampling_ultra_ratio_hunter, "🔥 ULTRA RATIO HUNTER + sampling"),
        (:sampling_ratio_agresivo, "🚀 Ratio agresivo + sampling"),
        (:sampling_pasillos_minimos, "⚡ Pasillos mínimos + sampling"),
        (:sampling_elite_orders, "👑 Órdenes elite + sampling"),
        (:sampling_cluster_valor, "🎯 Clustering por valor + sampling"),
        (:sampling_densidad_extrema, "📊 Densidad extrema + sampling"),
        (:sampling_pasillos_dominantes, "🚪 Pasillos dominantes + sampling"),
        (:sampling_greedy_ub, "💰 Greedy UB + sampling"),
        (:sampling_hibrido_balanceado, "⚖️ Híbrido balanceado + sampling")
    ]
    
    mejor_solucion = nothing
    mejor_ratio = 0.0
    
    for (estrategia, descripcion) in estrategias
        try
            candidato = ejecutar_estrategia_enorme(roi, upi, LB, UB, config, estrategia, n_sample)
            
            if candidato !== nothing && es_factible(candidato, roi, upi, LB, UB, config)
                ratio = evaluar(candidato, roi)
                if ratio > mejor_ratio
                    mejor_solucion = candidato
                    mejor_ratio = ratio
                    println("   ✅ $descripcion: ratio=$(round(ratio, digits=3))")
                else
                    println("   📊 $descripcion: ratio=$(round(ratio, digits=3))")
                end
            else
                println("   ❌ $descripcion: falló")
            end
        catch e
            println("   ⚠️ $descripcion: error $e")
        end
    end
    
    if mejor_solucion === nothing
        println("   🔧 Aplicando constructiva de emergencia escalable...")
        mejor_solucion = constructiva_emergencia_enorme(roi, upi, LB, UB, config, n_sample)
    end
    
    return mejor_solucion
end

# ========================================
# ESTRATEGIA ULTRA-AGRESIVA: RATIO HUNTER
# ========================================

"""
ESTRATEGIA NUEVA: ULTRA RATIO HUNTER - Búsqueda exhaustiva de ratio máximo
Esta estrategia es ULTRA-AGRESIVA y busca específicamente alcanzar ratios ~117
"""
function sampling_ultra_ratio_hunter_enorme(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, n_sample::Int)
    O = size(roi, 1)
    P = size(upi, 1)
    
    # PHASE 1: Identificar las TOP órdenes por valor absoluto
    valores_ordenes = [(o, sum(roi[o, :])) for o in 1:O]
    sort!(valores_ordenes, by=x -> x[2], rev=true)
    
    # Tomar el 80% superior - ULTRA AGRESIVO
    top_80_percent = Int(ceil(O * 0.8))
    top_ordenes = [valores_ordenes[i][1] for i in 1:top_80_percent]
    
    # PHASE 2: Identificar pasillos ultra-eficientes
    capacidades_pasillos = [(p, sum(upi[p, :])) for p in 1:P]
    sort!(capacidades_pasillos, by=x -> x[2], rev=true)
    
    mejor_ratio = 0.0
    mejor_solucion = nothing
    
    # PHASE 3: Búsqueda ULTRA-EXHAUSTIVA adaptativa según UB
    # Determinar rango de pasillos según la magnitud del problema
    max_pasillos_probar = if UB > 10000
        min(P, 20)  # Problemas muy grandes: hasta 20 pasillos
    elseif UB > 5000
        min(P, 15)  # Problemas grandes: hasta 15 pasillos  
    else
        min(P, 10)  # Problemas medianos: hasta 10 pasillos
    end
    
    pasillos_a_probar = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    if max_pasillos_probar > 10
        append!(pasillos_a_probar, [12, 15, 18, 20])
    end
    
    for num_pasillos in pasillos_a_probar
        if num_pasillos > P
            break
        end
        
        # Seleccionar los mejores pasillos
        pasillos_seleccionados = Set([capacidades_pasillos[i][1] for i in 1:num_pasillos])
        
        # Encontrar órdenes compatibles con estos pasillos
        ordenes_compatibles = []
        for o in top_ordenes[1:min(1000, length(top_ordenes))]  # Top 1000 órdenes
            if es_orden_compatible(o, pasillos_seleccionados, roi, upi)
                valor_o = sum(roi[o, :])
                push!(ordenes_compatibles, (o, valor_o))
            end
        end
        
        if isempty(ordenes_compatibles)
            continue
        end
        
        # Ordenar por valor descendente
        sort!(ordenes_compatibles, by=x -> x[2], rev=true)
        
        # PHASE 4: ULTRA-GREEDY CONSTRUCTION adaptativo con foco en RATIO
        # Determinar combinaciones a probar según tamaño del problema
        max_combinaciones = if UB > 10000
            [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 15, 20, 25, 30, 40, 50, 75, 100, 150, 200, 300, 500]
        elseif UB > 5000  
            [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 15, 20, 25, 30, 40, 50, 75, 100, 150, 200]
        else
            [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 15, 20, 25, 30, 40, 50, 75, 100]
        end
        
        for max_ordenes in max_combinaciones
            if max_ordenes > length(ordenes_compatibles)
                break
            end
            
            ordenes_seleccionadas = Set{Int}()
            valor_actual = 0
            
            # Greedy: agregar órdenes hasta que se viola UB
            for i in 1:min(max_ordenes, length(ordenes_compatibles))
                o, valor_o = ordenes_compatibles[i]
                if valor_actual + valor_o <= UB
                    push!(ordenes_seleccionadas, o)
                    valor_actual += valor_o
                else
                    break
                end
            end
            
            # Verificar factibilidad y evaluar ratio
            if valor_actual >= LB && !isempty(ordenes_seleccionadas)
                candidato = Solucion(ordenes_seleccionadas, pasillos_seleccionados)
                if es_factible(candidato, roi, upi, LB, UB, config)
                    ratio = evaluar(candidato, roi)
                    if ratio > mejor_ratio
                        mejor_ratio = ratio
                        mejor_solucion = candidato
                        
                        # Si encontramos un ratio muy alto, reportar inmediatamente
                        if ratio > 50.0
                            println("   🔥 ULTRA RATIO HUNTER: ratio=$(round(ratio, digits=3)) con $(length(ordenes_seleccionadas)) órdenes y $(num_pasillos) pasillos")
                        end
                    end
                end
            end
        end
    end
    
    return mejor_solucion
end

# ========================================
# EJECUTOR DE ESTRATEGIAS ESCALABLES
# ========================================

function ejecutar_estrategia_enorme(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, estrategia::Symbol, n_sample::Int)
    
    if estrategia == :sampling_ultra_ratio_hunter
        return sampling_ultra_ratio_hunter_enorme(roi, upi, LB, UB, config, n_sample)
    elseif estrategia == :sampling_cluster_valor
        return sampling_cluster_valor_enorme(roi, upi, LB, UB, config, n_sample)
    elseif estrategia == :sampling_densidad_extrema
        return sampling_densidad_extrema_enorme(roi, upi, LB, UB, config, n_sample)
    elseif estrategia == :sampling_pasillos_dominantes
        return sampling_pasillos_dominantes_enorme(roi, upi, LB, UB, config, n_sample)
    elseif estrategia == :sampling_greedy_ub
        return sampling_greedy_ub_enorme(roi, upi, LB, UB, config, n_sample)
    elseif estrategia == :sampling_hibrido_balanceado
        return sampling_hibrido_balanceado_enorme(roi, upi, LB, UB, config, n_sample)
    elseif estrategia == :sampling_ratio_agresivo
        return sampling_ratio_agresivo_enorme(roi, upi, LB, UB, config, n_sample)
    elseif estrategia == :sampling_pasillos_minimos
        return sampling_pasillos_minimos_enorme(roi, upi, LB, UB, config, n_sample)
    elseif estrategia == :sampling_elite_orders
        return sampling_elite_orders_enorme(roi, upi, LB, UB, config, n_sample)
    end
    
    return nothing
end

# ========================================
# ESTRATEGIA 1: SAMPLING + CLUSTERING POR VALOR
# ========================================

"""
Clustering inteligente: Evaluar solo muestra representativa, clustering por valor
"""
function sampling_cluster_valor_enorme(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, n_sample::Int)
    O, I = size(roi)
    
    # PASO 1: SAMPLING ESTRATIFICADO por valor
    valores_todas = [sum(roi[o, :]) for o in 1:O]
    orden_indices = sortperm(valores_todas, rev=true)
    
    # Sampling estratificado: top 40%, medio 40%, bajo 20%
    n_top = Int(ceil(n_sample * 0.4))
    n_medio = Int(ceil(n_sample * 0.4))
    n_bajo = n_sample - n_top - n_medio
    
    sample_top = orden_indices[1:min(n_top, Int(O*0.2))]
    sample_medio = orden_indices[Int(O*0.2)+1:min(Int(O*0.2) + n_medio, Int(O*0.8))]
    sample_bajo = orden_indices[Int(O*0.8)+1:min(Int(O*0.8) + n_bajo, O)]
    
    ordenes_sample = vcat(
        sample(sample_top, min(n_top, length(sample_top)), replace=false),
        sample(sample_medio, min(n_medio, length(sample_medio)), replace=false),
        sample(sample_bajo, min(n_bajo, length(sample_bajo)), replace=false)
    )
    
    # PASO 2: CLUSTERING por valor dentro del sample
    valores_sample = [(o, sum(roi[o, :])) for o in ordenes_sample]
    sort!(valores_sample, by=x -> x[2], rev=true)
    
    # PASO 3: CONSTRUCCIÓN GREEDY sobre clusters
    ordenes_seleccionadas = Set{Int}()
    valor_actual = 0
    
    for (o, valor) in valores_sample
        if valor_actual + valor <= UB
            push!(ordenes_seleccionadas, o)
            valor_actual += valor
        end
        
        if valor_actual >= LB
            break
        end
    end
    
    if valor_actual >= LB && !isempty(ordenes_seleccionadas)
        pasillos = calcular_pasillos_optimos(ordenes_seleccionadas, roi, upi, LB, UB, config)
        return Solucion(ordenes_seleccionadas, pasillos)
    end
    
    return nothing
end

# ========================================
# ESTRATEGIA 2: SAMPLING + DENSIDAD EXTREMA
# ========================================

"""
Densidad extrema: Solo órdenes ultra-densas del sample
"""
function sampling_densidad_extrema_enorme(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, n_sample::Int)
    O = size(roi, 1)
    
    # SAMPLING ALEATORIO
    ordenes_sample = sample(1:O, min(n_sample, O), replace=false)
    
    # EVALUAR DENSIDADES en el sample
    ordenes_densas = []
    
    for o in ordenes_sample
        valor = sum(roi[o, :])
        items = count(roi[o, :] .> 0)
        
        if items > 0 && valor > 0
            densidad = valor / items
            eficiencia_espacial = valor / sqrt(items)
            
            # Solo considerar órdenes muy densas
            umbral_densidad = config.es_patologica ? 1.5 : 2.0
            if densidad >= umbral_densidad
                score_extremo = densidad * 0.8 + eficiencia_espacial * 0.2
                push!(ordenes_densas, (o, valor, score_extremo, densidad))
            end
        end
    end
    
    if isempty(ordenes_densas)
        # Si no hay órdenes súper densas, relajar criterio
        for o in ordenes_sample
            valor = sum(roi[o, :])
            items = count(roi[o, :] .> 0)
            if items > 0 && valor > 0
                densidad = valor / items
                if densidad >= 1.0
                    push!(ordenes_densas, (o, valor, densidad, densidad))
                end
            end
        end
    end
    
    sort!(ordenes_densas, by=x -> x[3], rev=true)
    
    # CONSTRUCCIÓN con órdenes densas
    ordenes_seleccionadas = Set{Int}()
    valor_actual = 0
    
    for (o, valor, score, densidad) in ordenes_densas
        if valor_actual + valor <= UB
            push!(ordenes_seleccionadas, o)
            valor_actual += valor
        end
    end
    
    if valor_actual >= LB && !isempty(ordenes_seleccionadas)
        pasillos = calcular_pasillos_optimos(ordenes_seleccionadas, roi, upi, LB, UB, config)
        return Solucion(ordenes_seleccionadas, pasillos)
    end
    
    return nothing
end

# ========================================
# ESTRATEGIA 3: SAMPLING + PASILLOS DOMINANTES
# ========================================

"""
Pasillos dominantes: Seleccionar pasillos de mayor capacidad, llenar con órdenes del sample
"""
function sampling_pasillos_dominantes_enorme(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, n_sample::Int)
    P = size(upi, 1)
    O, I = size(roi)
    
    # EVALUAR pasillos por capacidad (sin sampling, es rápido)
    pasillos_evaluados = []
    
    for p in 1:P
        capacidad_total = sum(upi[p, :])
        items_cubiertos = count(upi[p, :] .> 0)
        densidad_pasillo = items_cubiertos > 0 ? capacidad_total / items_cubiertos : 0
        
        # Score para enormes: priorizar capacidad total
        score = capacidad_total * 0.8 + items_cubiertos * 0.2
        
        push!(pasillos_evaluados, (p, capacidad_total, score, items_cubiertos))
    end
    
    sort!(pasillos_evaluados, by=x -> x[3], rev=true)
    
    # Seleccionar top pasillos (más conservador para enormes)
    n_pasillos = if config.es_patologica
        min(P, max(3, Int(ceil(config.pasillos_teoricos * 1.1))))
    else
        min(P, max(5, Int(ceil(config.pasillos_teoricos * 1.2))))
    end
    
    pasillos_seleccionados = Set{Int}()
    for i in 1:min(n_pasillos, length(pasillos_evaluados))
        push!(pasillos_seleccionados, pasillos_evaluados[i][1])
    end
    
    # SAMPLING de órdenes
    ordenes_sample = sample(1:O, min(n_sample, O), replace=false)
    
    # Encontrar órdenes compatibles con estos pasillos (dentro del sample)
    ordenes_compatibles = []
    for o in ordenes_sample
        if es_orden_compatible(o, pasillos_seleccionados, roi, upi)
            valor_o = sum(roi[o, :])
            push!(ordenes_compatibles, (o, valor_o))
        end
    end
    
    if isempty(ordenes_compatibles)
        return nothing
    end
    
    # Ordenar por valor y tomar las mejores
    sort!(ordenes_compatibles, by=x -> x[2], rev=true)
    
    ordenes_seleccionadas = Set{Int}()
    valor_actual = 0
    
    for (o, valor) in ordenes_compatibles
        if valor_actual + valor <= UB
            push!(ordenes_seleccionadas, o)
            valor_actual += valor
        end
    end
    
    if valor_actual >= LB && !isempty(ordenes_seleccionadas)
        return Solucion(ordenes_seleccionadas, pasillos_seleccionados)
    end
    
    return nothing
end

# ========================================
# ESTRATEGIA 4: SAMPLING + GREEDY UB
# ========================================

"""
Greedy UB: Llenar agresivamente hacia UB con sample de órdenes
"""
function sampling_greedy_ub_enorme(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, n_sample::Int)
    O = size(roi, 1)
    
    # SAMPLING ALEATORIO
    ordenes_sample = sample(1:O, min(n_sample, O), replace=false)
    
    # Ordenar sample por valor descendente
    ordenes_por_valor = [(o, sum(roi[o, :])) for o in ordenes_sample]
    sort!(ordenes_por_valor, by=x -> x[2], rev=true)
    
    ordenes_seleccionadas = Set{Int}()
    valor_actual = 0
    
    # LLENAR agresivamente hasta UB
    for (o, valor) in ordenes_por_valor
        if valor > 0 && valor_actual + valor <= UB
            push!(ordenes_seleccionadas, o)
            valor_actual += valor
        end
        
        if valor_actual >= LB
            # Continue llenando hasta UB si es posible
        end
    end
    
    if valor_actual >= LB && !isempty(ordenes_seleccionadas)
        pasillos = calcular_pasillos_optimos(ordenes_seleccionadas, roi, upi, LB, UB, config)
        if !isempty(pasillos)
            return Solucion(ordenes_seleccionadas, pasillos)
        end
    end
    
    # Último recurso: orden individual más valiosa del sample
    for (o, valor) in ordenes_por_valor
        if LB <= valor <= UB
            ordenes = Set([o])
            pasillos = calcular_pasillos_optimos(ordenes, roi, upi, LB, UB, config)
            if !isempty(pasillos)
                return Solucion(ordenes, pasillos)
            end
        end
    end
    
    return nothing
end

# ========================================
# ESTRATEGIA 5: SAMPLING + HÍBRIDO BALANCEADO
# ========================================

"""
Híbrido balanceado: Criterios múltiples con sampling
"""
function sampling_hibrido_balanceado_enorme(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, n_sample::Int)
    O, I = size(roi)
    
    # SAMPLING ALEATORIO
    ordenes_sample = sample(1:O, min(n_sample, O), replace=false)
    
    # Pesos adaptativos para enormes
    if config.es_patologica
        peso_valor = 0.6
        peso_densidad = 0.25
        peso_eficiencia = 0.15
    else
        peso_valor = 0.5
        peso_densidad = 0.3
        peso_eficiencia = 0.2
    end
    
    # Calcular métricas para el sample
    valores = []
    densidades = []
    eficiencias = []
    
    for o in ordenes_sample
        valor = sum(roi[o, :])
        items = count(roi[o, :] .> 0)
        
        push!(valores, valor)
        
        if items > 0
            push!(densidades, valor / items)
            push!(eficiencias, valor / sqrt(items))
        else
            push!(densidades, 0.0)
            push!(eficiencias, 0.0)
        end
    end
    
    # Normalizar métricas del sample
    max_valor = maximum(valores)
    max_densidad = maximum(densidades)
    max_eficiencia = maximum(eficiencias)
    
    ordenes_evaluadas = []
    
    for (idx, o) in enumerate(ordenes_sample)
        if max_valor > 0 && max_densidad > 0 && max_eficiencia > 0
            valor_norm = valores[idx] / max_valor
            densidad_norm = densidades[idx] / max_densidad
            eficiencia_norm = eficiencias[idx] / max_eficiencia
            
            score_hibrido = (valor_norm * peso_valor + 
                           densidad_norm * peso_densidad + 
                           eficiencia_norm * peso_eficiencia)
            
            push!(ordenes_evaluadas, (o, valores[idx], score_hibrido))
        end
    end
    
    sort!(ordenes_evaluadas, by=x -> x[3], rev=true)
    
    # Construcción balanceada
    ordenes_seleccionadas = Set{Int}()
    valor_actual = 0
    
    for (o, valor, score) in ordenes_evaluadas
        if valor > 0 && valor_actual + valor <= UB
            push!(ordenes_seleccionadas, o)
            valor_actual += valor
        end
    end
    
    if valor_actual >= LB && !isempty(ordenes_seleccionadas)
        pasillos = calcular_pasillos_optimos(ordenes_seleccionadas, roi, upi, LB, UB, config)
        return Solucion(ordenes_seleccionadas, pasillos)
    end
    
    return nothing
end

# ========================================
# CONSTRUCTIVA DE EMERGENCIA ESCALABLE
# ========================================

"""
Constructiva de emergencia para enormes: Sampling + greedy simple
"""
function constructiva_emergencia_enorme(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, n_sample::Int)
    O = size(roi, 1)
    
    # Sampling más pequeño para emergencia
    n_emergencia = min(n_sample, 200)
    ordenes_sample = sample(1:O, min(n_emergencia, O), replace=false)
    
    # Greedy simple por valor en el sample
    ordenes_por_valor = [(o, sum(roi[o, :])) for o in ordenes_sample]
    sort!(ordenes_por_valor, by=x -> x[2], rev=true)
    
    ordenes_seleccionadas = Set{Int}()
    valor_actual = 0
    
    for (o, valor) in ordenes_por_valor
        if valor > 0 && valor_actual + valor <= UB
            push!(ordenes_seleccionadas, o)
            valor_actual += valor
        end
        
        if valor_actual >= LB
            break
        end
    end
    
    if valor_actual >= LB && !isempty(ordenes_seleccionadas)
        pasillos = calcular_pasillos_optimos(ordenes_seleccionadas, roi, upi, LB, UB, config)
        if !isempty(pasillos)
            return Solucion(ordenes_seleccionadas, pasillos)
        end
    end
    
    return nothing
end

# ========================================
# FUNCIONES AUXILIARES ESCALABLES
# ========================================

"""
Clustering rápido para enormes por características similares
"""
function clustering_rapido_enormes(ordenes_sample::Vector{Int}, roi::Matrix{Int}, max_clusters::Int = 10)
    if length(ordenes_sample) <= max_clusters
        return [[o] for o in ordenes_sample]
    end
    
    I = size(roi, 2)
    
    # Clustering simple por valor y diversidad de ítems
    clusters = Vector{Vector{Int}}()
    
    # Calcular características básicas
    caracteristicas = []
    for o in ordenes_sample
        valor = sum(roi[o, :])
        items_distintos = count(roi[o, :] .> 0)
        push!(caracteristicas, (o, valor, items_distintos))
    end
    
    # Ordenar por valor y dividir en clusters
    sort!(caracteristicas, by=x -> x[2], rev=true)
    
    cluster_size = Int(ceil(length(caracteristicas) / max_clusters))
    
    for i in 1:max_clusters
        inicio = (i-1) * cluster_size + 1
        fin = min(i * cluster_size, length(caracteristicas))
        
        if inicio <= length(caracteristicas)
            cluster = [caracteristicas[j][1] for j in inicio:fin]
            push!(clusters, cluster)
        end
    end
    
    return clusters
end

"""
Análisis de capacidad residual para enormes (versión rápida)
"""
function analizar_capacidad_residual_rapido(solucion::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, UB::Int)
    # Versión simplificada para enormes
    valor_actual = sum(sum(roi[o, :]) for o in solucion.ordenes)
    margen_basico = UB - valor_actual
    
    # Para enormes, usar estimación rápida en lugar de análisis ítem por ítem
    return max(0, Int(margen_basico * 0.8))  # Factor de seguridad del 80%
end

"""
Estimación rápida de pasillos necesarios para enormes
"""
function estimar_pasillos_necesarios_rapido(ordenes::Set{Int}, roi::Matrix{Int}, upi::Matrix{Int})
    if isempty(ordenes)
        return 0
    end
    
    # Estimación rápida basada en demanda total y capacidad promedio
    demanda_total = sum(sum(roi[o, :]) for o in ordenes)
    capacidad_promedio_pasillo = mean([sum(upi[p, :]) for p in 1:size(upi, 1)])
    
    pasillos_estimados = Int(ceil(demanda_total / capacidad_promedio_pasillo))
    
    return max(1, pasillos_estimados)
end

# ========================================
# NUEVAS ESTRATEGIAS AGRESIVAS PARA RATIO ALTO
# ========================================

"""
ESTRATEGIA 6: Ratio agresivo - Buscar el ratio más alto posible
"""
function sampling_ratio_agresivo_enorme(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, n_sample::Int)
    O = size(roi, 1)
    P = size(upi, 1)
    
    # SAMPLING con sesgo hacia órdenes de alto valor
    valores_todas = [sum(roi[o, :]) for o in 1:O]
    orden_indices = sortperm(valores_todas, rev=true)
    
    # Tomar más del top para maximizar ratio - MUCHO MÁS AGRESIVO
    n_top = min(n_sample, Int(O * 0.7))  # 70% del top - ULTRA AGRESIVO
    ordenes_sample = orden_indices[1:n_top]
    
    # Buscar combinaciones que maximicen ratio = unidades/pasillos
    mejor_ratio = 0.0
    mejor_solucion = nothing
    
    # Probar múltiples combinaciones ULTRA-AGRESIVAS para ratio alto
    for num_ordenes in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 15, 18, 20, 25, 30, 35, 40, 50]
        if num_ordenes > length(ordenes_sample)
            break
        end
        
        # Probar las top órdenes en grupos pequeños - MÁS COMBINACIONES
        for inicio in 1:min(25, length(ordenes_sample) - num_ordenes + 1)
            ordenes_subset = Set(ordenes_sample[inicio:inicio + num_ordenes - 1])
            valor_total = sum(sum(roi[o, :]) for o in ordenes_subset)
            
            if LB <= valor_total <= UB
                pasillos = calcular_pasillos_optimos(ordenes_subset, roi, upi, LB, UB, config)
                if !isempty(pasillos)
                    candidato = Solucion(ordenes_subset, pasillos)
                    if es_factible(candidato, roi, upi, LB, UB, config)
                        ratio = evaluar(candidato, roi)
                        if ratio > mejor_ratio
                            mejor_ratio = ratio
                            mejor_solucion = candidato
                        end
                    end
                end
            end
        end
    end
    
    return mejor_solucion
end

"""
ESTRATEGIA 7: Pasillos mínimos - Minimizar pasillos para maximizar ratio
"""
function sampling_pasillos_minimos_enorme(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, n_sample::Int)
    O = size(roi, 1)
    P = size(upi, 1)
    
    # SAMPLING de órdenes
    ordenes_sample = sample(1:O, min(n_sample, O), replace=false)
    
    # Ordenar por valor descendente
    ordenes_por_valor = [(o, sum(roi[o, :])) for o in ordenes_sample]
    sort!(ordenes_por_valor, by=x -> x[2], rev=true)
    
    mejor_ratio = 0.0
    mejor_solucion = nothing
    
    # Probar con número mínimo de pasillos - MÁS AGRESIVO
    for min_pasillos in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        if min_pasillos > P
            break
        end
        
        # Seleccionar los mejores pasillos
        pasillos_capacidades = [(p, sum(upi[p, :])) for p in 1:P]
        sort!(pasillos_capacidades, by=x -> x[2], rev=true)
        pasillos_seleccionados = Set([pasillos_capacidades[i][1] for i in 1:min_pasillos])
        
        # Encontrar órdenes compatibles con estos pasillos
        ordenes_compatibles = []
        for (o, valor) in ordenes_por_valor
            if es_orden_compatible(o, pasillos_seleccionados, roi, upi)
                push!(ordenes_compatibles, (o, valor))
            end
        end
        
        # Construir solución greedy con pasillos fijos
        ordenes_seleccionadas = Set{Int}()
        valor_actual = 0
        
        for (o, valor) in ordenes_compatibles
            if valor_actual + valor <= UB
                push!(ordenes_seleccionadas, o)
                valor_actual += valor
            end
        end
        
        if valor_actual >= LB && !isempty(ordenes_seleccionadas)
            candidato = Solucion(ordenes_seleccionadas, pasillos_seleccionados)
            if es_factible(candidato, roi, upi, LB, UB, config)
                ratio = evaluar(candidato, roi)
                if ratio > mejor_ratio
                    mejor_ratio = ratio
                    mejor_solucion = candidato
                end
            end
        end
    end
    
    return mejor_solucion
end

"""
ESTRATEGIA 8: Órdenes elite - Solo las mejores órdenes con pasillos óptimos
"""
function sampling_elite_orders_enorme(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, n_sample::Int)
    O = size(roi, 1)
    
    # Evaluar todas las órdenes por "elite score"
    ordenes_elite = []
    for o in 1:O
        valor = sum(roi[o, :])
        items = count(roi[o, :] .> 0)
        if items > 0 && valor > 0
            densidad = valor / items
            eficiencia = valor / sqrt(items)
            # Score elite: valor alto + densidad alta + pocos ítems
            score_elite = valor * 0.6 + densidad * 0.3 + (100 / items) * 0.1
            push!(ordenes_elite, (o, valor, score_elite))
        end
    end
    
    sort!(ordenes_elite, by=x -> x[3], rev=true)
    
    # Tomar top elite para sampling
    n_elite = min(n_sample ÷ 2, length(ordenes_elite))
    elite_sample = [ordenes_elite[i][1] for i in 1:n_elite]
    
    mejor_ratio = 0.0
    mejor_solucion = nothing
    
    # Probar diferentes combinaciones de órdenes elite - MÁS AGRESIVO
    for subset_size in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 15, 18, 20, 25, 30, 35, 40, 50, 60, 80, 100]
        if subset_size > length(elite_sample)
            break
        end
        
        ordenes_subset = Set(elite_sample[1:subset_size])
        valor_total = sum(sum(roi[o, :]) for o in ordenes_subset)
        
        if LB <= valor_total <= UB
            pasillos = calcular_pasillos_optimos(ordenes_subset, roi, upi, LB, UB, config)
            if !isempty(pasillos)
                candidato = Solucion(ordenes_subset, pasillos)
                if es_factible(candidato, roi, upi, LB, UB, config)
                    ratio = evaluar(candidato, roi)
                    if ratio > mejor_ratio
                        mejor_ratio = ratio
                        mejor_solucion = candidato
                    end
                end
            end
        end
    end
    
    return mejor_solucion
end