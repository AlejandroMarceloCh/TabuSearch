# solvers/grandes/grandes_constructivas.jl
# ========================================
# CONSTRUCTIVAS ESCALABLES SÚPER AGRESIVAS
# OBJETIVO: Destrozar instancias grandes patológicas
# ========================================


using Random
using StatsBase: sample
using Combinatorics


# ========================================
# CONSTRUCTIVA PRINCIPAL - MULTISTART AGRESIVO
# ========================================

"""
Constructiva multistart súper agresiva para grandes
ESTRATEGIA: 8 enfoques diferentes, retornar el mejor
"""
function generar_solucion_inicial_grande(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia; semilla=nothing)
    if semilla !== nothing
        Random.seed!(semilla)
    end
    
    println("🔥 CONSTRUCTIVA GRANDE AGRESIVA")
    println("   📊 Instancia: $(config.ordenes) órdenes, $(config.items) ítems, $(config.pasillos) pasillos")
    println("   🎯 Objetivo: Maximizar unidades/pasillos")
    println("   ⚡ Modo: AGRESIVO para patológicas")
    
    O, I = size(roi)
    
    # BANCO DE ESTRATEGIAS AGRESIVAS
    estrategias = [
        (:sampling_explosivo, "🎯 Sampling explosivo top 30%"),
        (:clustering_inteligente, "🧩 Clustering por ítems"),
        (:pasillos_primero_dominante, "🚪 Pasillos dominantes primero"),
        (:valor_puro_masivo, "💰 Valor puro masivo"),
        (:densidad_extrema, "📊 Densidad extrema"),
        (:hibrido_balanceado, "⚖️ Híbrido balanceado"),
        (:objetivo_reverso, "🔄 Ingeniería reversa"),
        (:consolidacion_agresiva, "🎯 Consolidación agresiva")
    ]
    
    mejor_solucion = nothing
    mejor_ratio = 0.0
    
    for (estrategia, descripcion) in estrategias
        try
            candidato = ejecutar_estrategia_grande(roi, upi, LB, UB, config, estrategia)
            
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
        println("   🔧 Aplicando constructiva de emergencia...")
        mejor_solucion = constructiva_emergencia_grande(roi, upi, LB, UB, config)
    end
    
    return mejor_solucion
end

# ========================================
# EJECUTOR DE ESTRATEGIAS
# ========================================

function ejecutar_estrategia_grande(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, estrategia::Symbol)
    
    if estrategia == :sampling_explosivo
        return sampling_explosivo_grande(roi, upi, LB, UB, config)
    elseif estrategia == :clustering_inteligente
        return clustering_inteligente_grande(roi, upi, LB, UB, config)
    elseif estrategia == :pasillos_primero_dominante
        return pasillos_primero_dominante_grande(roi, upi, LB, UB, config)
    elseif estrategia == :valor_puro_masivo
        return valor_puro_masivo_grande(roi, upi, LB, UB, config)
    elseif estrategia == :densidad_extrema
        return densidad_extrema_grande(roi, upi, LB, UB, config)
    elseif estrategia == :hibrido_balanceado
        return hibrido_balanceado_grande(roi, upi, LB, UB, config)
    elseif estrategia == :objetivo_reverso
        return objetivo_reverso_grande(roi, upi, LB, UB, config)
    elseif estrategia == :consolidacion_agresiva
        return consolidacion_agresiva_grande(roi, upi, LB, UB, config)
    end
    
    return nothing
end

# ========================================
# ESTRATEGIA 1: SAMPLING EXPLOSIVO
# ========================================


