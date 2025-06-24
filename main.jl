# -------------------------------
# Archivo principal: main.jl
# -------------------------------

include("solution.jl")
include("neighborhood.jl")
include("tabu_search_avanzado.jl")
include("data_loader.jl")

using Combinatorics
using Plots
using Printf
using Random
using Statistics
using StatsBase

function main()
    ruta = "data/instancia05.txt" 
    roi, upi, LB, UB = cargar_instancia(ruta)

    tipo = clasificar_instancia(roi, upi)

    println("✅ Instancia cargada correctamente.\n")
    println("📌 Parámetros:")
    println("    - Número de órdenes (O): ", size(roi, 1))
    println("    - Número de ítems (I): ", size(roi, 2))
    println("    - Número de pasillos (P): ", size(upi, 1))
    println("    - Límite inferior (LB): $LB")
    println("    - Límite superior (UB): $UB")
    println("    - Tipo de instancia: $tipo\n")

    # Ajuste dinámico según el tipo de instancia
    if tipo == :pequeña
        max_iter = 150
        max_no_improve = 30
        max_vecinos = 25
    elseif tipo == :mediana
        max_iter = 100
        max_no_improve = 20
        max_vecinos = 15
    else
        max_iter = 60
        max_no_improve = 10
        max_vecinos = 8
    end

    tiempo = @elapsed begin
        mejor_sol, mejor_obj = tabu_search(
            roi, upi, LB, UB;
            max_iter=max_iter,
            max_no_improve=max_no_improve,
            max_vecinos=max_vecinos
        )
    end

    println("\n📈 Gráfico guardado como 'results/evolucion_tabu.png'.")
    println("⏱ Tiempo total de ejecución: $(round(tiempo, digits=4)) segundos")
end

main()
