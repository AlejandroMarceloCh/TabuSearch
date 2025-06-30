# solution.jl
# ========================================
# CORE UNIFICADO Y DEFINITIVO - PROYECTO 20/20
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
# FUNCIÓN OBJETIVO
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

# ========================================
# CLASIFICACIÓN DE INSTANCIAS
# ========================================

"""
Clasifica el tipo de instancia según su tamaño
"""
function clasificar_instancia(roi::Matrix{Int}, upi::Matrix{Int})
    O, I = size(roi)
    P = size(upi, 1)
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

"""
Detecta si una instancia es patológica
"""
function es_instancia_patologica(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int)
    O, I, P = size(roi, 1), size(roi, 2), size(upi, 1)
    
    # Criterios para detectar patológicas
    ratio_ub_lb = UB / LB
    ratio_pasillos_ordenes = P / O
    demanda_total_posible = sum(roi)
    eficiencia_estimada = demanda_total_posible / P
    umbral_eficiencia = LB * 0.2
    
    # Es patológica si cumple al menos 2 de 3 criterios
    criterios = 0
    if ratio_ub_lb > 4.0; criterios += 1; end
    if ratio_pasillos_ordenes > 0.15; criterios += 1; end
    if eficiencia_estimada < umbral_eficiencia; criterios += 1; end
    
    es_patologica = criterios >= 2
    factor_gravedad = es_patologica ? min(3.0, 1.5 + (ratio_ub_lb - 4.0) / 6.0) : 1.0
    
    return es_patologica, factor_gravedad
end

# ========================================
# FACTIBILIDAD
# ========================================

"""
Verificación rápida de factibilidad - VERSIÓN DEFINITIVA
"""
# 4. En solution.jl - Optimización general de factibilidad
function es_factible_rapido(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int)
    if isempty(sol.pasillos) || isempty(sol.ordenes)
        return false
    end

    O, I = size(roi)
    
    # Verificación básica de límites
    demanda_total_global = sum(sum(roi[o, :]) for o in sol.ordenes)
    if !(LB ≤ demanda_total_global ≤ UB)
        return false
    end
    
    # Clasificar por tamaño para optimización
    es_gigante = (O > 1000 || I > 2000 || O * I > 5_000_000)
    es_muy_grande = I > 5000  # Muchos ítems
    
    if es_gigante
        # Para gigantes: usar diccionario y verificación selectiva
        items_con_demanda = Dict{Int, Int}()
        
        # Solo procesar ítems con demanda
        for o in sol.ordenes
            for i in 1:I
                if roi[o, i] > 0
                    items_con_demanda[i] = get(items_con_demanda, i, 0) + roi[o, i]
                end
            end
        end
        
        # Verificar cobertura
        if es_muy_grande && length(items_con_demanda) > 1000
            # Para instancias muy grandes: verificación por muestreo
            items_verificar = collect(keys(items_con_demanda))
            
            # Verificar todos los ítems con alta demanda
            for i in items_verificar
                demanda = items_con_demanda[i]
                if demanda > 10  # Umbral de demanda significativa
                    cobertura = sum(upi[p, i] for p in sol.pasillos if upi[p, i] > 0)
                    if demanda > cobertura
                        return false
                    end
                end
            end
            
            # Muestreo aleatorio para el resto
            items_baja_demanda = filter(i -> items_con_demanda[i] <= 10, items_verificar)
            if length(items_baja_demanda) > 100
                muestra = rand(items_baja_demanda, 100)
                for i in muestra
                    demanda = items_con_demanda[i]
                    cobertura = sum(upi[p, i] for p in sol.pasillos if upi[p, i] > 0)
                    if demanda > cobertura
                        return false
                    end
                end
            else
                # Verificar todos si son pocos
                for i in items_baja_demanda
                    demanda = items_con_demanda[i]
                    cobertura = sum(upi[p, i] for p in sol.pasillos if upi[p, i] > 0)
                    if demanda > cobertura
                        return false
                    end
                end
            end
        else
            # Verificación completa para gigantes con menos ítems
            for (i, demanda) in items_con_demanda
                cobertura = sum(upi[p, i] for p in sol.pasillos if upi[p, i] > 0)
                if demanda > cobertura
                    return false
                end
            end
        end
    else
        # Para instancias normales: verificación completa estándar
        demanda_por_item = zeros(Int, I)
        for o in sol.ordenes
            for i in 1:I
                demanda_por_item[i] += roi[o, i]
            end
        end
        
        for i in 1:I
            if demanda_por_item[i] > 0
                cobertura_disponible = sum(upi[p, i] for p in sol.pasillos; init=0)
                if demanda_por_item[i] > cobertura_disponible
                    return false
                end
            end
        end
    end
    
    return true
