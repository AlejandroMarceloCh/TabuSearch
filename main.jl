include("solution.jl")
include("neighborhood.jl")
include("tabu_search_avanzado.jl")
include("data_loader.jl")

using Random
using Plots

function main()
    ruta = "data/instancia01.txt"
    roi, upi, LB, UB = cargar_instancia(ruta)

    println("✅ Instancia cargada correctamente.\n")
    println("📌 Parámetros:")
    println("    - Número de órdenes (O): ", size(roi, 1))
    println("    - Número de ítems (I): ", size(roi, 2))
    println("    - Número de pasillos (P): ", size(upi, 1))
    println("    - Límite inferior (LB): $LB")
    println("    - Límite superior (UB): $UB\n")

    tiempo = @elapsed begin
        mejor_sol, mejor_obj = tabu_search_balanceado(roi, upi, LB, UB;
                                                      max_iter=100,
                                                      max_no_improve=10,
                                                      max_vecinos=40)
    end

    println("\n📈 Gráfico guardado como 'results/evolucion_tabu_balanceado.png'.")
    println("⏱ Tiempo total de ejecución: $(round(tiempo, digits=4)) segundos")
end

main()
