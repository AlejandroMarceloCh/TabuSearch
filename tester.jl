include("data_loader.jl")
include("neighborhood.jl")
include("solution.jl")
include("tabu_search_avanzado.jl")

using Combinatorics
using Plots
using Printf
using Random
using Statistics
using StatsBase

function correr_repetidas_veces(path_instancia::String, repeticiones::Int)
    
    roi, upi, LB, UB = cargar_instancia(path_instancia)
    resultados = Float64[]

    println("🔁 Corriendo instancia $path_instancia $repeticiones veces...\n")

    contador_vecinos_vacios = 0  # acumulador total
    for i in 1:repeticiones
        print("▶️  Iteración $i... ")

        sol, vecinos_vacios = tabu_search(roi, upi, LB, UB; max_iter=200, max_no_improve=40, max_vecinos=100)
        valor = evaluar(sol, roi)
        push!(resultados, valor)

        contador_vecinos_vacios += vecinos_vacios  # sumamos

        println("valor obtenido: $(round(valor, digits=3))")
    end

    peor = minimum(resultados)
    mejor = maximum(resultados)
    promedio = mean(resultados)
    desv = std(resultados)

    println("\n📊 Estadísticas finales:")
    println("   ✅ Mejor:    $(round(mejor, digits=3))")
    println("   ❌ Peor:     $(round(peor, digits=3))")
    println("   📈 Promedio: $(round(promedio, digits=3))")
    println("   🧮 Desv.Estd: $(round(desv, digits=3))")
    println("   🚫 Vecinos no factibles acumulados: $contador_vecinos_vacios")

    return resultados
end

# Cambia el nombre de la instancia o número de repeticiones según necesites:
correr_repetidas_veces("data/instancia05.txt", 50)
