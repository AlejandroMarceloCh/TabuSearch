#neighborhood.jl
include("solution.jl")

function clasificar_instancia(roi, upi)
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

function calcular_densidad_ordenes(roi)
    densidades = Dict{Int, Float64}()
    O, I = size(roi)

    for o in 1:O
        items_activos = sum(roi[o, :] .> 0)
        demanda_total = sum(roi[o, :])
        densidades[o] = items_activos > 0 ? demanda_total / items_activos : 0.0
    end

    return densidades
end

function sample_ordenes_inteligente(candidatos, densidades, n::Int; tipo=:alta_densidad)
    if length(candidatos) <= n
        return candidatos
    end

    if tipo == :alta_densidad
        ordenados = sort(candidatos, by=o -> get(densidades, o, 0.0), rev=true)
        n_det = max(1, Int(floor(0.7 * n)))
        n_rand = n - n_det

        seleccionados = ordenados[1:n_det]
        if n_rand > 0 && length(ordenados) > n_det
            restantes = ordenados[(n_det+1):end]
            append!(seleccionados, sample(restantes, min(n_rand, length(restantes)); replace=false))
        end
        return seleccionados
    else
        return sample(candidatos, n; replace=false)
    end
end

function actualizar_pasillos_incremental(sol_base::Solucion, ordenes_nuevas, roi, upi)
    return calcular_pasillos(ordenes_nuevas, roi, upi)
end

