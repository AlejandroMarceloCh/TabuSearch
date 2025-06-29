# tabu_search.jl
# ========================================
# TABU SEARCH UNIFICADO Y ADAPTATIVO - PROYECTO 20/20
# ========================================

include("solution.jl")
include("config_manager.jl")
include("neighborhood.jl")

using Random

# ========================================
# ESTRUCTURAS DE CONTROL
# ========================================

mutable struct TabuListaInteligente
    lista::Vector{UInt64}
    tamaño_max::Int
    memoria_frecuencia::Dict{UInt64, Int}
    
    TabuListaInteligente(tamaño_max::Int) = new(UInt64[], tamaño_max, Dict{UInt64, Int}())
end

mutable struct ControlAdaptativo
    iteraciones_sin_mejora::Int
    mejoras_recientes::Vector{Float64}
    intensidad::Symbol  # :intensificar, :diversificar, :reintensificar
    mejor_valor_historico::Float64
    umbral_estancamiento::Int
    
    ControlAdaptativo() = new(0, Float64[], :intensificar, -Inf, 5)
end

# ========================================
# ALGORITMO PRINCIPAL UNIFICADO
# ========================================

"""
Tabu Search unificado que se adapta automáticamente a cualquier tipo de instancia
"""
function tabu_search_unificado(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int;
                              config::Union{InstanceConfig,Nothing}=nothing,
                              semilla::Union{Int,Nothing}=nothing,
                              solucion_inicial::Union{Solucion,Nothing}=nothing,
                              devolver_evolucion::Bool=false)
    
    if semilla !== nothing
        Random.seed!(semilla)
    end
    
    # Crear configuración automática si no se proporciona
    if config === nothing
        config = crear_configuracion_automatica(roi, upi, LB, UB)
    end
    
    # Mostrar información de la instancia
    mostrar_info_instancia(config, roi, upi, LB, UB)
    
    # Generar o usar solución inicial
    if solucion_inicial === nothing
        actual = generar_solucion_inicial_unificada(roi, upi, LB, UB; config=config)
    else
        actual = solucion_inicial
    end
    
    if actual === nothing
        error("❌ No se pudo generar solución inicial factible")
    end
    
    # Inicializar estructuras de control
    control = ControlAdaptativo()
    tabu_lista = TabuListaInteligente(config.parametros.tabu_size)
    gestor_vecindarios = GestorVecindarios()
    
    # Variables de estado
    mejor = actual
    mejor_obj = evaluar(mejor, roi)
    control.mejor_valor_historico = mejor_obj
    
    # Métricas
    evolucion_obj = Float64[]
    contador_vecinos_vacios = 0
    mejores_encontrados = [(mejor_obj, 0)]
    iteraciones_criticas = 0
    
    iter = 0
    sin_mejora = 0
    
    mostrar_inicio_busqueda(config)
    mostrar_solucion(actual, roi, config, "Inicial")
    
    # BUCLE PRINCIPAL
    while iter < config.parametros.max_iter && sin_mejora < config.parametros.max_no_improve
        iter += 1
        
        # Generar vecinos usando el sistema unificado
        vecinos = generar_vecinos_unificado(actual, roi, upi, LB, UB, config; gestor=gestor_vecindarios)
        
        if isempty(vecinos)
            contador_vecinos_vacios += 1
            iteraciones_criticas += 1
            
            # Estrategias de escape adaptativas
            if manejar_vecinos_vacios!(actual, control, tabu_lista, roi, upi, LB, UB, config, 
                                     contador_vecinos_vacios, iteraciones_criticas)
                actual, contador_vecinos_vacios, iteraciones_criticas = 
                    aplicar_escape(actual, roi, upi, LB, UB, config, contador_vecinos_vacios, iteraciones_criticas)
            end
            continue
        end
        
        # Reset contadores si encontramos vecinos
        if contador_vecinos_vacios > 0
            contador_vecinos_vacios = 0
        end
        if iteraciones_criticas > 0
            iteraciones_criticas = max(0, iteraciones_criticas - 1)
        end
        
        # Evaluar y seleccionar mejor vecino
        mejor_vecino = seleccionar_mejor_vecino(vecinos, tabu_lista, mejor_obj, control, roi)
        
        if mejor_vecino === nothing
            # Selección diversificada como último recurso
            mejor_vecino = seleccion_diversificada(vecinos, roi)
        end
        
        # Actualizar solución actual
        actual = mejor_vecino
        obj_actual = evaluar(actual, roi)
        push!(evolucion_obj, obj_actual)
        
        # Agregar a lista tabú
        agregar_tabu!(tabu_lista, actual.ordenes)
        
        # Verificar mejora
        es_mejor = obj_actual > mejor_obj
        if es_mejor
            mejor = actual
            mejor_obj = obj_actual
            sin_mejora = 0
            push!(mejores_encontrados, (mejor_obj, iter))
            
            mostrar_solucion(mejor, roi, config, "Nuevo MEJOR", true)
        else
            sin_mejora += 1
        end
        
        # Actualizar control adaptativo
        actualizar_control!(control, obj_actual, es_mejor)
        
        # Log de progreso
        if iter % config.parametros.log_interval == 0
            mostrar_progreso(iter, obj_actual, mejor_obj, sin_mejora, config, 
                           "[$(control.intensidad)]")
        end
    end
    
    # Finalización
    mostrar_finalizacion(mejor, roi, upi, LB, UB, iter, contador_vecinos_vacios, 
                        length(mejores_encontrados), config)
    
    if devolver_evolucion
        return mejor, mejor_obj, evolucion_obj, contador_vecinos_vacios, mejores_encontrados
    else
        return mejor, contador_vecinos_vacios
    end
