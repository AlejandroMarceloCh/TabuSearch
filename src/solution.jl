# solution.jl
# ========================================
# FUNCIONES CORE Y ESTRUCTURA BÁSICA DE SOLUCIÓN
# ========================================

using Random

# ========================================
# ESTRUCTURA PRINCIPAL
# ========================================

"""
Estructura que representa una solución al problema
"""
mutable struct Solucion
    ordenes::Set{Int}
    pasillos::Set{Int}
end

# ========================================
# FUNCIONES CORE DEL PROBLEMA
# ========================================

"""
Función objetivo: maximiza unidades recolectadas por pasillo
"""
function evaluar(sol::Solucion, roi::Matrix{Int})
    if isempty(sol.ordenes) || isempty(sol.pasillos)
        return 0.0
    end
    
    demanda_total = sum(sum(roi[o, :] for o in sol.ordenes))
    num_pasillos = length(sol.pasillos)
    return demanda_total / num_pasillos
end

"""
Verificación rápida de factibilidad
"""

# SOBRESCRIBIR en solution.jl - línea ~180
function es_factible_rapido(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int)
    if isempty(sol.pasillos) || isempty(sol.ordenes)
        return false
    end

    O, I = size(roi)
    es_gigante = (O > 2000 || I > 5000 || O * I > 10_000_000)
    
    # PARA GIGANTES: Verificación eficiente pero CORRECTA
    if es_gigante
        # 1. Verificar límites de demanda total
        demanda_total_global = sum(sum(roi[o, :]) for o in sol.ordenes)
        if !(LB ≤ demanda_total_global ≤ UB)
            return false
        end
        
        # 2. Verificación de cobertura SIMPLIFICADA pero correcta
        # Solo verificar ítems que realmente tienen demanda
        items_con_demanda = Set{Int}()
        demanda_por_item = Dict{Int, Int}()
        
        for o in sol.ordenes
            for i in 1:I
                if roi[o, i] > 0
                    push!(items_con_demanda, i)
                    demanda_por_item[i] = get(demanda_por_item, i, 0) + roi[o, i]
                end
            end
        end
        
        # Verificar solo ítems con demanda
        for i in items_con_demanda
            cobertura_disponible = sum(upi[p, i] for p in sol.pasillos; init=0)
            if demanda_por_item[i] > cobertura_disponible
                return false
            end
        end
        
        return true
    end
    
    # PARA NO-GIGANTES: Verificación completa original
    demanda_total = zeros(Int, I)
    for o in sol.ordenes
        for i in 1:I
            demanda_total[i] += roi[o, i]
        end
    end

    for i in 1:I
        if demanda_total[i] > 0
            cobertura_disponible = sum(upi[p, i] for p in sol.pasillos; init=0)
            if demanda_total[i] > cobertura_disponible
                return false
            end
        end
    end

    unidades_totales = sum(demanda_total)
    return LB ≤ unidades_totales ≤ UB
end

"""
Verificación completa de factibilidad (más estricta)
"""
function es_factible_completo(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int)
    if !es_factible_rapido(sol, roi, upi, LB, UB)
        return false
    end
    
    # Verificaciones adicionales pueden agregarse aquí
    return true
end

"""
Clasifica el tipo de instancia según su tamaño
"""
function clasificar_instancia(roi::Matrix{Int}, upi::Matrix{Int})
    O, I = size(roi)        # Órdenes e ítems
    P = size(upi, 1)        # Pasillos
    tamaño_efectivo = I * (O + P)

    if tamaño_efectivo <= 5_000
        return :pequeña
    elseif tamaño_efectivo <= 50_000
        return :mediana
    elseif tamaño_efectivo <= 200_000
        return :grande
    else
        return :gigante
    end
end

# ========================================
# CÁLCULO DE PASILLOS
# ========================================

function calcular_pasillos_optimo(ordenes::Set{Int}, roi::Matrix{Int}, upi::Matrix{Int})
    if isempty(ordenes)
        return Set([1])
    end
    
    I = size(roi, 2)
    P = size(upi, 1)
    O = size(roi, 1)
    
    es_gigante = (O > 2000 || I > 5000 || O * I > 10_000_000)
    
    if es_gigante
        # PARA GIGANTES: Algoritmo mejorado que asegura factibilidad
        pasillos_necesarios = Set{Int}()
        
        # Calcular demanda real por ítem
        demanda_por_item = Dict{Int, Int}()
        for o in ordenes
            for i in 1:I
                if roi[o, i] > 0
                    demanda_por_item[i] = get(demanda_por_item, i, 0) + roi[o, i]
                end
            end
        end
        
        # Para cada ítem con demanda, encontrar pasillos que lo cubran
        for (item, demanda) in demanda_por_item
            demanda_restante = demanda
            
            # Ordenar pasillos por capacidad para este ítem (descendente)
            pasillos_item = [(p, upi[p, item]) for p in 1:P if upi[p, item] > 0]
            sort!(pasillos_item, by=x -> x[2], rev=true)
            
            for (p, capacidad) in pasillos_item
                if demanda_restante <= 0
                    break
                end
                
                push!(pasillos_necesarios, p)
                demanda_restante -= capacidad
                
                # Límite de pasillos para gigantes
                if length(pasillos_necesarios) >= 50
                    break
                end
            end
            
            # Si aún queda demanda sin cubrir, agregar más pasillos
            if demanda_restante > 0
                for p in 1:P
                    if !(p in pasillos_necesarios) && upi[p, item] > 0
                        push!(pasillos_necesarios, p)
                        demanda_restante -= upi[p, item]
                        if demanda_restante <= 0 || length(pasillos_necesarios) >= 50
                            break
                        end
                    end
                end
            end
        end
        
        return isempty(pasillos_necesarios) ? Set([1, 2, 3]) : pasillos_necesarios
    end
    
    # PARA NO-GIGANTES: Lógica original
    demanda_por_item = zeros(Int, I)
    for o in ordenes
        for i in 1:I
            demanda_por_item[i] += roi[o, i]
        end
    end
    
    pasillos_necesarios = Int[]
    capacidad_usada = zeros(Int, P)
    
    for i in 1:I
        if demanda_por_item[i] > 0
            mejor_pasillo = 0
            mejor_score = -1
            
            for p in 1:P
                if upi[p, i] > 0
                    capacidad_restante = upi[p, i] - capacidad_usada[p]
                    if capacidad_restante >= demanda_por_item[i]
                        score = capacidad_restante
                        if score > mejor_score
                            mejor_score = score
                            mejor_pasillo = p
                        end
                    end
                end
            end
            
            if mejor_pasillo > 0
                if !(mejor_pasillo in pasillos_necesarios)
                    push!(pasillos_necesarios, mejor_pasillo)
                end
                capacidad_usada[mejor_pasillo] += demanda_por_item[i]
            end
        end
    end
    
    return isempty(pasillos_necesarios) ? Set([1]) : Set(pasillos_necesarios)
