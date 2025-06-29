# neighborhood_grande.jl
# ========================================
# GENERACIÓN DE VECINOS PARA INSTANCIAS GRANDES Y ENORMES
# ========================================

using Random

# ========================================
# VALIDACIÓN Y REPARACIÓN CON TOLERANCIA
# ========================================

include("pathological_fix.jl")

"""
Validación relajada que permite cierta violación temporal para facilitar
la generación de vecinos en instancias grandes
"""
function validar_factibilidad_relajada(ordenes::Set{Int}, roi::Matrix{Int}, upi::Matrix{Int}, 
                                      LB::Int, UB::Int; tolerancia_lb::Float64=0.05, 
                                      tolerancia_ub::Float64=0.1)
    if isempty(ordenes)
        return false
    end
    
    I = size(roi, 2)
    demanda_total = zeros(Int, I)
    
    for o in ordenes
        demanda_total .+= roi[o, :]
    end
    
    total_unidades = sum(demanda_total)
    
    # Relajar límites con tolerancia
    lb_relajado = LB * (1 - tolerancia_lb)
    ub_relajado = UB * (1 + tolerancia_ub)
    
    if total_unidades < lb_relajado || total_unidades > ub_relajado
        return false
    end
    
    return true
end


function reparar_solucion(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, 
                         LB::Int, UB::Int; max_iteraciones::Int=50)
    if es_factible_rapido(sol, roi, upi, LB, UB)
        return sol
    end
    
    # 🔥 OPTIMIZACIÓN PARA GIGANTES: Detectar instancia gigante y reducir iteraciones
    O, I = size(roi)
    es_gigante = (O > 2000 || I > 5000 || O * I > 10_000_000)
    
    if es_gigante
        max_iteraciones = 5  # ⚡ DRÁSTICAMENTE reducido para gigantes
    elseif O > 500 || I > 1000
        max_iteraciones = 15  # Para instancias grandes normales
    end
    
    ordenes_reparadas = copy(sol.ordenes)
    
    for iter in 1:max_iteraciones
        if isempty(ordenes_reparadas)
            break
        end
        
        # 🔥 OPTIMIZACIÓN: Validación rápida antes de cálculos costosos
        demanda_total = sum(sum(roi[o, :]) for o in ordenes_reparadas)
        if demanda_total < LB || demanda_total > UB
            # Eliminar orden aleatoria si está fuera de límites
            if length(ordenes_reparadas) > 1
                orden_aleatoria = rand(collect(ordenes_reparadas))
                delete!(ordenes_reparadas, orden_aleatoria)
            else
                break
            end
            continue
        end
        
        # Solo hacer cálculo costoso si la validación básica pasa
        pasillos_actuales = calcular_pasillos_optimo(ordenes_reparadas, roi, upi)
        sol_candidata = Solucion(ordenes_reparadas, pasillos_actuales)
        
        if es_factible_rapido(sol_candidata, roi, upi, LB, UB)
            return sol_candidata
        end
        
        # 🔥 OPTIMIZACIÓN: Remoción más agresiva para gigantes
        if es_gigante && length(ordenes_reparadas) > 2
            # Remover 2-3 órdenes de una vez para gigantes
            n_remover = min(rand(2:3), length(ordenes_reparadas) - 1)
            ordenes_lista = collect(ordenes_reparadas)
            for _ in 1:n_remover
                if !isempty(ordenes_lista)
                    orden_remover = rand(ordenes_lista)
                    delete!(ordenes_reparadas, orden_remover)
                    filter!(x -> x != orden_remover, ordenes_lista)
                end
            end
        else
            # Remoción normal para instancias menores
            if length(ordenes_reparadas) > 1
                orden_aleatoria = rand(collect(ordenes_reparadas))
                delete!(ordenes_reparadas, orden_aleatoria)
            end
        end
    end
    
    return nothing
end



# ========================================
# MOVIMIENTOS ESPECÍFICOS PARA INSTANCIAS GRANDES
# ========================================