end

# ========================================
# FUNCIONES DE GESTIÓN DE LISTA TABÚ
# ========================================

"""
Genera hash único para un conjunto de órdenes
"""
function hash_solucion(ordenes::Set{Int})
    return hash(sort(collect(ordenes)))
end

"""
Verifica si una solución está en la lista tabú
"""
function es_tabu(lista::TabuListaInteligente, ordenes::Set{Int})
    h = hash_solucion(ordenes)
    return h in lista.lista
end

"""
Agrega una solución a la lista tabú
"""
function agregar_tabu!(lista::TabuListaInteligente, ordenes::Set{Int})
    h = hash_solucion(ordenes)
    push!(lista.lista, h)
    lista.memoria_frecuencia[h] = get(lista.memoria_frecuencia, h, 0) + 1
    
    # Mantener tamaño máximo
    if length(lista.lista) > lista.tamaño_max
        h_viejo = popfirst!(lista.lista)
    end
end

"""
Calcula penalización por frecuencia de visita
"""
function calcular_penalizacion_frecuencia(lista::TabuListaInteligente, ordenes::Set{Int})
    h = hash_solucion(ordenes)
    frecuencia = get(lista.memoria_frecuencia, h, 0)
    return frecuencia * 0.1
end

# ========================================
# CONTROL ADAPTATIVO
# ========================================

"""
Actualiza el control adaptativo según el progreso
"""
function actualizar_control!(control::ControlAdaptativo, valor_actual::Float64, es_mejor::Bool)
    mejora = es_mejor ? valor_actual - control.mejor_valor_historico : 0.0
    push!(control.mejoras_recientes, mejora)
    
    # Mantener ventana de mejoras recientes
    if length(control.mejoras_recientes) > 15
        popfirst!(control.mejoras_recientes)
    end
    
    if es_mejor
        control.mejor_valor_historico = valor_actual
        control.iteraciones_sin_mejora = 0
        control.intensidad = :intensificar
    else
        control.iteraciones_sin_mejora += 1
        
        # Detectar estancamiento
        mejoras_significativas = count(x -> x > 0.01, control.mejoras_recientes)
        
        if control.iteraciones_sin_mejora > control.umbral_estancamiento || 
           (length(control.mejoras_recientes) > 5 && mejoras_significativas < 2)
            
            if control.intensidad == :intensificar
                control.intensidad = :diversificar
            else
                control.intensidad = :reintensificar
                control.umbral_estancamiento = min(control.umbral_estancamiento + 2, 15)
            end
        end
    end
end

# ========================================
# SELECCIÓN DE VECINOS
# ========================================

"""
Selecciona el mejor vecino considerando lista tabú y criterios de aspiración
"""
function seleccionar_mejor_vecino(vecinos::Vector{Solucion}, tabu_lista::TabuListaInteligente, 
                                 mejor_obj::Float64, control::ControlAdaptativo, roi::Matrix{Int})
    
    mejor_vecino = nothing
    mejor_score = -Inf
    
    for vecino in vecinos
        obj_vecino = evaluar(vecino, roi)
        penalizacion = calcular_penalizacion_frecuencia(tabu_lista, vecino.ordenes)
        score = obj_vecino - penalizacion
        
        # Criterios de aspiración
        es_aspiracion = (obj_vecino > mejor_obj * 1.001) ||  # Mejor que el mejor global
                       (obj_vecino > control.mejor_valor_historico * 0.995 && control.iteraciones_sin_mejora > 5) ||
                       (control.iteraciones_sin_mejora > 10 && obj_vecino > mejor_obj * 0.99)
        
        if (!es_tabu(tabu_lista, vecino.ordenes) || es_aspiracion) && score > mejor_score
            mejor_vecino = vecino
            mejor_score = score
        end
    end
    
    # Si no hay vecino válido en modo intensificar, tomar el mejor aunque sea tabú
    if mejor_vecino === nothing && control.intensidad == :intensificar
        vecinos_evaluados = [(v, evaluar(v, roi)) for v in vecinos]
        sort!(vecinos_evaluados, by=x -> x[2], rev=true)
        mejor_vecino = vecinos_evaluados[1][1]
    end
    
    return mejor_vecino
