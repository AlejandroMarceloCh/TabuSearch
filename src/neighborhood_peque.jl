# neighborhood_peque.jl
# ========================================
# GENERACIÓN DE VECINOS PARA INSTANCIAS PEQUEÑAS Y MEDIANAS
# ========================================

# ========================================
# ANÁLISIS DE CRITICIDAD
# ========================================

"""
Analiza la criticidad de órdenes e ítems en la solución actual
Retorna información sobre elementos críticos para la factibilidad
"""
function analizar_criticidad(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int})
    I = size(roi, 2)
    
    # Calcular demanda actual
    demanda_actual = zeros(Int, I)
    for o in sol.ordenes
        demanda_actual .+= roi[o, :]
    end
    
    # Calcular cobertura actual
    cobertura_actual = zeros(Int, I)
    for p in sol.pasillos
        cobertura_actual .+= upi[p, :]
    end
    
    # Identificar ítems críticos (poca holgura)
    items_criticos = Set{Int}()
    for i in 1:I
        if demanda_actual[i] > 0
            holgura = cobertura_actual[i] - demanda_actual[i]
            if holgura <= 1  # Muy poca holgura
                push!(items_criticos, i)
            end
        end
    end
    
    # Identificar órdenes críticas (afectan ítems críticos)
    ordenes_criticas = Set{Int}()
    for o in sol.ordenes
        for i in items_criticos
            if roi[o, i] > 0
                push!(ordenes_criticas, o)
                break
            end
        end
    end
    
    return items_criticos, ordenes_criticas
end

# ========================================
# MOVIMIENTOS BÁSICOS
# ========================================

"""
Movimiento de intercambio inteligente: sustituye una orden por otra
considerando la criticidad de los elementos
"""
function intercambio_inteligente(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, 
                               LB::Int, UB::Int, max_intentos::Int=15)
    vecinos = Solucion[]
    O = size(roi, 1)
    ordenes_actuales = collect(sol.ordenes)
    candidatos_externos = setdiff(1:O, sol.ordenes)
    
    if isempty(ordenes_actuales) || isempty(candidatos_externos)
        return vecinos
    end
    
    items_criticos, ordenes_criticas = analizar_criticidad(sol, roi, upi)
    
    for _ in 1:max_intentos
        # Preferir remover órdenes no críticas
        ordenes_no_criticas = setdiff(ordenes_actuales, ordenes_criticas)
        o_out = if !isempty(ordenes_no_criticas)
            rand(ordenes_no_criticas)
        else
            rand(ordenes_actuales)
        end
        
        # Preferir agregar órdenes que cubran ítems críticos
        candidatos_beneficiosos = Int[]
        for o in candidatos_externos
            for i in items_criticos
                if roi[o, i] > 0
                    push!(candidatos_beneficiosos, o)
                    break
                end
            end
        end
        
        o_in = if !isempty(candidatos_beneficiosos)
            rand(candidatos_beneficiosos)
        else
            rand(candidatos_externos)
        end
        
        # Crear nueva solución
        nuevas_ordenes = copy(sol.ordenes)
        delete!(nuevas_ordenes, o_out)
        push!(nuevas_ordenes, o_in)
        
        # Validar antes de calcular pasillos
        if validar_factibilidad_basica(nuevas_ordenes, roi, upi, LB, UB)
            nuevos_pasillos = calcular_pasillos_optimo(nuevas_ordenes, roi, upi)
            nueva_sol = Solucion(nuevas_ordenes, nuevos_pasillos)
            
            if es_factible_rapido(nueva_sol, roi, upi, LB, UB)
                push!(vecinos, nueva_sol)
            end
        end
    end
    
    return vecinos
end

"""
Movimiento de crecimiento controlado: agrega órdenes sin violar restricciones
"""
function crecimiento_controlado(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, 
                              LB::Int, UB::Int, max_intentos::Int=15)
    vecinos = Solucion[]
    O = size(roi, 1)
    candidatos_externos = setdiff(1:O, sol.ordenes)
    
    if isempty(candidatos_externos)
        return vecinos
    end
    
    # Calcular demanda actual
    I = size(roi, 2)
    demanda_actual = zeros(Int, I)
    for o in sol.ordenes
        demanda_actual .+= roi[o, :]
    end
    total_actual = sum(demanda_actual)
    
    # Identificar candidatos seguros (que no rompan UB)
    candidatos_seguros = Int[]
    for o in candidatos_externos
        demanda_extra = sum(roi[o, :])
        if total_actual + demanda_extra <= UB
            push!(candidatos_seguros, o)
        end
    end
    
    # Generar vecinos por adición
    intentos_realizados = 0
    for o_new in candidatos_seguros
        if intentos_realizados >= max_intentos
            break
        end
        intentos_realizados += 1
        
        nuevas_ordenes = copy(sol.ordenes)
        push!(nuevas_ordenes, o_new)
        
        if validar_factibilidad_basica(nuevas_ordenes, roi, upi, LB, UB)
            nuevos_pasillos = calcular_pasillos_optimo(nuevas_ordenes, roi, upi)
            nueva_sol = Solucion(nuevas_ordenes, nuevos_pasillos)
            
            if es_factible_rapido(nueva_sol, roi, upi, LB, UB)
                push!(vecinos, nueva_sol)
            end
        end
    end
    
    return vecinos
