# ========================================
# BASE.JL - FUNCIONES CAMALEÓNICAS ADAPTATIVAS
# Basado en métricas reales y restricciones exactas del PDF
# OBJETIVO: Maximizar Σ(unidades recolectadas) / Σ(pasillos visitados)
# ========================================

using Random
using StatsBase: sample


# ========================================
# ESTRUCTURA DE SOLUCIÓN
# ========================================
struct Solucion
    ordenes::Set{Int}          # Órdenes seleccionadas en el wave
    pasillos::Set{Int}         # Pasillos visitados para recolección
end

# Constructor de copia
function copiar_solucion(sol::Solucion)
    return Solucion(copy(sol.ordenes), copy(sol.pasillos))
end

# ========================================
# FUNCIÓN DE EVALUACIÓN (OBJETIVO DEL PDF)
# ========================================

"""
Calcula el ratio objetivo según PDF: Σ(unidades recolectadas) / Σ(pasillos visitados)
"""
function evaluar(sol::Solucion, roi::Matrix{Int})
    if isempty(sol.ordenes) || isempty(sol.pasillos)
        return 0.0
    end
    
    # Calcular total de unidades recolectadas
    unidades_totales = sum(sum(roi[o, :]) for o in sol.ordenes)
    
    # Número de pasillos visitados
    pasillos_visitados = length(sol.pasillos)
    
    # Ratio según PDF
    return unidades_totales / pasillos_visitados
end

# ========================================
# VERIFICACIÓN DE FACTIBILIDAD CAMALEÓNICA
# ========================================