"""
Mutación múltiple: cambia varias órdenes simultáneamente con mayor intensidad
"""
function mutacion_multiple(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, 
                          LB::Int, UB::Int; intensidad::Float64=0.25)
    vecinos = Solucion[]
    O, I = size(roi)
    ordenes_actuales = collect(sol.ordenes)
    n_ordenes = length(ordenes_actuales)
    
    if n_ordenes < 2
        return vecinos
    end
    
    # 🔥 OPTIMIZACIÓN: Intensidad reducida para gigantes
    es_gigante = (O > 2000 || I > 5000 || O * I > 10_000_000)
    
    if es_gigante
        intensidad = 0.15  # Reducido de 0.25 a 0.15 para gigantes
        max_intentos = 4   # Reducido de 8 a 4 para gigantes
    else
        max_intentos = 8   # Original para no-gigantes
    end
    
    n_cambios = max(2, Int(ceil(n_ordenes * intensidad)))
    n_cambios = min(n_cambios, max(5, n_ordenes ÷ 2))
    
    for _ in 1:max_intentos
        indices_cambio = randperm(length(ordenes_actuales))[1:min(n_cambios, length(ordenes_actuales))]
        ordenes_a_cambiar = ordenes_actuales[indices_cambio]
        
        nuevas_ordenes = setdiff(sol.ordenes, ordenes_a_cambiar)
        candidatos = setdiff(1:O, nuevas_ordenes)
        
        if !isempty(candidatos)
            n_agregar = min(length(ordenes_a_cambiar) + rand(-2:2), length(candidatos))
            if n_agregar > 0
                indices_nuevas = randperm(length(candidatos))[1:n_agregar]
                ordenes_nuevas = candidatos[indices_nuevas]
                for o in ordenes_nuevas
                    push!(nuevas_ordenes, o)
                end
            end
        end
        
        if validar_factibilidad_relajada(nuevas_ordenes, roi, upi, LB, UB)
            nuevos_pasillos = calcular_pasillos_optimo(nuevas_ordenes, roi, upi)
            candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
            
            if !es_factible_rapido(candidato, roi, upi, LB, UB)
                candidato = reparar_solucion(candidato, roi, upi, LB, UB)
            end
            
            if candidato !== nothing && es_factible_rapido(candidato, roi, upi, LB, UB)
                push!(vecinos, candidato)
            end
        end
    end
    
    return vecinos
end

