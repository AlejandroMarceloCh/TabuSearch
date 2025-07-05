struct ConfigInstancia
    tipo::Symbol
    es_patologica::Bool
    tipos_patologia::Vector{Symbol}
    ordenes::Int
    items::Int
    pasillos::Int
    ratio_ub_lb::Float64
    pasillos_teoricos::Float64
    tamaño_efectivo::Int
    # AGREGAR ESTOS CAMPOS:
    estrategia_constructiva::Symbol
    estrategia_factibilidad::Symbol
    estrategia_pasillos::Symbol
    estrategia_vecindarios::Symbol
    estrategia_tabu::Symbol
    max_iteraciones::Int
    max_sin_mejora::Int
    tabu_size::Int
    max_vecinos::Int
    timeout_adaptativo::Float64
end