end

"""
Movimiento de reducción controlada: elimina órdenes manteniendo factibilidad
"""
function reduccion_controlada(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, 
                            LB::Int, UB::Int, max_intentos::Int=10)
    vecinos = Solucion[]
    ordenes_actuales = collect(sol.ordenes)
    
    if length(ordenes_actuales) <= 2
        return vecinos  # No reducir demasiado
    end
    
    # Calcular demanda actual
    I = size(roi, 2)
    demanda_actual = zeros(Int, I)
    for o in sol.ordenes
        demanda_actual .+= roi[o, :]
    end
    total_actual = sum(demanda_actual)
    
    items_criticos, ordenes_criticas = analizar_criticidad(sol, roi, upi)
    
    # Preferir remover órdenes no críticas
    ordenes_no_criticas = setdiff(ordenes_actuales, ordenes_criticas)
    candidatos_remocion = !isempty(ordenes_no_criticas) ? ordenes_no_criticas : ordenes_actuales
    
    intentos_realizados = 0
    for o_rem in candidatos_remocion
        if intentos_realizados >= max_intentos
            break
        end
        intentos_realizados += 1
        
        demanda_perdida = sum(roi[o_rem, :])
        
        # Verificar que no caigamos por debajo de LB
        if total_actual - demanda_perdida >= LB
            nuevas_ordenes = setdiff(sol.ordenes, [o_rem])
            
            if validar_factibilidad_basica(nuevas_ordenes, roi, upi, LB, UB)
                nuevos_pasillos = calcular_pasillos_optimo(nuevas_ordenes, roi, upi)
                nueva_sol = Solucion(nuevas_ordenes, nuevos_pasillos)
                
                if es_factible_rapido(nueva_sol, roi, upi, LB, UB)
                    push!(vecinos, nueva_sol)
                end
            end
        end
    end
    
    return vecinos
end

# ========================================
# MOVIMIENTOS AVANZADOS
# ========================================

"""
Intercambio múltiple: cambia varias órdenes simultáneamente
"""
function intercambio_multiple(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, 
                            LB::Int, UB::Int, intensidad::Float64=0.3)
    vecinos = Solucion[]
    O = size(roi, 1)
    ordenes_actuales = collect(sol.ordenes)
    candidatos_externos = setdiff(1:O, sol.ordenes)
    
    if length(ordenes_actuales) < 3 || isempty(candidatos_externos)
        return vecinos
    end
    
    # Determinar número de cambios
    n_cambios = max(1, Int(ceil(length(ordenes_actuales) * intensidad)))
    n_cambios = min(n_cambios, 3)  # Máximo 3 cambios para instancias pequeñas/medianas
    
    for _ in 1:5  # Múltiples intentos
        # Seleccionar órdenes a cambiar
        indices_cambio = Random.randperm(length(ordenes_actuales))[1:min(n_cambios, length(ordenes_actuales))]
        ordenes_a_cambiar = ordenes_actuales[indices_cambio]
        
        # Crear nueva solución base
        nuevas_ordenes = setdiff(sol.ordenes, ordenes_a_cambiar)
        
        # Agregar nuevas órdenes
        n_agregar = min(length(ordenes_a_cambiar) + rand(-1:1), length(candidatos_externos))
        if n_agregar > 0
            indices_nuevas = Random.randperm(length(candidatos_externos))[1:n_agregar]
            ordenes_nuevas = candidatos_externos[indices_nuevas]
            for o in ordenes_nuevas
                push!(nuevas_ordenes, o)
            end
        end
        
        # Validar y crear vecino
        if validar_factibilidad_basica(nuevas_ordenes, roi, upi, LB, UB)
            nuevos_pasillos = calcular_pasillos_optimo(nuevas_ordenes, roi, upi)
            candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
            
            if es_factible_rapido(candidato, roi, upi, LB, UB)
                push!(vecinos, candidato)
            end
        end
    end
    
    return vecinos
end

"""
Optimización local de pasillos: reoptimiza pasillos para las órdenes actuales
"""
function optimizar_pasillos_localmente(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, 
                                     LB::Int, UB::Int)
    vecinos = Solucion[]
    
    # Recalcular pasillos óptimos
    nuevos_pasillos = calcular_pasillos_optimo(sol.ordenes, roi, upi)
    
    # Si son diferentes, crear nuevo vecino
    if nuevos_pasillos != sol.pasillos
        nueva_sol = Solucion(sol.ordenes, nuevos_pasillos)
        if es_factible_rapido(nueva_sol, roi, upi, LB, UB)
            push!(vecinos, nueva_sol)
        end
    end
    
    return vecinos
end

# ========================================
# FUNCIÓN PRINCIPAL DE GENERACIÓN DE VECINOS
# ========================================