end

"""
Selección diversificada cuando no hay vecino válido
"""
function seleccion_diversificada(vecinos::Vector{Solucion}, roi::Matrix{Int})
    if isempty(vecinos)
        return nothing
    end
    
    vecinos_evaluados = [(v, evaluar(v, roi)) for v in vecinos]
    sort!(vecinos_evaluados, by=x -> x[2], rev=true)
    
    # Seleccionar aleatoriamente entre los top 3
    top_k = min(3, length(vecinos_evaluados))
    return vecinos_evaluados[rand(1:top_k)][1]
end

# ========================================
# ESTRATEGIAS DE ESCAPE
# ========================================

"""
Determina si se debe aplicar estrategia de escape
"""
function manejar_vecinos_vacios!(actual::Solucion, control::ControlAdaptativo, 
                                tabu_lista::TabuListaInteligente, roi::Matrix{Int}, 
                                upi::Matrix{Int}, LB::Int, UB::Int, config::InstanceConfig,
                                contador_vacios::Int, iter_criticas::Int)
    
    # Umbrales adaptativos según tipo de instancia
    umbral_perturbacion = config.es_gigante ? 2 : 3
    umbral_reinicio = config.es_gigante ? 5 : 8
    
    return contador_vacios >= umbral_perturbacion || iter_criticas >= umbral_reinicio
end

"""
Aplica estrategias de escape cuando no se encuentran vecinos
"""
function aplicar_escape(actual::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, 
                       LB::Int, UB::Int, config::InstanceConfig, 
                       contador_vacios::Int, iter_criticas::Int)
    
    nueva_solucion = actual
    nuevo_contador = contador_vacios
    nuevas_criticas = iter_criticas
    
    if contador_vacios >= 2 && contador_vacios < 5
        # Perturbación
        nueva_solucion = perturbar_solucion(actual, roi, upi, LB, UB, config)
        nuevo_contador = 0
        
        if config.mostrar_detalles
            println("🔄 Perturbación aplicada")
        end
    elseif iter_criticas >= (config.es_gigante ? 5 : 8)
        # Reinicio parcial
        nueva_solucion = generar_solucion_inicial_unificada(roi, upi, LB, UB; config=config)
        
        if nueva_solucion === nothing
            nueva_solucion = actual  # Mantener actual si falla
        else
            nuevo_contador = 0
            nuevas_criticas = 0
            
            if config.mostrar_detalles
                println("🆘 Reinicio parcial aplicado")
            end
        end
    end
    
    return nueva_solucion, nuevo_contador, nuevas_criticas
end

"""
Perturbación de solución con intensidad adaptativa
"""
function perturbar_solucion(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, 
                           LB::Int, UB::Int, config::InstanceConfig)
    
    O = size(roi, 1)
    ordenes_actuales = collect(sol.ordenes)
    n_ordenes = length(ordenes_actuales)
    
    if n_ordenes < 3
        return sol
    end
    
    intensidad = config.parametros.intensidad_perturbacion
    n_cambios = max(2, Int(ceil(n_ordenes * intensidad)))
    
    # Remover órdenes
    n_remover = min(n_cambios, length(ordenes_actuales) - 1)
    indices_remover = randperm(length(ordenes_actuales))[1:n_remover]
    ordenes_a_remover = ordenes_actuales[indices_remover]
    nuevas_ordenes = setdiff(sol.ordenes, ordenes_a_remover)
    
    # Agregar órdenes aleatorias
    candidatos = setdiff(1:O, nuevas_ordenes)
    if !isempty(candidatos)
        n_agregar = min(n_cambios + rand(-1:2), length(candidatos))
        if n_agregar > 0
            indices_agregar = randperm(length(candidatos))[1:n_agregar]
            ordenes_a_agregar = candidatos[indices_agregar]
            for o in ordenes_a_agregar
                push!(nuevas_ordenes, o)
            end
        end
    end
    
    # Intentar crear solución factible
    for intento in 1:5
        if validar_factibilidad_basica(nuevas_ordenes, roi, upi, LB, UB)
            nuevos_pasillos = calcular_pasillos_optimo(nuevas_ordenes, roi, upi)
            candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
            
            if es_factible_rapido(candidato, roi, upi, LB, UB)
                return candidato
            end
        end
        
        # Ajustar para siguiente intento
        if length(nuevas_ordenes) > 2
            ordenes_lista = collect(nuevas_ordenes)
            o_rem = ordenes_lista[rand(1:length(ordenes_lista))]
            delete!(nuevas_ordenes, o_rem)
        end
    end
    
    # Si falla, retornar solución original
    return sol
end