include("solution.jl")
include("neighborhood.jl")
using Random
using Plots

function tabu_search(roi, upi, LB, UB;
                     max_iter=100, max_no_improve=20, tabu_tam=7)

    O = size(roi, 1)

    # Solución inicial aleatoria (con al menos una orden)
    ordenes_ini = Set{Int}()
    while isempty(ordenes_ini)
        for o in 1:O
            if rand() < 0.3
                push!(ordenes_ini, o)
            end
        end
    end
    pasillos_ini = calcular_pasillos(ordenes_ini, roi, upi)
    actual = Solucion(ordenes_ini, pasillos_ini)

    # Si no es factible, seguimos generando hasta que lo sea
    while !es_factible(actual, roi, upi, LB, UB)
        ordenes_ini = Set{Int}()
        while isempty(ordenes_ini)
            for o in 1:O
                if rand() < 0.3
                    push!(ordenes_ini, o)
                end
            end
        end
        pasillos_ini = calcular_pasillos(ordenes_ini, roi, upi)
        actual = Solucion(ordenes_ini, pasillos_ini)
    end

    mejor = actual
    mejor_obj = calcular_objetivo(mejor, roi)
    lista_tabu = Vector{Set{Int}}()

    iter = 0
    sin_mejora = 0
    evolucion_objetivo = Float64[]

    println("🔁 Iniciando Tabu Search...")

    while iter < max_iter && sin_mejora < max_no_improve
        vecinos = generar_vecinos(actual, roi, upi, LB, UB)
        sorted_vecinos = sort(vecinos, by = v -> calcular_objetivo(v, roi), rev = true)

        candidato = nothing
        for vecino in sorted_vecinos
            if vecino.ordenes ∉ lista_tabu
                candidato = vecino
                break
            end
        end

        if candidato == nothing && !isempty(sorted_vecinos)
            candidato = sorted_vecinos[1]
        end

        if candidato == nothing
            println("🟡 Sin vecinos válidos en iteración $iter.")
            break
        end

        actual = candidato
        obj = calcular_objetivo(actual, roi)

        push!(evolucion_objetivo, obj)

        if obj > mejor_obj
            mejor = actual
            mejor_obj = obj
            sin_mejora = 0
            println("✅ Iter $iter: Nueva mejor solución → $mejor_obj")
        else
            sin_mejora += 1
        end

        push!(lista_tabu, actual.ordenes)
        if length(lista_tabu) > tabu_tam
            popfirst!(lista_tabu)
        end

        iter += 1
    end

    println("🎯 Mejor valor encontrado: $mejor_obj")
    println("📦 Órdenes: $(mejor.ordenes)")
    println("🚪 Pasillos: $(mejor.pasillos)")

    # Mostrar evolución visual
    plot(1:length(evolucion_objetivo), evolucion_objetivo,
         title = "Evolución de la función objetivo",
         xlabel = "Iteración", ylabel = "Unidades / Pasillos",
         label = "Valor objetivo", linewidth = 2, legend = :bottomright)

    savefig("results/evolucion_tabu.png")  # guarda imagen también

    return mejor, mejor_obj
end