"""

"""
function reconstruccion_parcial(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int)
    vecinos = Solucion[]
    ordenes_actuales = collect(sol.ordenes)
    
    if length(ordenes_actuales) < 4
        return vecinos
    end
    
    # 🔥 OPTIMIZACIÓN: Eliminar ordenamiento costoso - usar muestreo aleatorio
    O, I = size(roi)
    es_gigante = (O > 2000 || I > 5000 || O * I > 10_000_000)
    
    if es_gigante
        # Para gigantes: muestreo aleatorio simple sin ordenamiento
        porcentaje_mantener = 0.6 + rand() * 0.2  # 60-80%
        n_mantener = Int(ceil(length(ordenes_actuales) * porcentaje_mantener))
        
        # Selección aleatoria sin ordenamiento
        indices_mantener = randperm(length(ordenes_actuales))[1:n_mantener]
        ordenes_nucleo = Set(ordenes_actuales[indices_mantener])
    else
        # Para no-gigantes: usar lógica original con ordenamiento
        valores_ordenes = [(o, sum(roi[o, :])) for o in ordenes_actuales]
        sort!(valores_ordenes, by=x -> x[2], rev=true)
        
        porcentaje_mantener = 0.5 + rand() * 0.2
        n_mantener = Int(ceil(length(ordenes_actuales) * porcentaje_mantener))
        ordenes_nucleo = Set([v[1] for v in valores_ordenes[1:n_mantener]])
    end
    
    # Reconstruir (lógica simplificada para gigantes)
    for intento in 1:(es_gigante ? 2 : 3)  # Menos intentos para gigantes
        ordenes_trabajo = copy(ordenes_nucleo)
        candidatos = setdiff(1:O, ordenes_trabajo)
        
        # 🔥 OPTIMIZACIÓN: Construcción más simple para gigantes
        if es_gigante
            # Para gigantes: agregar órdenes aleatoriamente hasta límites
            while !isempty(candidatos)
                demanda_actual = sum(sum(roi[o, :]) for o in ordenes_trabajo)
                if demanda_actual >= UB * 0.95  # Parar cerca del límite
                    break
                end
                
                candidato = rand(candidatos)
                demanda_extra = sum(roi[candidato, :])
                if demanda_actual + demanda_extra <= UB
                    push!(ordenes_trabajo, candidato)
                end
                
                filter!(x -> x != candidato, candidatos)
                
                # Parar si tenemos suficiente
                if demanda_actual + demanda_extra >= LB && rand() < 0.4
                    break
                end
            end
        else
            # Para no-gigantes: usar lógica original más compleja
            while !isempty(candidatos)
                demanda_actual = sum(sum(roi[o, :]) for o in ordenes_trabajo)
                if demanda_actual >= UB
                    break
                end
                
                candidatos_validos = Int[]
                for c in candidatos
                    demanda_extra = sum(roi[c, :])
                    if demanda_actual + demanda_extra <= UB * 1.05
                        push!(candidatos_validos, c)
                    end
                end
                
                if isempty(candidatos_validos)
                    break
                end
                
                candidato_elegido = rand(candidatos_validos)
                push!(ordenes_trabajo, candidato_elegido)
                filter!(x -> x != candidato_elegido, candidatos)
                
                if sum(sum(roi[o, :]) for o in ordenes_trabajo) >= LB && rand() < 0.3
                    break
                end
            end
        end
        
        # Validar y crear vecino
        if validar_factibilidad_relajada(ordenes_trabajo, roi, upi, LB, UB)
            nuevos_pasillos = calcular_pasillos_optimo(ordenes_trabajo, roi, upi)
            candidato = Solucion(ordenes_trabajo, nuevos_pasillos)
            
            if !es_factible_rapido(candidato, roi, upi, LB, UB)
                candidato = reparar_solucion(candidato, roi, upi, LB, UB)
            end
            
            if candidato !== nothing && es_factible_rapido(candidato, roi, upi, LB, UB)
                push!(vecinos, candidato)
            end
        end
    end
    
    return vecinos
end


# ========================================
# MOVIMIENTOS BÁSICOS CON TOLERANCIA
# ========================================

"""
Intercambio inteligente con tolerancia para instancias grandes
"""
function intercambio_inteligente_tolerante(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, 
                                         LB::Int, UB::Int)
    vecinos = Solucion[]
    O = size(roi, 1)
    ordenes_actuales = collect(sol.ordenes)
    candidatos_externos = setdiff(1:O, sol.ordenes)
    
    # Más intentos para instancias grandes
    for _ in 1:20
        if isempty(ordenes_actuales) || isempty(candidatos_externos)
            break
        end
        
        o_out = rand(ordenes_actuales)
        o_in = rand(candidatos_externos)
        
        nuevas_ordenes = copy(sol.ordenes)
        delete!(nuevas_ordenes, o_out)
        push!(nuevas_ordenes, o_in)
        
        # Usar validación relajada
        if validar_factibilidad_relajada(nuevas_ordenes, roi, upi, LB, UB)
            nuevos_pasillos = calcular_pasillos_optimo(nuevas_ordenes, roi, upi)
            candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
            
            # Reparar si es necesario
            if !es_factible_rapido(candidato, roi, upi, LB, UB)
                candidato = reparar_solucion(candidato, roi, upi, LB, UB)
            end
            
            if es_factible_rapido(candidato, roi, upi, LB, UB)
                push!(vecinos, candidato)
            end
        end
    end
    
    return vecinos
end

"""
Crecimiento controlado con tolerancia para instancias grandes
"""
function crecimiento_controlado_tolerante(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, 
                                        LB::Int, UB::Int)
    vecinos = Solucion[]
    O = size(roi, 1)
    candidatos_externos = setdiff(1:O, sol.ordenes)
    
    for _ in 1:15
        if isempty(candidatos_externos)
            break
        end
        
        o_new = rand(candidatos_externos)
        nuevas_ordenes = copy(sol.ordenes)
        push!(nuevas_ordenes, o_new)
        
        if validar_factibilidad_relajada(nuevas_ordenes, roi, upi, LB, UB)
            nuevos_pasillos = calcular_pasillos_optimo(nuevas_ordenes, roi, upi)
            candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
            
            if !es_factible_rapido(candidato, roi, upi, LB, UB)
                candidato = reparar_solucion(candidato, roi, upi, LB, UB)
            end
            
            if es_factible_rapido(candidato, roi, upi, LB, UB)
                push!(vecinos, candidato)
            end
        end
    end
    
    return vecinos