"""
Función principal que genera vecinos para instancias pequeñas y medianas
Coordina todos los tipos de movimientos según la estrategia adaptativa
"""
function generar_vecinos_mejorado(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, 
                                LB::Int, UB::Int; max_vecinos::Int=50, control=nothing)
    
    tipo = clasificar_instancia(roi, upi)
    vecinos = Solucion[]
    
    # Ajustar parámetros según tipo de instancia
    if tipo == :pequeña
        max_intercambios = 15
        max_crecimientos = 10
        max_reducciones = 8
        usar_movimientos_avanzados = true
    else  # :mediana
        max_intercambios = 20
        max_crecimientos = 15
        max_reducciones = 10
        usar_movimientos_avanzados = true
    end
    
    # Ajustar según control adaptativo
    if control !== nothing
        factor = control.intensidad == :diversificar ? 1.5 : 1.0
        max_intercambios = Int(ceil(max_intercambios * factor))
        max_crecimientos = Int(ceil(max_crecimientos * factor))
        max_reducciones = Int(ceil(max_reducciones * factor))
    end
    
    # 1. Intercambios inteligentes (40% del esfuerzo)
    vecinos_intercambio = intercambio_inteligente(sol, roi, upi, LB, UB, max_intercambios)
    append!(vecinos, vecinos_intercambio)
    
    if length(vecinos) >= max_vecinos
        return unique_vecinos(vecinos)[1:max_vecinos]
    end
    
    # 2. Crecimiento controlado (30% del esfuerzo)
    vecinos_crecimiento = crecimiento_controlado(sol, roi, upi, LB, UB, max_crecimientos)
    append!(vecinos, vecinos_crecimiento)
    
    if length(vecinos) >= max_vecinos
        return unique_vecinos(vecinos)[1:max_vecinos]
    end
    
    # 3. Reducción controlada (20% del esfuerzo)
    vecinos_reduccion = reduccion_controlada(sol, roi, upi, LB, UB, max_reducciones)
    append!(vecinos, vecinos_reduccion)
    
    # 4. Movimientos avanzados (10% del esfuerzo) - solo si tenemos espacio
    if usar_movimientos_avanzados && length(vecinos) < max_vecinos * 0.8
        # Intercambio múltiple
        intensidad = control !== nothing && control.intensidad == :diversificar ? 0.4 : 0.3
        vecinos_multiple = intercambio_multiple(sol, roi, upi, LB, UB, intensidad)
        append!(vecinos, vecinos_multiple)
        
        # Optimización de pasillos
        vecinos_pasillos = optimizar_pasillos_localmente(sol, roi, upi, LB, UB)
        append!(vecinos, vecinos_pasillos)
    end
    
    # Filtrar duplicados y retornar los mejores
    vecinos_unicos = unique_vecinos(vecinos)
    
    if length(vecinos_unicos) > max_vecinos
        # Ordenar por calidad y tomar los mejores
        vecinos_evaluados = [(v, evaluar(v, roi)) for v in vecinos_unicos]
        sort!(vecinos_evaluados, by=x -> x[2], rev=true)
        return [v[1] for v in vecinos_evaluados[1:max_vecinos]]
    end
    
    return vecinos_unicos
end

# ========================================
# FUNCIONES AUXILIARES
# ========================================

"""
Elimina vecinos duplicados basándose en las órdenes seleccionadas
"""
function unique_vecinos(vecinos::Vector{Solucion})
    if isempty(vecinos)
        return vecinos
    end
    
    unicos = Solucion[]
    ordenes_vistas = Set{Set{Int}}()
    
    for vecino in vecinos
        if !(vecino.ordenes in ordenes_vistas)
            push!(unicos, vecino)
            push!(ordenes_vistas, copy(vecino.ordenes))
        end
    end
    
    return unicos
end

"""
Validación específica para vecindarios de instancias pequeñas/medianas
"""
function validar_vecino_especifico(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, 
                                 LB::Int, UB::Int)
    # Validaciones adicionales específicas para instancias pequeñas/medianas
    if isempty(sol.ordenes) || isempty(sol.pasillos)
        return false
    end
    
    # Verificar que no tengamos demasiados pasillos (ineficiencia)
    max_pasillos_razonable = min(size(upi, 1), length(sol.ordenes) + 2)
    if length(sol.pasillos) > max_pasillos_razonable
        return false
    end
    
    return es_factible_rapido(sol, roi, upi, LB, UB)
end

"""
Estadísticas de generación de vecinos para debugging
"""
function estadisticas_vecindarios(vecinos::Vector{Solucion}, roi::Matrix{Int})
    if isempty(vecinos)
        return (total=0, obj_promedio=0.0, obj_mejor=0.0, obj_peor=0.0)
    end
    
    objetivos = [evaluar(v, roi) for v in vecinos]
    
    return (
        total = length(vecinos),
        obj_promedio = sum(objetivos) / length(objetivos),
        obj_mejor = maximum(objetivos),
        obj_peor = minimum(objetivos)
    )
end