function generar_vecinos(sol::Solucion, roi, upi, LB, UB;
                         max_vecinos=50, control=nothing)

    tipo = clasificar_instancia(roi, upi)
    O = size(roi, 1)
    vecinos = Solucion[]
    ordenes_actuales = collect(sol.ordenes)
    densidades = calcular_densidad_ordenes(roi)

    candidatos_agregar = setdiff(1:O, sol.ordenes)
    candidatos_quitar = ordenes_actuales
    candidatos_reemplazo = candidatos_agregar

    function intentar_push(ordenes_modificadas)
        if isempty(ordenes_modificadas)
            return false
        end
        nuevos_pasillos = actualizar_pasillos_incremental(sol, ordenes_modificadas, roi, upi)
        nuevo = Solucion(ordenes_modificadas, nuevos_pasillos)

        if es_factible_rapido(nuevo, roi, upi, LB, UB)
            push!(vecinos, nuevo)
            return true
        end
        return false
    end

    intensidad = control !== nothing ? control.intensidad : :intensificar
    factor_diversificacion = intensidad == :diversificar ? 2.0 : 1.0

    if tipo == :pequeña
        vecinos = []
    
        # 1. Movimientos simples (40%)
        for _ in 1:ceil(Int, max_vecinos * 0.4)
            mov = rand(1:3)
            if mov == 1 && !isempty(candidatos_agregar)
                o = rand(candidatos_agregar)
                nueva = copy(sol.ordenes)
                push!(nueva, o)
                intentar_push(nueva)
            elseif mov == 2 && !isempty(candidatos_quitar)
                o = rand(candidatos_quitar)
                nueva = setdiff(sol.ordenes, [o])
                intentar_push(nueva)
            elseif mov == 3 && !isempty(candidatos_reemplazo) && !isempty(ordenes_actuales)
                o_out = rand(ordenes_actuales)
                o_in = rand(candidatos_reemplazo)
                nueva = copy(sol.ordenes)
                delete!(nueva, o_out)
                push!(nueva, o_in)
                intentar_push(nueva)
            end
            length(vecinos) >= max_vecinos && return vecinos
        end
    
        # 2. Movimientos compuestos (40%)
        for _ in 1:ceil(Int, max_vecinos * 0.4)
            if length(candidatos_agregar) >= 2 && !isempty(candidatos_quitar)
                seleccionados = sample(candidatos_agregar, 2; replace=false)
                o_add1, o_add2 = seleccionados[1], seleccionados[2]
                o_rem = rand(candidatos_quitar)
                nueva = copy(sol.ordenes)
                push!(nueva, o_add1)
                push!(nueva, o_add2)
                delete!(nueva, o_rem)
                intentar_push(nueva)
            end
            length(vecinos) >= max_vecinos && return vecinos
        end
    
        # 3. Perturbación controlada (20%)
        for _ in 1:ceil(Int, max_vecinos * 0.2)
            if length(ordenes_actuales) >= 3 && length(candidatos_agregar) >= 3
                o_outs = sample(ordenes_actuales, 3; replace=false)
                o_ins = sample(candidatos_agregar, 3; replace=false)
                nueva = copy(sol.ordenes)
                for o in o_outs
                    delete!(nueva, o)
                end
                for o in o_ins
                    push!(nueva, o)
                end
                intentar_push(nueva)
            end
            length(vecinos) >= max_vecinos && return vecinos
        end
    
        # 4. Backup: combinaciones 2–4 si no se llegó al mínimo
        if length(vecinos) < max_vecinos
            subconjuntos = Iterators.take(
                Iterators.filter(x -> length(x) ≥ 2,
                    Iterators.flatten([collect(combinations(collect(1:O), k)) for k in 2:4])
                ), max_vecinos - length(vecinos)
            )
    
            for subset in subconjuntos
                ordenes_nueva = Set(subset)
                nuevos_pasillos = calcular_pasillos(ordenes_nueva, roi, upi)
                nueva = Solucion(ordenes_nueva, nuevos_pasillos)
    
                es_factible_rapido(nueva, roi, upi, LB, UB) && push!(vecinos, nueva)
                length(vecinos) >= max_vecinos && break
            end
        end
    
        return vecinos
    
    
    
    elseif tipo == :mediana
        n_add = Int(ceil(8 * factor_diversificacion))
        n_rem = Int(ceil(5 * factor_diversificacion))
        n_swaps = Int(ceil(6 * factor_diversificacion))

        for o in sample_ordenes_inteligente(candidatos_agregar, densidades, n_add)
            nueva = copy(sol.ordenes)
            push!(nueva, o)
            intentar_push(nueva)
            length(vecinos) >= max_vecinos && return vecinos
        end

        for o in sample_ordenes_inteligente(candidatos_quitar, densidades, n_rem)
            nueva = setdiff(sol.ordenes, [o])
            intentar_push(nueva)
            length(vecinos) >= max_vecinos && return vecinos
        end

        for _ in 1:n_swaps
            if isempty(ordenes_actuales) || isempty(candidatos_reemplazo)
                continue
            end
            o_out = rand(ordenes_actuales)
            o_in = rand(sample_ordenes_inteligente(candidatos_reemplazo, densidades, 1))
            nueva = copy(sol.ordenes)
            delete!(nueva, o_out)
            push!(nueva, o_in)
            intentar_push(nueva)
            length(vecinos) >= max_vecinos && return vecinos
        end

    else
        # Para grandes y gigantes
        n_movimientos = tipo == :grande ? Int(ceil(8 * factor_diversificacion)) : Int(ceil(5 * factor_diversificacion))
        rmin, rmax = tipo == :grande ? (3, 8) : (5, 15)
        amin, amax = tipo == :grande ? (2, 7) : (3, 12)

        for _ in 1:n_movimientos
            n_remove = rand(rmin:ceil(Int, rmax * factor_diversificacion))
            n_add    = rand(amin:ceil(Int, amax * factor_diversificacion))
            
            if length(ordenes_actuales) >= n_remove
                ordenes_nueva = copy(sol.ordenes)
                ordenes_a_remover = rand() < 0.5 ?
                    sample_ordenes_inteligente(ordenes_actuales, densidades, n_remove, tipo=:baja_densidad) :
                    sample(ordenes_actuales, n_remove; replace=false)

                for o in ordenes_a_remover
                    delete!(ordenes_nueva, o)
                end

                candidatos_actualizados = setdiff(1:O, ordenes_nueva)
                if length(candidatos_actualizados) >= n_add
                    nuevos = sample_ordenes_inteligente(candidatos_actualizados, densidades, n_add)
                    for o in nuevos
                        push!(ordenes_nueva, o)
                    end

                    intentar_push(ordenes_nueva)
                    length(vecinos) >= max_vecinos && return vecinos
                end
            end
        end
    end

    return vecinos
end
