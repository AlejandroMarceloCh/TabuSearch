include("solution.jl")
include("neighborhood.jl")
using Random
using Plots
using Statistics
using StatsBase

function calcular_pasillos_balanceado(ordenes::Set{Int}, roi::Matrix{Int}, upi::Matrix{Int})
    I = size(roi, 2)
    demanda_total = zeros(Int, I)
    for o in ordenes
        demanda_total .+= roi[o, :]
    end

    pasillos = Set{Int}()
    for i in 1:I
        if demanda_total[i] == 0
            continue
        end

        cobertura = 0
        for p in 1:size(upi, 1)
            if upi[p, i] > 0
                push!(pasillos, p)
                cobertura += upi[p, i]
                if cobertura >= demanda_total[i]
                    break
                end
            end
        end
    end

    return pasillos
end

function tabu_search_balanceado(roi, upi, LB, UB; max_iter=150, max_no_improve=10, max_vecinos=40)
    O = size(roi, 1)
    visitas = Dict{Set{Int}, Int}()
    lista_tabu = Vector{Set{Int}}()
    top_strokes = Vector{Set{Int}}()

    function generar_solucion_inicial()
        ordenes = Set{Int}()
        while isempty(ordenes)
            for o in 1:O
                rand() < 0.3 && push!(ordenes, o)
            end
        end
        pasillos = calcular_pasillos_balanceado(ordenes, roi, upi)
        return Solucion(ordenes, pasillos)
    end

    actual = generar_solucion_inicial()
    while !es_factible(actual, roi, upi, LB, UB)
        actual = generar_solucion_inicial()
    end

    mejor = actual
    mejor_obj = calcular_objetivo(mejor, roi)
    evolucion_obj = Float64[]

    iter = 0
    sin_mejora = 0
    println("\n🚀 Tabu Search Balanceado iniciado...")

    while iter < max_iter && sin_mejora < max_no_improve
        vecinos = generar_vecinos_balanceado(actual, roi, upi, LB, UB; max_vecinos=max_vecinos)
        scored_vecinos = [(v, calcular_objetivo(v, roi) - get(visitas, v.ordenes, 0) * 0.2) for v in vecinos]
        sorted_vecinos = sort(scored_vecinos, by = x -> x[2], rev=true)

        candidato = findfirst(v -> v[1].ordenes ∉ lista_tabu, sorted_vecinos)
        actual = candidato !== nothing ? sorted_vecinos[candidato][1] : sorted_vecinos[1][1]

        visitas[actual.ordenes] = get(visitas, actual.ordenes, 0) + 1
        obj = calcular_objetivo(actual, roi)
        push!(evolucion_obj, obj)

        if obj > mejor_obj
            mejor = actual
            mejor_obj = obj
            sin_mejora = 0
            println("✅ Iter $iter: Nuevo mejor → $mejor_obj")
            push!(top_strokes, copy(actual.ordenes))
            length(top_strokes) > 5 && popfirst!(top_strokes)
        else
            sin_mejora += 1
        end

        L = clamp(length(actual.ordenes) ÷ 2 + rand(-2:2), 1, O)
        push!(lista_tabu, copy(actual.ordenes))
        length(lista_tabu) > L && popfirst!(lista_tabu)
        iter += 1
    end

    println("\n🎯 Mejor valor encontrado: $mejor_obj")
    println("📦 Órdenes: ", mejor.ordenes)
    println("🚪 Pasillos: ", mejor.pasillos)

    plot(1:length(evolucion_obj), evolucion_obj,
         title = "Evolución de la función objetivo",
         xlabel = "Iteración", ylabel = "Unidades / Pasillos",
         label = "Objetivo", linewidth = 2, legend = :bottomright)
    savefig("results/evolucion_tabu_balanceado.png")

    return mejor, mejor_obj
end