end

"""
Reducción controlada con tolerancia para instancias grandes
"""
function reduccion_controlada_tolerante(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, 
                                      LB::Int, UB::Int)
    vecinos = Solucion[]
    ordenes_actuales = collect(sol.ordenes)
    
    if length(ordenes_actuales) <= 3  # Mantener mínimo mayor para instancias grandes
        return vecinos
    end
    
    for _ in 1:12
        o_rem = rand(ordenes_actuales)
        nuevas_ordenes = setdiff(sol.ordenes, [o_rem])
        
        if validar_factibilidad_relajada(nuevas_ordenes, roi, upi, LB, UB)
            nuevos_pasillos = calcular_pasillos_optimo(nuevas_ordenes, roi, upi)
            candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
            
            if !es_factible_rapido(candidato, roi, upi, LB, UB)
                candidato = reparar_solucion(candidato, roi, upi, LB, UB)
            end
            
            if es_factible_rapido(candidato, roi, upi, LB, UB)
                push!(vecinos, candidato)
            end
        end
    end
    
    return vecinos
end

# ========================================
# FUNCIÓN PRINCIPAL CON GESTIÓN ADAPTATIVA
# ========================================

"""
REEMPLAZAR la función generar_vecinos_con_tolerancia existente
SOBRESCRIBIR: generar_vecinos_con_tolerancia con movimientos completos para patológicas
"""
function generar_vecinos_con_tolerancia(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, 
                                       LB::Int, UB::Int; max_vecinos::Int=50, 
                                       gestor_vecindarios=nothing)
    
    O, I = size(roi)
    es_gigante = (O > 2000 || I > 5000 || O * I > 10_000_000)
    es_patologica = get(INSTANCIA_STATE, "es_patologica", false)
    
    if gestor_vecindarios === nothing
        gestor_vecindarios = GestorVecindarios()
    end
    
    vecinos = Solucion[]
    
    # 🔥 PARA PATOLÓGICAS: Usar límites muy relajados
    if es_patologica
        println("🔥 Generando vecinos con límites adaptativos para patológica...")
        max_intentos_globales = max_vecinos * 10  # Muchos más intentos
        tolerancia_lb = 0.15  # 15% tolerancia
        tolerancia_ub = 0.25  # 25% tolerancia
    else
        max_intentos_globales = max_vecinos * 3
        tolerancia_lb = 0.05
        tolerancia_ub = 0.1
    end
    
    intentos_totales = 0
    
    while length(vecinos) < max_vecinos && intentos_totales < max_intentos_globales
        intentos_totales += 1
        
        tipo_movimiento = seleccionar_tipo_vecindario(gestor_vecindarios)
        vecinos_nuevos = Solucion[]
        
        try
            if tipo_movimiento == :intercambio
                vecinos_nuevos = intercambio_inteligente_tolerante_adaptativo(sol, roi, upi, LB, UB, tolerancia_lb, tolerancia_ub)
            elseif tipo_movimiento == :crecimiento
                vecinos_nuevos = crecimiento_controlado_tolerante_adaptativo(sol, roi, upi, LB, UB, tolerancia_lb, tolerancia_ub)
            elseif tipo_movimiento == :reduccion
                vecinos_nuevos = reduccion_controlada_tolerante_adaptativo(sol, roi, upi, LB, UB, tolerancia_lb, tolerancia_ub)
            elseif tipo_movimiento == :mutacion_multiple
                vecinos_nuevos = mutacion_multiple(sol, roi, upi, LB, UB)
            elseif tipo_movimiento == :reconstruccion_parcial
                vecinos_nuevos = reconstruccion_parcial(sol, roi, upi, LB, UB)
            end
            
            tuvo_exito = !isempty(vecinos_nuevos)
            actualizar_probabilidades!(gestor_vecindarios, tipo_movimiento, tuvo_exito)
            
            for v in vecinos_nuevos
                if !any(v_existente -> v_existente.ordenes == v.ordenes, vecinos)
                    push!(vecinos, v)
                    if length(vecinos) >= max_vecinos
                        break
                    end
                end
            end
            
        catch e
            actualizar_probabilidades!(gestor_vecindarios, tipo_movimiento, false)
        end
    end
    
    if es_patologica && length(vecinos) == 0
        println("⚠️ No se generaron vecinos con tolerancia adaptativa")
    end
    
    return vecinos
