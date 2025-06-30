# neighborhood.jl
# ========================================
# GENERACIÓN DE VECINDARIOS UNIFICADA - PROYECTO 20/20
# ========================================

include("solution.jl")
include("config_manager.jl")

# ========================================
# GESTOR ADAPTATIVO DE VECINDARIOS
# ========================================

mutable struct GestorVecindarios
    probabilidades::Dict{Symbol, Float64}
    exitos::Dict{Symbol, Int}
    intentos::Dict{Symbol, Int}
    
    function GestorVecindarios()
        tipos = [:intercambio, :crecimiento, :reduccion, :mutacion_multiple, :reconstruccion]
        probs = Dict(t => 1.0/length(tipos) for t in tipos)
        new(probs, Dict(t => 0 for t in tipos), Dict(t => 0 for t in tipos))
    end
end

"""
Actualiza las probabilidades según el éxito de cada tipo de vecindario
"""
function actualizar_probabilidades!(gestor::GestorVecindarios, tipo::Symbol, tuvo_exito::Bool)
    gestor.intentos[tipo] += 1
    if tuvo_exito
        gestor.exitos[tipo] += 1
    end
    
    # Rebalancear cada 20 intentos
    if sum(values(gestor.intentos)) % 20 == 0
        for t in keys(gestor.probabilidades)
            if gestor.intentos[t] > 0
                tasa_exito = gestor.exitos[t] / gestor.intentos[t]
                gestor.probabilidades[t] = 0.1 + 0.8 * tasa_exito
            end
        end
        
        # Normalizar
        suma = sum(values(gestor.probabilidades))
        for t in keys(gestor.probabilidades)
            gestor.probabilidades[t] /= suma
        end
    end
end

"""
Selecciona tipo de vecindario según probabilidades adaptativas
"""
function seleccionar_tipo_vecindario(gestor::GestorVecindarios)
    tipos = collect(keys(gestor.probabilidades))
    probs = [gestor.probabilidades[t] for t in tipos]
    
    r = rand()
    acumulado = 0.0
    for (i, p) in enumerate(probs)
        acumulado += p
        if r <= acumulado
            return tipos[i]
        end
    end
    return tipos[end]
end

# ========================================
# FUNCIÓN PRINCIPAL UNIFICADA
# ========================================

"""
Función principal que genera vecinos adaptándose automáticamente al tipo de instancia
"""
function generar_vecinos_unificado(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, 
                                 LB::Int, UB::Int, config::InstanceConfig; 
                                 gestor::Union{GestorVecindarios,Nothing}=nothing)
    
    if gestor === nothing
        gestor = GestorVecindarios()
    end
    
    vecinos = Solucion[]
    max_vecinos = config.parametros.max_vecinos
    max_intentos_globales = max_vecinos * (config.es_patologica ? 10 : 3)
    intentos_totales = 0
    
    while length(vecinos) < max_vecinos && intentos_totales < max_intentos_globales
        intentos_totales += 1
        
        tipo_movimiento = seleccionar_tipo_vecindario(gestor)
        vecinos_nuevos = Solucion[]
        
        try
            if tipo_movimiento == :intercambio
                vecinos_nuevos = intercambio_inteligente(sol, roi, upi, LB, UB, config)
            elseif tipo_movimiento == :crecimiento
                vecinos_nuevos = crecimiento_controlado(sol, roi, upi, LB, UB, config)
            elseif tipo_movimiento == :reduccion
                vecinos_nuevos = reduccion_controlada(sol, roi, upi, LB, UB, config)
            elseif tipo_movimiento == :mutacion_multiple
                vecinos_nuevos = mutacion_multiple(sol, roi, upi, LB, UB, config)
            elseif tipo_movimiento == :reconstruccion
                vecinos_nuevos = reconstruccion_parcial(sol, roi, upi, LB, UB, config)
            end
            
            tuvo_exito = !isempty(vecinos_nuevos)
            actualizar_probabilidades!(gestor, tipo_movimiento, tuvo_exito)
            
            # Agregar vecinos únicos
            for v in vecinos_nuevos
                if !any(v_existente -> v_existente.ordenes == v.ordenes, vecinos)
                    push!(vecinos, v)
                    if length(vecinos) >= max_vecinos
                        break
                    end
                end
            end
            
        catch e
            actualizar_probabilidades!(gestor, tipo_movimiento, false)
        end
    end
    
    return vecinos