"""
Sampling explosivo: Evalúa top 30% de órdenes por múltiples criterios
"""
function sampling_explosivo_grande(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    O, I = size(roi)
    
    # Evaluar TODAS las órdenes por múltiples criterios
    candidatos = []
    
    for o in 1:O
        valor = sum(roi[o, :])
        items = count(roi[o, :] .> 0)
        
        if valor > 0 && items > 0
            densidad = valor / items
            eficiencia = valor / sqrt(items)
            compactacion = valor / max(1, count(roi[o, :] .== 1))
            
            # SCORE AGRESIVO: Priorizar valor alto
            score = valor * 0.6 + densidad * 0.25 + eficiencia * 0.15
            
            push!(candidatos, (o, valor, score, densidad))
        end
    end
    
    # Tomar top 30% más agresivo
    sort!(candidatos, by=x -> x[3], rev=true)
    n_candidatos = max(5, Int(ceil(length(candidatos) * 0.3)))
    top_candidatos = candidatos[1:n_candidatos]
    
    # Construcción greedy agresiva
    ordenes_seleccionadas = Set{Int}()
    valor_actual = 0
    
    for (o, valor, score, densidad) in top_candidatos
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
# ESTRATEGIA 2: CLUSTERING INTELIGENTE
# ========================================

"""
Clustering por ítems: Agrupa órdenes que comparten ítems
"""
function clustering_inteligente_grande(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    O, I = size(roi)
    
    # Crear matriz de similitud entre órdenes (por ítems compartidos)
    similitudes = Dict{Tuple{Int,Int}, Float64}()
    
    for o1 in 1:min(O, 200)  # Limitar para escalabilidad
        for o2 in (o1+1):min(O, 200)
            items_o1 = Set(i for i in 1:I if roi[o1, i] > 0)
            items_o2 = Set(i for i in 1:I if roi[o2, i] > 0)
            
            interseccion = length(intersect(items_o1, items_o2))
            union_size = length(union(items_o1, items_o2))
            
            if union_size > 0
                similitud = interseccion / union_size  # Jaccard similarity
                if similitud > 0.1  # Solo guardar similitudes significativas
                    similitudes[(o1, o2)] = similitud
                end
            end
        end
    end
    
    # Encontrar clusters usando algoritmo greedy
    clusters = []
    ordenes_usadas = Set{Int}()
    
    # Ordenar similitudes por valor
    similitudes_ordenadas = sort(collect(similitudes), by=x -> x[2], rev=true)
    
    for ((o1, o2), similitud) in similitudes_ordenadas[1:min(50, length(similitudes_ordenadas))]
        if !(o1 in ordenes_usadas) && !(o2 in ordenes_usadas)
            cluster = Set([o1, o2])
            
            # Expandir cluster con órdenes similares
            for o3 in 1:O
                if !(o3 in ordenes_usadas) && o3 != o1 && o3 != o2
                    # Verificar similitud con el cluster
                    similitud_cluster = 0.0
                    count_similitudes = 0
                    
                    for o_cluster in cluster
                        if haskey(similitudes, (min(o3, o_cluster), max(o3, o_cluster)))
                            similitud_cluster += similitudes[(min(o3, o_cluster), max(o3, o_cluster))]
                            count_similitudes += 1
                        end
                    end
                    
                    if count_similitudes > 0
                        similitud_promedio = similitud_cluster / count_similitudes
                        if similitud_promedio > 0.15  # Umbral para agregar al cluster
                            push!(cluster, o3)
                        end
                    end
                end
            end
            
            push!(clusters, cluster)
            for o in cluster
                push!(ordenes_usadas, o)
            end
        end
    end
    
    # Evaluar clusters por valor total
    clusters_evaluados = []
    for cluster in clusters
        valor_cluster = sum(sum(roi[o, :]) for o in cluster)
        densidad_cluster = valor_cluster / length(cluster)
        push!(clusters_evaluados, (cluster, valor_cluster, densidad_cluster))
    end
    
    sort!(clusters_evaluados, by=x -> x[3], rev=true)  # Por densidad
    
    # Construcción por clusters
    ordenes_seleccionadas = Set{Int}()
    valor_actual = 0
    
    for (cluster, valor_cluster, densidad) in clusters_evaluados
        if valor_actual + valor_cluster <= UB
            for o in cluster
                push!(ordenes_seleccionadas, o)
            end
            valor_actual += valor_cluster
        end
    end
    
    if valor_actual >= LB && !isempty(ordenes_seleccionadas)
        pasillos = calcular_pasillos_optimos(ordenes_seleccionadas, roi, upi, LB, UB, config)
        return Solucion(ordenes_seleccionadas, pasillos)
    end
    
    return nothing
end

# ========================================
# ESTRATEGIA 3: PASILLOS PRIMERO DOMINANTE
# ========================================

"""
Pasillos dominantes primero: Selecciona pasillos de mayor capacidad y llena con órdenes
"""
function pasillos_primero_dominante_grande(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    P = size(upi, 1)
    O, I = size(roi)
    
    # Evaluar pasillos por capacidad y cobertura
    pasillos_evaluados = []
    
    for p in 1:P
        capacidad_total = sum(upi[p, :])
        items_cubiertos = count(upi[p, :] .> 0)
        densidad_pasillo = items_cubiertos > 0 ? capacidad_total / items_cubiertos : 0
        
        # Score agresivo: capacidad + diversidad
        score = capacidad_total * 0.7 + items_cubiertos * 0.3
        
        push!(pasillos_evaluados, (p, capacidad_total, score, items_cubiertos))
    end
    
    sort!(pasillos_evaluados, by=x -> x[3], rev=true)
    
    # Seleccionar top pasillos (más agresivo para patológicas)
    n_pasillos = if config.es_patologica
        min(P, max(5, Int(ceil(P * 0.15))))  # 15% para patológicas
    else
        min(P, max(3, Int(ceil(P * 0.10))))  # 10% para normales
    end
    
    pasillos_seleccionados = Set{Int}()
    for i in 1:n_pasillos
        push!(pasillos_seleccionados, pasillos_evaluados[i][1])
    end
    
    # Encontrar TODAS las órdenes compatibles con estos pasillos
    ordenes_compatibles = encontrar_ordenes_compatibles(pasillos_seleccionados, roi, upi)
    
    if isempty(ordenes_compatibles)
        return nothing
    end
    
    # Ordenar órdenes compatibles por valor y tomar las mejores
    ordenes_por_valor = [(o, sum(roi[o, :])) for o in ordenes_compatibles]
    sort!(ordenes_por_valor, by=x -> x[2], rev=true)
    
    ordenes_seleccionadas = Set{Int}()
    valor_actual = 0
    
    for (o, valor) in ordenes_por_valor
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
# ESTRATEGIA 4: VALOR PURO MASIVO
# ========================================

"""
Valor puro masivo: Greedy por valor, maximizando unidades totales
"""
function valor_puro_masivo_grande(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    O = size(roi, 1)
    
    # Ordenar TODAS las órdenes por valor descendente
    ordenes_por_valor = [(o, sum(roi[o, :])) for o in 1:O]
    sort!(ordenes_por_valor, by=x -> x[2], rev=true)
    
    ordenes_seleccionadas = Set{Int}()
    valor_actual = 0
    
    # Tomar TODAS las órdenes que quepan (súper agresivo)
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
    
    # Último recurso: orden individual más valiosa
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
# ESTRATEGIA 5: DENSIDAD EXTREMA
# ========================================

"""
Densidad extrema: Solo órdenes súper densas (valor/ítems alto)
"""
function densidad_extrema_grande(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    O, I = size(roi)
    
    # Calcular densidades extremas
    ordenes_densas = []
    
    for o in 1:O
        valor = sum(roi[o, :])
        items = count(roi[o, :] .> 0)
        
        if items > 0 && valor > 0
            densidad = valor / items
            eficiencia_espacial = valor / sqrt(items)
            
            # Solo considerar órdenes MUY densas
            if densidad >= 2.0  # Umbral alto para densidad
                score_extremo = densidad * 0.8 + eficiencia_espacial * 0.2
                push!(ordenes_densas, (o, valor, score_extremo, densidad))
            end
        end
    end
    
    if isempty(ordenes_densas)
        # Si no hay órdenes súper densas, relajar criterio
        for o in 1:O
            valor = sum(roi[o, :])
            items = count(roi[o, :] .> 0)
            if items > 0 && valor > 0
                densidad = valor / items
                if densidad >= 1.0  # Criterio relajado
                    push!(ordenes_densas, (o, valor, densidad, densidad))
                end
            end
        end
    end
    
    sort!(ordenes_densas, by=x -> x[3], rev=true)
    
    # Construcción greedy con órdenes densas
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
# ESTRATEGIA 6: HÍBRIDO BALANCEADO
# ========================================

"""
Híbrido balanceado: Combina múltiples criterios con pesos dinámicos
"""
function hibrido_balanceado_grande(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    O, I = size(roi)
    
    # Pesos adaptativos según patología
    if config.es_patologica
        peso_valor = 0.5
        peso_densidad = 0.3
        peso_eficiencia = 0.2
    else
        peso_valor = 0.4
        peso_densidad = 0.35
        peso_eficiencia = 0.25
    end
    
    # Normalizar métricas
    valores = [sum(roi[o, :]) for o in 1:O]
    densidades = []
    eficiencias = []
    
    for o in 1:O
        valor = valores[o]
        items = count(roi[o, :] .> 0)
        
        if items > 0
            push!(densidades, valor / items)
            push!(eficiencias, valor / sqrt(items))
        else
            push!(densidades, 0.0)
            push!(eficiencias, 0.0)
        end
    end
    
    # Normalizar a [0,1]
    max_valor = maximum(valores)
    max_densidad = maximum(densidades)
    max_eficiencia = maximum(eficiencias)
    
    ordenes_evaluadas = []
    
    for o in 1:O
        if max_valor > 0 && max_densidad > 0 && max_eficiencia > 0
            valor_norm = valores[o] / max_valor
            densidad_norm = densidades[o] / max_densidad
            eficiencia_norm = eficiencias[o] / max_eficiencia
            
            score_hibrido = (valor_norm * peso_valor + 
                           densidad_norm * peso_densidad + 
                           eficiencia_norm * peso_eficiencia)
            
            push!(ordenes_evaluadas, (o, valores[o], score_hibrido))
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
# ESTRATEGIA 7: OBJETIVO REVERSO
# ========================================

"""
Ingeniería reversa: Calcular ratio objetivo y construir hacia atrás
"""
function objetivo_reverso_grande(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    O, I = size(roi)
    P = size(upi, 1)
    
    # Estimar ratio objetivo basado en características de la instancia
    ratio_objetivo = if config.es_patologica
        UB / max(1, config.pasillos_teoricos * 1.5)  # Más conservador para patológicas
    else
        UB / max(1, config.pasillos_teoricos)
    end
    
    println("      🎯 Ratio objetivo estimado: $(round(ratio_objetivo, digits=2))")
    
    # Buscar combinaciones que se acerquen al ratio objetivo
    mejor_solucion = nothing
    mejor_diferencia = Inf
    
    # Probar diferentes números de pasillos
    for n_pasillos in 3:min(20, P)
        unidades_objetivo = Int(ceil(ratio_objetivo * n_pasillos))
        
        if LB <= unidades_objetivo <= UB
            # Buscar mejor combinación de pasillos
            pasillos_candidatos = obtener_mejores_pasillos(upi, n_pasillos)
            
            for pasillos_set in pasillos_candidatos[1:min(5, length(pasillos_candidatos))]
                ordenes_compatibles = encontrar_ordenes_compatibles(pasillos_set, roi, upi)
                
                if !isempty(ordenes_compatibles)
                    # Buscar combinación de órdenes que se acerque al objetivo
                    ordenes_por_valor = [(o, sum(roi[o, :])) for o in ordenes_compatibles]
                    sort!(ordenes_por_valor, by=x -> x[2], rev=true)
                    
                    # Búsqueda greedy hacia el objetivo
                    ordenes_seleccionadas = Set{Int}()
                    valor_actual = 0
                    
                    for (o, valor) in ordenes_por_valor
                        if valor_actual + valor <= unidades_objetivo && valor_actual + valor <= UB
                            push!(ordenes_seleccionadas, o)
                            valor_actual += valor
                        end
                    end
                    
                    if valor_actual >= LB
                        diferencia = abs(valor_actual - unidades_objetivo)
                        if diferencia < mejor_diferencia
                            candidato = Solucion(ordenes_seleccionadas, pasillos_set)
                            if es_factible(candidato, roi, upi, LB, UB, config)
                                mejor_solucion = candidato
                                mejor_diferencia = diferencia
                            end
                        end
                    end
                end
            end
        end
    end
    
    return mejor_solucion
end

# ========================================
# ESTRATEGIA 8: CONSOLIDACIÓN AGRESIVA
# ========================================

"""
Consolidación agresiva: Minimizar pasillos maximizando utilización
"""
function consolidacion_agresiva_grande(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    P = size(upi, 1)
    
    # Para patológicas, ser más agresivo en consolidación
    max_pasillos = if config.es_patologica
        min(P, max(3, Int(ceil(config.pasillos_teoricos * 1.2))))
    else
        min(P, max(5, Int(ceil(config.pasillos_teoricos * 1.5))))
    end
    
    mejor_solucion = nothing
    mejor_ratio = 0.0
    
    # Probar diferentes niveles de consolidación
    for n_pasillos in 3:max_pasillos
        # Obtener mejores pasillos por algoritmo de set cover
        pasillos_set = set_cover_pasillos(roi, upi, n_pasillos)
        
        if !isempty(pasillos_set)
            # Encontrar TODAS las órdenes compatibles
            ordenes_compatibles = encontrar_ordenes_compatibles(pasillos_set, roi, upi)
            
            if !isempty(ordenes_compatibles)
                # Tomar las mejores órdenes por valor
                ordenes_por_valor = [(o, sum(roi[o, :])) for o in ordenes_compatibles]
                sort!(ordenes_por_valor, by=x -> x[2], rev=true)
                
                ordenes_seleccionadas = Set{Int}()
                valor_actual = 0
                
                for (o, valor) in ordenes_por_valor
                    if valor_actual + valor <= UB
                        push!(ordenes_seleccionadas, o)
                        valor_actual += valor
                    end
                end
                
                if valor_actual >= LB
                    candidato = Solucion(ordenes_seleccionadas, pasillos_set)
                    if es_factible(candidato, roi, upi, LB, UB, config)
                        ratio = evaluar(candidato, roi)
                        if ratio > mejor_ratio
                            mejor_solucion = candidato
                            mejor_ratio = ratio
                        end
                    end
                end
            end
        end
    end
    
    return mejor_solucion
end

# ========================================
# FUNCIONES AUXILIARES
# ========================================

"""
Obtiene mejores combinaciones de pasillos por capacidad
"""
function obtener_mejores_pasillos(upi::Matrix{Int}, n_pasillos::Int)
    P = size(upi, 1)
    
    # Evaluar pasillos por capacidad total
    pasillos_por_capacidad = [(p, sum(upi[p, :])) for p in 1:P]
    sort!(pasillos_por_capacidad, by=x -> x[2], rev=true)
    
    # Tomar top pasillos
    top_pasillos = [pasillos_por_capacidad[i][1] for i in 1:min(n_pasillos*3, P)]
    
    # Generar combinaciones (limitar para escalabilidad)
    combinaciones = []
    
    if n_pasillos <= 5
        # Para pocos pasillos, explorar más combinaciones
        for combo in combinations(top_pasillos[1:min(15, length(top_pasillos))], n_pasillos)
            push!(combinaciones, Set(combo))
        end
    else
        # Para muchos pasillos, usar greedy
        push!(combinaciones, Set(top_pasillos[1:n_pasillos]))
    end
    
    return combinaciones
end

"""
Set cover aproximado para selección de pasillos
"""
function set_cover_pasillos(roi::Matrix{Int}, upi::Matrix{Int}, max_pasillos::Int)
    O, I = size(roi)
    P = size(upi, 1)
    
    # Calcular demanda total por ítem
    demanda_total = zeros(Int, I)
    for o in 1:O
        for i in 1:I
            demanda_total[i] += roi[o, i]
        end
    end
    
    # Algoritmo greedy de set cover
    pasillos_seleccionados = Set{Int}()
    demanda_restante = copy(demanda_total)
    
    for _ in 1:max_pasillos
        if !any(demanda_restante .> 0)
            break
        end
        
        mejor_pasillo = 0
        mejor_cobertura = 0
        
        for p in 1:P
            if !(p in pasillos_seleccionados)
                cobertura = sum(min(upi[p, i], demanda_restante[i]) for i in 1:I)
                if cobertura > mejor_cobertura
                    mejor_pasillo = p
                    mejor_cobertura = cobertura
                end
            end
        end
        
        if mejor_pasillo > 0
            push!(pasillos_seleccionados, mejor_pasillo)
            for i in 1:I
                demanda_restante[i] = max(0, demanda_restante[i] - upi[mejor_pasillo, i])
            end
        else
            break
        end
    end
    
    return pasillos_seleccionados
end

"""
Constructiva de emergencia garantizada
"""
function constructiva_emergencia_grande(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    O = size(roi, 1)
    
    # Greedy súper simple por valor
    ordenes_por_valor = [(o, sum(roi[o, :])) for o in 1:O]
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