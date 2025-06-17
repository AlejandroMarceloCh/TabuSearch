include("solution.jl")

function generar_vecinos_balanceado(sol::Solucion, roi, upi, LB, UB; max_vecinos=40)
    O = size(roi, 1)
    vecinos = []

    # 1. Agregar UNA orden aleatoria (limitado)
    candidatos_agregar = shuffle(setdiff(1:O, sol.ordenes))
    for o in candidatos_agregar[1:min(10, length(candidatos_agregar))]
        nueva_ordenes = copy(sol.ordenes)
        push!(nueva_ordenes, o)
        nuevos_pasillos = calcular_pasillos_balanceado(nueva_ordenes, roi, upi)
        nuevo = Solucion(nueva_ordenes, nuevos_pasillos)
        if es_factible_rapido(nuevo, roi, upi, LB, UB)
            push!(vecinos, nuevo)
            length(vecinos) >= max_vecinos && break
        end
    end

    # 2. Quitar UNA orden (si hay más de 2)
    if length(sol.ordenes) > 2
        for o in shuffle(collect(sol.ordenes))[1:min(5, length(sol.ordenes))]
            nueva_ordenes = setdiff(sol.ordenes, [o])
            nuevos_pasillos = calcular_pasillos_balanceado(nueva_ordenes, roi, upi)
            nuevo = Solucion(nueva_ordenes, nuevos_pasillos)
            if es_factible_rapido(nuevo, roi, upi, LB, UB)
                push!(vecinos, nuevo)
                length(vecinos) >= max_vecinos && break
            end
        end
    end

    # 3. Intercambio 1x1 (reemplazar una orden por otra fuera del conjunto)
    ordenes_actuales = collect(sol.ordenes)
    candidatos_nuevos = setdiff(1:O, sol.ordenes)

    for _ in 1:min(15, length(ordenes_actuales) * 2)
        length(vecinos) >= max_vecinos && break
        o_out = rand(ordenes_actuales)
        o_in = rand(candidatos_nuevos)

        nueva_ordenes = copy(sol.ordenes)
        delete!(nueva_ordenes, o_out)
        push!(nueva_ordenes, o_in)

        nuevos_pasillos = calcular_pasillos_balanceado(nueva_ordenes, roi, upi)
        nuevo = Solucion(nueva_ordenes, nuevos_pasillos)
        if es_factible_rapido(nuevo, roi, upi, LB, UB)
            push!(vecinos, nuevo)
        end
    end

    return vecinos
end
