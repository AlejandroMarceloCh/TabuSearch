# tabu_structures.jl
# ========================================
# ESTRUCTURAS Y FUNCIONES PARA TABU SEARCH
# ========================================

# ========================================
# ESTRUCTURAS DE CONTROL
# ========================================

"""
Estructura de control adaptativo mejorada para todas las instancias
"""
mutable struct ControlAdaptativoMejorado
    iteraciones_sin_mejora::Int
    mejoras_recientes::Vector{Float64}
    intensidad::Symbol  # :intensificar, :diversificar, :reintensificar
    contador_diversificacion::Int
    contador_reintensificar::Int
    mejor_valor_historico::Float64
    umbral_estancamiento::Int
    
    ControlAdaptativoMejorado() = new(0, Float64[], :intensificar, 0, 0, -Inf, 5)
end

"""
Lista tabú con gestión de frecuencias y hash eficiente
"""
mutable struct TabuListaInteligente
    lista::Vector{UInt64}
    tamaño_max::Int
    memoria_frecuencia::Dict{UInt64, Int}
    
    TabuListaInteligente(tamaño_max::Int) = new(UInt64[], tamaño_max, Dict{UInt64, Int}())
end

"""
Gestor que adapta las probabilidades de uso de diferentes tipos de vecindarios
según el éxito histórico de cada uno
"""
mutable struct GestorVecindarios
    probabilidades::Dict{Symbol, Float64}
    exitos::Dict{Symbol, Int}
    intentos::Dict{Symbol, Int}
    
    function GestorVecindarios()
        tipos = [:intercambio, :crecimiento, :reduccion, :mutacion_multiple, :reconstruccion_parcial]
        probs = Dict(t => 1.0/length(tipos) for t in tipos)
        new(probs, Dict(t => 0 for t in tipos), Dict(t => 0 for t in tipos))
    end
end

# ========================================
# FUNCIONES PARA CONTROL ADAPTATIVO
# ========================================

"""
Actualiza el control adaptativo según el progreso de la búsqueda
"""
function actualizar_control_mejorado!(control::ControlAdaptativoMejorado, valor_actual::Float64, es_mejor::Bool)
    mejora = es_mejor ? valor_actual - control.mejor_valor_historico : 0.0
    push!(control.mejoras_recientes, mejora)
    
    # Mantener ventana de mejoras recientes
    if length(control.mejoras_recientes) > 15
        popfirst!(control.mejoras_recientes)
    end
    
    if es_mejor
        control.mejor_valor_historico = valor_actual
        control.iteraciones_sin_mejora = 0
        control.contador_diversificacion = 0
        control.contador_reintensificar = 0
        control.intensidad = :intensificar
    else
        control.iteraciones_sin_mejora += 1
        
        # Detectar estancamiento
        mejoras_significativas = count(x -> x > 0.01, control.mejoras_recientes)
        varianza_baja = false
        if length(control.mejoras_recientes) > 5
            try
                # Usar std si está disponible
                varianza_baja = length(Set(control.mejoras_recientes)) <= 3
            catch
                varianza_baja = false
            end
        end
        
        if control.iteraciones_sin_mejora > control.umbral_estancamiento || 
           (varianza_baja && mejoras_significativas < 2)
            
            control.contador_diversificacion += 1
            
            if control.contador_diversificacion <= 3
                control.intensidad = :diversificar
            else
                control.intensidad = :reintensificar
                control.contador_reintensificar += 1
                
                # Reset después de varios intentos de reintensificación
                if control.contador_reintensificar > 2
                    control.contador_diversificacion = 0
                    control.contador_reintensificar = 0
                    control.iteraciones_sin_mejora = 0
                    control.umbral_estancamiento = min(control.umbral_estancamiento + 2, 15)
                end
            end
        end
    end
end

# ========================================
# FUNCIONES PARA LISTA TABÚ
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
    return frecuencia * 0.1  # Penalización suave
end

# ========================================
# FUNCIONES PARA GESTOR DE VECINDARIOS
# ========================================

"""
Actualiza las probabilidades de uso de vecindarios según el éxito
"""
function actualizar_probabilidades!(gestor::GestorVecindarios, tipo::Symbol, tuvo_exito::Bool)
    gestor.intentos[tipo] += 1
    if tuvo_exito
        gestor.exitos[tipo] += 1
    end
    
    # Cada 20 intentos, rebalancear probabilidades
    if sum(values(gestor.intentos)) % 20 == 0
        for tipo in keys(gestor.probabilidades)
            if gestor.intentos[tipo] > 0
                tasa_exito = gestor.exitos[tipo] / gestor.intentos[tipo]
                # Ajustar probabilidad basada en tasa de éxito con componente exploratorio
                gestor.probabilidades[tipo] = 0.1 + 0.8 * tasa_exito
            end
        end
        
        # Normalizar probabilidades
        suma_probs = sum(values(gestor.probabilidades))
        for tipo in keys(gestor.probabilidades)
            gestor.probabilidades[tipo] /= suma_probs
        end
    end
end

"""
Selecciona el tipo de vecindario según las probabilidades adaptativas
"""
function seleccionar_tipo_vecindario(gestor::GestorVecindarios)
    tipos = collect(keys(gestor.probabilidades))
    probs = [gestor.probabilidades[t] for t in tipos]
    
    # Implementación sin StatsBase
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
# FUNCIONES AUXILIARES
# ========================================

"""
Función auxiliar para mostrar estadísticas del gestor de vecindarios
"""
function mostrar_estadisticas_vecindarios(gestor::GestorVecindarios)
    println("📊 Estadísticas de vecindarios:")
    for (tipo, prob) in gestor.probabilidades
        exitos = get(gestor.exitos, tipo, 0)
        intentos = get(gestor.intentos, tipo, 1)
        tasa_exito = round(exitos / intentos * 100, digits=1)
        println("   $tipo: $(round(prob, digits=3)) (éxito: $tasa_exito%)")
    end
end

"""
Función para crear un diccionario redondeado (utilidad para logging)
"""
function round_dict(dict::Dict, digits::Int)
    return Dict(k => round(v, digits=digits) for (k, v) in dict)
end