end



# ========================================
# FUNCIONES AUXILIARES
# ========================================

"""
Selección ponderada manual (reemplazo de StatsBase.sample)
"""
function seleccionar_ponderado(elementos::Vector{Int}, pesos::Vector{Float64})
    if isempty(elementos) || isempty(pesos)
        return elementos[1]
    end
    
    # Normalizar pesos
    suma_pesos = sum(pesos)
    if suma_pesos == 0
        return rand(elementos)
    end
    
    pesos_norm = pesos ./ suma_pesos
    
    # Selección por ruleta
    r = rand()
    acumulado = 0.0
    for (i, peso) in enumerate(pesos_norm)
        acumulado += peso
        if r <= acumulado
            return elementos[i]
        end
    end
    
    return elementos[end]
end

"""
Validación específica para instancias grandes con criterios más permisivos
"""
function validar_solucion_grande(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, 
                                LB::Int, UB::Int)
    # Para instancias grandes, ser más permisivo con algunos criterios
    if isempty(sol.ordenes) || isempty(sol.pasillos)
        return false
    end
    
    # Verificar factibilidad básica
    if !es_factible_rapido(sol, roi, upi, LB, UB)
        return false
    end
    
    # Verificar que la solución no sea degenerada
    if length(sol.ordenes) < 2
        return false
    end
    
    # Para instancias grandes, permitir más pasillos si es necesario
    max_pasillos_permitidos = min(size(upi, 1), length(sol.ordenes) * 2)
    if length(sol.pasillos) > max_pasillos_permitidos
        return false
    end
    
    return true
end

"""
Función de limpieza de vecinos para instancias grandes
Remueve vecinos de baja calidad para mantener diversidad
"""
function limpiar_vecinos_grandes(vecinos::Vector{Solucion}, roi::Matrix{Int}; 
                                mantener_top::Int=50)
    if length(vecinos) <= mantener_top
        return vecinos
    end
    
    # Evaluar todos los vecinos
    vecinos_evaluados = [(v, evaluar(v, roi)) for v in vecinos]
    
    # Ordenar por calidad
    sort!(vecinos_evaluados, by=x -> x[2], rev=true)
    
    # Mantener los mejores
    return [v[1] for v in vecinos_evaluados[1:mantener_top]]
end

"""
Función de escape para cuando no se pueden generar vecinos
"""
function generar_vecinos_emergencia(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, 
                                   LB::Int, UB::Int)
    # Estrategia de último recurso: perturbación simple
    O = size(roi, 1)
    ordenes_actuales = collect(sol.ordenes)
    
    if length(ordenes_actuales) < 2
        return Solucion[]
    end
    
    vecinos_emergencia = Solucion[]
    
    # Intentar intercambios simples
    for _ in 1:10
        o_out = rand(ordenes_actuales)
        candidatos = setdiff(1:O, sol.ordenes)
        
        if !isempty(candidatos)
            o_in = rand(candidatos)
            nuevas_ordenes = copy(sol.ordenes)
            delete!(nuevas_ordenes, o_out)
            push!(nuevas_ordenes, o_in)
            
            # Verificación muy básica
            demanda_total = sum(sum(roi[o, :]) for o in nuevas_ordenes)
            if LB <= demanda_total <= UB * 1.1  # Tolerancia del 10%
                nuevos_pasillos = calcular_pasillos_optimo(nuevas_ordenes, roi, upi)
                candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
                
                if es_factible_rapido(candidato, roi, upi, LB, UB)
                    push!(vecinos_emergencia, candidato)
                end
            end
        end
    end
    
    return vecinos_emergencia
end