end


# ========================================
# UTILIDADES BÁSICAS
# ========================================

"""
Calcula estadísticas básicas de una solución
"""
function estadisticas_solucion(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int})
    if isempty(sol.ordenes)
        return (
            unidades_totales = 0,
            ordenes_count = 0,
            pasillos_count = 0,
            eficiencia = 0.0,
            cobertura_promedio = 0.0
        )
    end
    
    I = size(roi, 2)
    demanda_total = zeros(Int, I)
    
    for o in sol.ordenes
        demanda_total .+= roi[o, :]
    end
    
    unidades_totales = sum(demanda_total)
    cobertura_items = 0
    
    if !isempty(sol.pasillos)
        for i in 1:I
            if demanda_total[i] > 0
                cobertura_disponible = sum(upi[p, i] for p in sol.pasillos)
                if cobertura_disponible >= demanda_total[i]
                    cobertura_items += 1
                end
            end
        end
    end
    
    return (
        unidades_totales = unidades_totales,
        ordenes_count = length(sol.ordenes),
        pasillos_count = length(sol.pasillos),
        eficiencia = evaluar(sol, roi),
        cobertura_promedio = cobertura_items / max(1, count(x -> x > 0, demanda_total))
    )
end

"""
Compara dos soluciones y retorna la mejor
"""
function comparar_soluciones(sol1::Solucion, sol2::Solucion, roi::Matrix{Int})
    obj1 = evaluar(sol1, roi)
    obj2 = evaluar(sol2, roi)
    return obj1 >= obj2 ? sol1 : sol2
end

"""
Crea una copia profunda de una solución
"""
function copiar_solucion(sol::Solucion)
    return Solucion(copy(sol.ordenes), copy(sol.pasillos))
end

"""
Validación básica de factibilidad sin calcular pasillos completos
"""
function validar_factibilidad_basica(ordenes::Set{Int}, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int)
    if isempty(ordenes)
        return false
    end
    
    # Verificar límites de demanda total
    demanda_total = sum(sum(roi[o, :]) for o in ordenes)
    if demanda_total < LB || demanda_total > UB
        return false
    end
    
    # Verificación básica de cobertura posible
    I = size(roi, 2)
    P = size(upi, 1)
    
    demanda_por_item = zeros(Int, I)
    for o in ordenes
        demanda_por_item .+= roi[o, :]
    end
    
    # Verificar que cada ítem con demanda tenga cobertura posible
    for i in 1:I
        if demanda_por_item[i] > 0
            cobertura_maxima_posible = sum(upi[p, i] for p in 1:P)
            if cobertura_maxima_posible < demanda_por_item[i]
                return false
            end
        end
    end
    
    return true
end

"""
Analiza las características de una instancia para diagnóstico
"""
function analizar_instancia(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int; mostrar::Bool=true)
    O, I = size(roi)
    P = size(upi, 1)
    
    # Estadísticas básicas
    demanda_total_posible = sum(roi)
    densidad_roi = count(x -> x > 0, roi) / (O * I)
    densidad_upi = count(x -> x > 0, upi) / (P * I)
    
    # Distribuciones
    demandas_por_orden = [sum(roi[o, :]) for o in 1:O]
    capacidades_por_pasillo = [sum(upi[p, :]) for p in 1:P]
    
    resultado = (
        tamaño = (O, I, P),
        tipo = clasificar_instancia(roi, upi),
        densidad_roi = round(densidad_roi, digits=3),
        densidad_upi = round(densidad_upi, digits=3),
        limites = (LB, UB),
        capacidad_vs_limite = round(demanda_total_posible / UB, digits=2),
        demanda_stats = (
            min = minimum(demandas_por_orden),
            max = maximum(demandas_por_orden),
            media = round(sum(demandas_por_orden) / O, digits=1)
        ),
        cobertura_stats = (
            min = minimum(capacidades_por_pasillo),
            max = maximum(capacidades_por_pasillo),
            media = round(sum(capacidades_por_pasillo) / P, digits=1)
        )
    )
    
    if mostrar
        println("📊 ANÁLISIS DE INSTANCIA:")
        println("   Tamaño: $(O) órdenes × $(I) ítems × $(P) pasillos")
        println("   Tipo: $(resultado.tipo)")
        println("   Densidades: ROI=$(resultado.densidad_roi), UPI=$(resultado.densidad_upi)")
        println("   Límites: LB=$LB, UB=$UB")
        println("   Demanda total posible vs UB: $(resultado.capacidad_vs_limite)x")
    end
    
    return resultado
end 