"""
Verificación de factibilidad adaptativa según el nivel de precisión
Restricciones del PDF:
1. Para cada ítem i: cantidad recolectada = demanda total en órdenes
2. Cantidad recolectada ≤ capacidad disponible en pasillos  
3. LB ≤ total unidades ≤ UB
"""
function es_factible(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    
    # Verificación rápida de casos básicos
    if isempty(sol.ordenes) || isempty(sol.pasillos)
        return false
    end
    
    # Usar estrategia adaptativa según configuración
    if config.estrategia_factibilidad == :verificacion_exhaustiva
        return verificacion_exhaustiva(sol, roi, upi, LB, UB)
    elseif config.estrategia_factibilidad == :verificacion_robusta
        return verificacion_robusta(sol, roi, upi, LB, UB)
    elseif config.estrategia_factibilidad == :verificacion_inteligente
        return verificacion_inteligente(sol, roi, upi, LB, UB)
    elseif config.estrategia_factibilidad == :verificacion_muestreo
        return verificacion_muestreo(sol, roi, upi, LB, UB, config)
    else # :verificacion_rapida
        return verificacion_rapida(sol, roi, upi, LB, UB)
    end
end

# Sobrecarga para compatibilidad con código existente
function es_factible(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int)
    # Usar verificación rápida por defecto
    return verificacion_rapida(sol, roi, upi, LB, UB)
end

"""
Verificación exhaustiva para pequeñas (complejidad < 1000)
"""
function verificacion_exhaustiva(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int)
    O, I = size(roi)
    P, _ = size(upi)
    
    # 1. Verificar límites de unidades totales
    unidades_totales = sum(sum(roi[o, :]) for o in sol.ordenes)
    if unidades_totales < LB || unidades_totales > UB
        return false
    end
    
    # 2. Verificar restricción exacta: demanda = recolección por ítem
    for i in 1:I
        # Demanda total del ítem i en las órdenes seleccionadas
        demanda_item = sum(roi[o, i] for o in sol.ordenes)
        
        # Capacidad disponible del ítem i en pasillos seleccionados
        capacidad_item = sum(upi[p, i] for p in sol.pasillos)
        
        # Restricción del PDF: debe poder satisfacer exactamente la demanda
        if demanda_item > 0 && capacidad_item < demanda_item
            return false
        end
    end
    
    # 3. Verificar que no se exceda capacidad de ningún pasillo
    for p in sol.pasillos
        for i in 1:I
            demanda_item = sum(roi[o, i] for o in sol.ordenes)
            if demanda_item > upi[p, i]
                # En este caso, verificamos si otros pasillos pueden compensar
                capacidad_total_item = sum(upi[p2, i] for p2 in sol.pasillos)
                if demanda_item > capacidad_total_item
                    return false
                end
            end
        end
    end
    
    return true
end

"""
Verificación robusta para medianas patológicas
"""
function verificacion_robusta(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int)
    # Verificación exhaustiva + checks adicionales para patologías
    if !verificacion_exhaustiva(sol, roi, upi, LB, UB)
        return false
    end
    
    # Checks adicionales para casos patológicos
    I = size(roi, 2)
    
    # Verificar que al menos el 80% de los ítems con demanda puedan ser satisfechos
    items_con_demanda = 0
    items_satisfechos = 0
    
    for i in 1:I
        demanda_item = sum(roi[o, i] for o in sol.ordenes)
        if demanda_item > 0
            items_con_demanda += 1
            capacidad_item = sum(upi[p, i] for p in sol.pasillos)
            if capacidad_item >= demanda_item
                items_satisfechos += 1
            end
        end
    end
    
    if items_con_demanda > 0
        ratio_satisfaccion = items_satisfechos / items_con_demanda
        return ratio_satisfaccion >= 0.8
    end
    
    return true
end

"""
Verificación inteligente para medianas normales
"""
function verificacion_inteligente(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int)
    # Verificar límites básicos
    unidades_totales = sum(sum(roi[o, :]) for o in sol.ordenes)
    if unidades_totales < LB || unidades_totales > UB
        return false
    end
    
    # Muestreo inteligente de ítems críticos (top 20% por demanda)
    I = size(roi, 2)
    demandas_items = [(i, sum(roi[o, i] for o in sol.ordenes)) for i in 1:I]
    sort!(demandas_items, by=x -> x[2], rev=true)
    
    # Verificar top 20% de ítems
    n_criticos = max(1, I ÷ 5)
    for (i, demanda) in demandas_items[1:n_criticos]
        if demanda > 0
            capacidad = sum(upi[p, i] for p in sol.pasillos)
            if capacidad < demanda
                return false
            end
        end
    end
    
    return true
end

"""
Verificación por muestreo para grandes
"""
function verificacion_muestreo(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    # Verificar límites básicos
    unidades_totales = sum(sum(roi[o, :]) for o in sol.ordenes)
    if unidades_totales < LB || unidades_totales > UB
        return false
    end
    
    # Muestreo representativo (5% de ítems)
    I = size(roi, 2)
    n_muestra = max(5, I ÷ 20)
    
    items_muestra = sample(1:I, min(n_muestra, I), replace=false)
    
    for i in items_muestra
        demanda = sum(roi[o, i] for o in sol.ordenes)
        if demanda > 0
            capacidad = sum(upi[p, i] for p in sol.pasillos)
            if capacidad < demanda
                return false
            end
        end
    end
    
    return true
end

"""
Verificación rápida para enormes
"""
function verificacion_rapida(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int)
    # Solo verificar límites de unidades
    unidades_totales = sum(sum(roi[o, :]) for o in sol.ordenes)
    return LB <= unidades_totales <= UB
end

# ========================================
# CÁLCULO DE PASILLOS CAMALEÓNICO
# ========================================

"""
Calcula pasillos óptimos de forma adaptativa según la estrategia configurada
"""
function calcular_pasillos_optimos(ordenes::Set{Int}, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    if isempty(ordenes)
        return Set{Int}()
    end
    
    # Usar estrategia adaptativa
    if config.estrategia_pasillos == :algoritmo_optimo
        return algoritmo_optimo_pasillos(ordenes, roi, upi)
    elseif config.estrategia_pasillos == :greedy_inteligente
        return greedy_inteligente_pasillos(ordenes, roi, upi)
    elseif config.estrategia_pasillos == :sampling_optimizado
        return sampling_optimizado_pasillos(ordenes, roi, upi, config)
    else # :heuristicas_rapidas
        return heuristicas_rapidas_pasillos(ordenes, roi, upi, config)
    end
end

# Sobrecarga para compatibilidad
function calcular_pasillos_optimos(ordenes::Set{Int}, roi::Matrix{Int}, upi::Matrix{Int})
    # Usar algoritmo óptimo por defecto
    return algoritmo_optimo_pasillos(ordenes, roi, upi)
end

"""
Algoritmo óptimo para pequeñas (exacto)
"""
function algoritmo_optimo_pasillos(ordenes::Set{Int}, roi::Matrix{Int}, upi::Matrix{Int})
    if isempty(ordenes)
        return Set{Int}()
    end
    
    I = size(roi, 2)
    P = size(upi, 1)
    
    # Calcular demanda por ítem
    demanda = zeros(Int, I)
    for o in ordenes
        for i in 1:I
            demanda[i] += roi[o, i]
        end
    end
    
    # Algoritmo de cobertura mínima (exacto para pequeñas)
    pasillos_seleccionados = Set{Int}()
    demanda_restante = copy(demanda)
    
    while any(demanda_restante .> 0)
        mejor_pasillo = 0
        mejor_cobertura = 0
        
        # Encontrar pasillo que cubra más demanda restante
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
            # Actualizar demanda restante
            for i in 1:I
                demanda_restante[i] = max(0, demanda_restante[i] - upi[mejor_pasillo, i])
            end
        else
            break  # No se puede cubrir más demanda
        end
    end
    
    return pasillos_seleccionados
end

"""
Greedy inteligente para medianas
"""
function greedy_inteligente_pasillos(ordenes::Set{Int}, roi::Matrix{Int}, upi::Matrix{Int})
    if isempty(ordenes)
        return Set{Int}()
    end
    
    I = size(roi, 2)
    P = size(upi, 1)
    
    # Calcular demanda por ítem
    demanda = zeros(Int, I)
    for o in ordenes
        for i in 1:I
            demanda[i] += roi[o, i]
        end
    end
    
    # Greedy con ratio eficiencia/cobertura
    pasillos_seleccionados = Set{Int}()
    demanda_restante = copy(demanda)
    
    # Evaluar pasillos por eficiencia
    eficiencias = []
    for p in 1:P
        capacidad_total = sum(upi[p, :])
        items_cubiertos = count(upi[p, :] .> 0)
        eficiencia = items_cubiertos > 0 ? capacidad_total / items_cubiertos : 0
        push!(eficiencias, (p, eficiencia))
    end
    
    sort!(eficiencias, by=x -> x[2], rev=true)
    
    # Seleccionar pasillos por eficiencia hasta cubrir demanda
    for (p, _) in eficiencias
        if any(demanda_restante .> 0)
            cobertura = sum(min(upi[p, i], demanda_restante[i]) for i in 1:I)
            if cobertura > 0
                push!(pasillos_seleccionados, p)
                for i in 1:I
                    demanda_restante[i] = max(0, demanda_restante[i] - upi[p, i])
                end
            end
        else
            break
        end
    end
    
    return pasillos_seleccionados
end

"""
Sampling optimizado para grandes
"""
function sampling_optimizado_pasillos(ordenes::Set{Int}, roi::Matrix{Int}, upi::Matrix{Int}, config::ConfigInstancia)
    if isempty(ordenes)
        return Set{Int}()
    end
    
    I = size(roi, 2)
    P = size(upi, 1)
    
    # Para grandes, limitar búsqueda a mejores candidatos
    max_candidatos = min(P, 50)  # Máximo 50 pasillos a evaluar
    
    # Evaluar todos los pasillos por utilidad
    utilidades = []
    for p in 1:P
        utilidad = 0
        for o in ordenes
            for i in 1:I
                if roi[o, i] > 0
                    utilidad += min(upi[p, i], roi[o, i])
                end
            end
        end
        push!(utilidades, (p, utilidad))
    end
    
    sort!(utilidades, by=x -> x[2], rev=true)
    
    # Aplicar greedy en mejores candidatos
    candidatos = [utilidades[i][1] for i in 1:min(max_candidatos, length(utilidades))]
    
    return greedy_sobre_candidatos(ordenes, roi, upi, candidatos)
end

"""
Heurísticas rápidas para enormes
"""
function heuristicas_rapidas_pasillos(ordenes::Set{Int}, roi::Matrix{Int}, upi::Matrix{Int}, config::ConfigInstancia)
    if isempty(ordenes)
        return Set{Int}()
    end
    
    P = size(upi, 1)
    
    # Límite estricto para enormes
    max_pasillos = min(P, config.max_vecinos)
    
    # Selección rápida por capacidad total
    capacidades = [(p, sum(upi[p, :])) for p in 1:P]
    sort!(capacidades, by=x -> x[2], rev=true)
    
    # Tomar los mejores pasillos por capacidad
    pasillos_seleccionados = Set{Int}()
    for (p, _) in capacidades[1:min(max_pasillos, length(capacidades))]
        push!(pasillos_seleccionados, p)
    end
    
    return pasillos_seleccionados
end

"""
Aplica greedy sobre conjunto limitado de candidatos
"""
function greedy_sobre_candidatos(ordenes::Set{Int}, roi::Matrix{Int}, upi::Matrix{Int}, candidatos::Vector{Int})
    if isempty(ordenes) || isempty(candidatos)
        return Set{Int}()
    end
    
    I = size(roi, 2)
    
    # Calcular demanda
    demanda = zeros(Int, I)
    for o in ordenes
        for i in 1:I
            demanda[i] += roi[o, i]
        end
    end
    
    # Greedy sobre candidatos
    pasillos_seleccionados = Set{Int}()
    demanda_restante = copy(demanda)
    
    while any(demanda_restante .> 0) && length(pasillos_seleccionados) < length(candidatos)
        mejor_pasillo = 0
        mejor_cobertura = 0
        
        for p in candidatos
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

# ========================================
# FUNCIONES AUXILIARES
# ========================================

"""
Verifica si una orden es compatible con los pasillos dados
"""
function es_orden_compatible(orden::Int, pasillos::Set{Int}, roi::Matrix{Int}, upi::Matrix{Int})
    if isempty(pasillos)
        return false
    end
    
    I = size(roi, 2)
    
    # Verificar que todos los ítems de la orden puedan ser cubiertos
    for i in 1:I
        if roi[orden, i] > 0
            capacidad_total = sum(upi[p, i] for p in pasillos)
            if capacidad_total < roi[orden, i]
                return false
            end
        end
    end
    
    return true
end

"""
Encuentra órdenes compatibles con un conjunto de pasillos
"""
function encontrar_ordenes_compatibles(pasillos::Set{Int}, roi::Matrix{Int}, upi::Matrix{Int})
    if isempty(pasillos)
        return Set{Int}()
    end
    
    O = size(roi, 1)
    ordenes_compatibles = Set{Int}()
    
    for o in 1:O
        if es_orden_compatible(o, pasillos, roi, upi)
            push!(ordenes_compatibles, o)
        end
    end
    
    return ordenes_compatibles
end

"""
Muestra información de una solución
"""
function mostrar_solucion(sol::Solucion, roi::Matrix{Int}, titulo::String="")
    if !isempty(titulo)
        print("🎯 $titulo → ")
    end
    
    unidades = sum(sum(roi[o, :]) for o in sol.ordenes)
    ratio = evaluar(sol, roi)
    
    println("📦 $(length(sol.ordenes)) órdenes | 🚪 $(length(sol.pasillos)) pasillos | 📊 $unidades unidades | ⚡ Ratio: $(round(ratio, digits=3))")
end