end

# ========================================
# MOVIMIENTOS BÁSICOS
# ========================================

"""
Intercambio inteligente: sustituye una orden por otra
"""
function intercambio_inteligente(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, 
                               LB::Int, UB::Int, config::InstanceConfig)
    vecinos = Solucion[]
    O = size(roi, 1)
    ordenes_actuales = collect(sol.ordenes)
    candidatos_externos = setdiff(1:O, sol.ordenes)
    
    if isempty(ordenes_actuales) || isempty(candidatos_externos)
        return vecinos
    end
    
    max_intentos = config.parametros.max_intercambios
    tolerancia = config.es_patologica ? 0.15 : 0.05
    
    for _ in 1:max_intentos
        o_out = rand(ordenes_actuales)
        o_in = rand(candidatos_externos)
        
        nuevas_ordenes = copy(sol.ordenes)
        delete!(nuevas_ordenes, o_out)
        push!(nuevas_ordenes, o_in)
        
        # Validación con tolerancia para patológicas
        if validar_con_tolerancia(nuevas_ordenes, roi, upi, LB, UB, tolerancia)
            nuevos_pasillos = calcular_pasillos_optimo(nuevas_ordenes, roi, upi)
            candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
            
            if es_factible_rapido(candidato, roi, upi, LB, UB)
                push!(vecinos, candidato)
            elseif config.parametros.usar_reparacion_agresiva
                candidato_reparado = reparar_vecino(candidato, roi, upi, LB, UB, config)
                if candidato_reparado !== nothing
                    push!(vecinos, candidato_reparado)
                end
            end
        end
    end
    
    return vecinos
end

"""
Crecimiento controlado: agrega órdenes sin violar restricciones
"""
function crecimiento_controlado(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, 
                              LB::Int, UB::Int, config::InstanceConfig)
    vecinos = Solucion[]
    O = size(roi, 1)
    candidatos_externos = setdiff(1:O, sol.ordenes)
    
    if isempty(candidatos_externos)
        return vecinos
    end
    
    # Calcular demanda actual
    demanda_actual = sum(sum(roi[o, :]) for o in sol.ordenes)
    max_intentos = config.parametros.max_crecimientos
    
    # Permitir crecimiento más agresivo si estamos lejos del UB
    margen_disponible = UB - demanda_actual
    es_conservador = margen_disponible < UB * 0.2
    
    for _ in 1:max_intentos
        if es_conservador
            # Selección cuidadosa cuando estamos cerca del límite
            valores_candidatos = [(o, sum(roi[o, :])) for o in candidatos_externos]
            sort!(valores_candidatos, by=x->x[2])  # Ordenar por tamaño
            
            # Buscar orden que quepa
            for (o_new, demanda_extra) in valores_candidatos
                if demanda_actual + demanda_extra <= UB
                    nuevas_ordenes = copy(sol.ordenes)
                    push!(nuevas_ordenes, o_new)
                    
                    if validar_factibilidad_basica(nuevas_ordenes, roi, upi, LB, UB)
                        nuevos_pasillos = calcular_pasillos_optimo(nuevas_ordenes, roi, upi)
                        candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
                        
                        if es_factible_rapido(candidato, roi, upi, LB, UB)
                            push!(vecinos, candidato)
                            break
                        end
                    end
                end
            end
        else
            # Selección aleatoria cuando hay margen
            o_new = rand(candidatos_externos)
            demanda_extra = sum(roi[o_new, :])
            
            if demanda_actual + demanda_extra <= UB
                nuevas_ordenes = copy(sol.ordenes)
                push!(nuevas_ordenes, o_new)
                
                if validar_factibilidad_basica(nuevas_ordenes, roi, upi, LB, UB)
                    nuevos_pasillos = calcular_pasillos_optimo(nuevas_ordenes, roi, upi)
                    candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
                    
                    if es_factible_rapido(candidato, roi, upi, LB, UB)
                        push!(vecinos, candidato)
                    end
                end
            end
        end
    end
    
    return vecinos
