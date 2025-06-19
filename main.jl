# -------------------------------
# Archivo principal: main.jl
# -------------------------------

include("solution.jl")
include("neighborhood.jl")
include("tabu_search_avanzado.jl")
include("data_loader.jl")

using Random
using Plots
using StatsBase

function main()
    ruta = "data/instancia20.txt" 
    roi, upi, LB, UB = cargar_instancia(ruta)

    O, I, P = size(roi, 1), size(roi, 2), size(upi, 1)
    tamaño_efectivo = I * (O + P)

    println("✅ Instancia cargada correctamente.\n")
    println("📌 Parámetros:")
    println("    - Número de órdenes (O): $O")
    println("    - Número de ítems (I): $I")
    println("    - Número de pasillos (P): $P")
    println("    - Límite inferior (LB): $LB")
    println("    - Límite superior (UB): $UB")
    println("    - Tamaño efectivo: $tamaño_efectivo\n")

    # Ajuste dinámico según el tamaño de la instancia
    if tamaño_efectivo <= 100_000
        max_iter = 150
        max_no_improve = 30
        max_vecinos = 25
    elseif tamaño_efectivo <= 1_000_000
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