end


"""
Validación básica sin calcular pasillos completos
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
    
    # Verificar que cada ítem tenga cobertura suficiente
    for i in 1:I
        if demanda_por_item[i] > 0
            cobertura_maxima = sum(upi[p, i] for p in 1:P)
            if cobertura_maxima < demanda_por_item[i]
                return false
            end
        end
    end
    
    return true
end

# ========================================
# CÁLCULO DE PASILLOS
# ========================================

"""
Cálculo de pasillos óptimo - VERSIÓN UNIFICADA DEFINITIVA
"""
function calcular_pasillos_optimo(ordenes::Set{Int}, roi::Matrix{Int}, upi::Matrix{Int})
    if isempty(ordenes)
        return Set([1])
    end
    
    I = size(roi, 2)
    P = size(upi, 1)
    O = size(roi, 1)
    
    es_gigante = (O > 2000 || I > 5000 || O * I > 10_000_000)
    
    # Calcular demanda por ítem
    demanda_por_item = Dict{Int, Int}()
    for o in ordenes
        for i in 1:I
            if roi[o, i] > 0
                demanda_por_item[i] = get(demanda_por_item, i, 0) + roi[o, i]
            end
        end
    end
    
    pasillos_necesarios = Set{Int}()
    
    if es_gigante
        # Algoritmo optimizado para gigantes
        for (item, demanda) in demanda_por_item
            demanda_restante = demanda
            
            # Ordenar pasillos por capacidad para este ítem
            pasillos_item = [(p, upi[p, item]) for p in 1:P if upi[p, item] > 0]
            sort!(pasillos_item, by=x -> x[2], rev=true)
            
            for (p, capacidad) in pasillos_item
                if demanda_restante <= 0
                    break
                end
                
                push!(pasillos_necesarios, p)
                demanda_restante -= capacidad
                
                # Límite para gigantes
                if length(pasillos_necesarios) >= 50
                    break
                end
            end
        end
    else
        # Algoritmo estándar para instancias normales
        demanda_array = zeros(Int, I)
        for o in ordenes
            for i in 1:I
                demanda_array[i] += roi[o, i]
            end
        end
        
        capacidad_usada = zeros(Int, P)
        
        for i in 1:I
            if demanda_array[i] > 0
                mejor_pasillo = 0
                mejor_score = -1
                
                for p in 1:P
                    if upi[p, i] > 0
                        capacidad_restante = upi[p, i] - capacidad_usada[p]
                        if capacidad_restante >= demanda_array[i]
                            if capacidad_restante > mejor_score
                                mejor_score = capacidad_restante
                                mejor_pasillo = p
                            end
                        end
                    end
                end
                
                if mejor_pasillo > 0
                    push!(pasillos_necesarios, mejor_pasillo)
                    capacidad_usada[mejor_pasillo] += demanda_array[i]
                end
            end
        end
    end
    
    return isempty(pasillos_necesarios) ? Set([1]) : pasillos_necesarios
end

# ========================================
# UTILIDADES
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