end


"""
Reducción controlada: elimina órdenes manteniendo factibilidad
"""
function reduccion_controlada(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, 
                            LB::Int, UB::Int, config::InstanceConfig)
    vecinos = Solucion[]
    ordenes_actuales = collect(sol.ordenes)
    
    if length(ordenes_actuales) <= 2
        return vecinos
    end
    
    demanda_actual = sum(sum(roi[o, :]) for o in sol.ordenes)
    max_intentos = config.parametros.max_reducciones
    
    for _ in 1:max_intentos
        o_rem = rand(ordenes_actuales)
        demanda_perdida = sum(roi[o_rem, :])
        
        # Verificar que no caigamos por debajo de LB
        if demanda_actual - demanda_perdida >= LB
            nuevas_ordenes = setdiff(sol.ordenes, [o_rem])
            
            if validar_factibilidad_basica(nuevas_ordenes, roi, upi, LB, UB)
                nuevos_pasillos = calcular_pasillos_optimo(nuevas_ordenes, roi, upi)
                candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
                
                if es_factible_rapido(candidato, roi, upi, LB, UB)
                    push!(vecinos, candidato)
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
Mutación múltiple: cambia varias órdenes simultáneamente
"""
function mutacion_multiple(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, 
                          LB::Int, UB::Int, config::InstanceConfig)
    vecinos = Solucion[]
    O = size(roi, 1)
    ordenes_actuales = collect(sol.ordenes)
    n_ordenes = length(ordenes_actuales)
    
    if n_ordenes < 3
        return vecinos
    end
    
    intensidad = config.parametros.intensidad_perturbacion
    n_cambios = max(2, Int(ceil(n_ordenes * intensidad)))
    n_cambios = min(n_cambios, config.es_gigante ? 5 : max(5, n_ordenes ÷ 2))
    
    max_intentos = config.es_gigante ? 4 : 8
    
    for _ in 1:max_intentos
        # Seleccionar órdenes a cambiar
        indices_cambio = randperm(length(ordenes_actuales))[1:min(n_cambios, length(ordenes_actuales))]
        ordenes_a_cambiar = ordenes_actuales[indices_cambio]
        
        nuevas_ordenes = setdiff(sol.ordenes, ordenes_a_cambiar)
        candidatos = setdiff(1:O, nuevas_ordenes)
        
        if !isempty(candidatos)
            n_agregar = min(length(ordenes_a_cambiar) + rand(-1:2), length(candidatos))
            if n_agregar > 0
                indices_nuevas = randperm(length(candidatos))[1:n_agregar]
                ordenes_nuevas = candidatos[indices_nuevas]
                for o in ordenes_nuevas
                    push!(nuevas_ordenes, o)
                end
            end
        end
        
        tolerancia = config.es_patologica ? 0.2 : 0.1
        if validar_con_tolerancia(nuevas_ordenes, roi, upi, LB, UB, tolerancia)
            nuevos_pasillos = calcular_pasillos_optimo(nuevas_ordenes, roi, upi)
            candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
            
            if es_factible_rapido(candidato, roi, upi, LB, UB)
                push!(vecinos, candidato)
            elseif config.parametros.usar_reparacion_agresiva
                candidato_reparado = reparar_vecino(candidato, roi, upi, LB, UB, config)
                if candidato_reparado !== nothing
                    push!(vecinos, candidato_reparado)
                end
            end
        end
    end
    
    return vecinos
end

"""
Reconstrucción parcial: mantiene núcleo y reconstruye el resto
"""
function reconstruccion_parcial(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, 
                               LB::Int, UB::Int, config::InstanceConfig)
    vecinos = Solucion[]
    ordenes_actuales = collect(sol.ordenes)
    
    if length(ordenes_actuales) < 4
        return vecinos
    end
    
    O = size(roi, 1)
    max_intentos = config.es_gigante ? 2 : 3
    
    for intento in 1:max_intentos
        # Seleccionar núcleo a mantener
        porcentaje_mantener = 0.5 + rand() * 0.2  # 50-70%
        n_mantener = Int(ceil(length(ordenes_actuales) * porcentaje_mantener))
        
        if config.es_gigante
            # Para gigantes: selección aleatoria simple
            indices_mantener = randperm(length(ordenes_actuales))[1:n_mantener]
            ordenes_nucleo = Set(ordenes_actuales[indices_mantener])
        else
            # Para no-gigantes: mantener las mejores
            valores_ordenes = [(o, sum(roi[o, :])) for o in ordenes_actuales]
            sort!(valores_ordenes, by=x -> x[2], rev=true)
            ordenes_nucleo = Set([v[1] for v in valores_ordenes[1:n_mantener]])
        end
        
        # Reconstruir
        ordenes_trabajo = copy(ordenes_nucleo)
        candidatos = setdiff(1:O, ordenes_trabajo)
        
        # Construcción guiada hacia factibilidad
        while !isempty(candidatos)
            demanda_actual = sum(sum(roi[o, :]) for o in ordenes_trabajo)
            if demanda_actual >= UB * 0.95
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
        
        # Validar y crear vecino
        if validar_factibilidad_basica(ordenes_trabajo, roi, upi, LB, UB)
            nuevos_pasillos = calcular_pasillos_optimo(ordenes_trabajo, roi, upi)
            candidato = Solucion(ordenes_trabajo, nuevos_pasillos)
            
            if es_factible_rapido(candidato, roi, upi, LB, UB)
                push!(vecinos, candidato)
            end
        end
    end
    
    return vecinos
end

# ========================================
# FUNCIONES AUXILIARES
# ========================================

"""
Validación con tolerancia para instancias patológicas
"""
function validar_con_tolerancia(ordenes::Set{Int}, roi::Matrix{Int}, upi::Matrix{Int}, 
                               LB::Int, UB::Int, tolerancia::Float64)
    if isempty(ordenes)
        return false
    end
    
    demanda_total = sum(sum(roi[o, :]) for o in ordenes)
    lb_relajado = LB * (1 - tolerancia)
    ub_relajado = UB * (1 + tolerancia)
    
    return lb_relajado <= demanda_total <= ub_relajado
end

"""
Reparación rápida de vecinos para instancias patológicas
"""
function reparar_vecino(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, 
                       LB::Int, UB::Int, config::InstanceConfig)
    
    ordenes_actuales = copy(sol.ordenes)
    max_intentos = config.es_gigante ? 3 : 5
    
    for _ in 1:max_intentos
        if isempty(ordenes_actuales)
            break
        end
        
        demanda_total = sum(sum(roi[o, :]) for o in ordenes_actuales)
        
        if demanda_total > UB
            # Remover orden aleatoria
            if length(ordenes_actuales) > 1
                orden_remover = rand(collect(ordenes_actuales))
                delete!(ordenes_actuales, orden_remover)
            else
                break
            end
        elseif demanda_total >= LB
            # Está en rango, probar factibilidad
            nuevos_pasillos = calcular_pasillos_optimo(ordenes_actuales, roi, upi)
            candidato = Solucion(ordenes_actuales, nuevos_pasillos)
            
            if es_factible_rapido(candidato, roi, upi, LB, UB)
                return candidato
            else
                # Remover una orden y continuar
                if length(ordenes_actuales) > 1
                    orden_remover = rand(collect(ordenes_actuales))
                    delete!(ordenes_actuales, orden_remover)
                else
                    break
                end
            end
        else
            # Menos que LB, no se puede reparar fácilmente
            break
        end
    end
    
    return nothing
end