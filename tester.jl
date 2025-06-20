
include("solution.jl")
include("neighborhood.jl")
include("tabu_search_avanzado.jl")
include("data_loader.jl")

using Random
using StatsBase
using Combinatorics
using Plots

function testear_instancia(ruta::String, repeticiones::Int = 50)
    roi, upi, LB, UB = cargar_instancia(ruta)
    tipo = clasificar_instancia(roi, upi)

    max_iter, max_no_improve, max_vecinos = if tipo == :pequeña
        (150, 30, 25)
    elseif tipo == :mediana
        (100, 20, 15)
    else
        (60, 10, 8)
    end

    println("🔁 Ejecutando \$repeticiones repeticiones sobre la instancia \$ruta")

    resultados = Float64[]
    curvas = Vector{Vector{Float64}}()  # Guardar evolución de cada ejecución

    for rep in 1:repeticiones
        mejor_sol, mejor_obj, evolucion = tabu_search(
            roi, upi, LB, UB;
            max_iter=max_iter,
            max_no_improve=max_no_improve,
            max_vecinos=max_vecinos,
            semilla=rep,
            devolver_evolucion=true
        )
        push!(resultados, mejor_obj)
        push!(curvas, evolucion)
    end

    # Graficar curvas seleccionadas
    top_indices = sortperm(resultados, rev=true)[1:min(10, repeticiones)]
    plot()
    for i in top_indices
        plot!(1:length(curvas[i]), curvas[i], label="Run \$i", lw=2)
    end

    xlabel!("Iteración")
    ylabel!("Función objetivo")
    title!("Evolución de Tabu Search en \$repeticiones ejecuciones")
    savefig("results/evolucion_comparativa.png")
    println("\n📊 Gráfico generado: results/evolucion_comparativa.png")

    println("\n📊 Resumen de resultados:")
    println("   🔺 Máximo: ", maximum(resultados))
    println("   🔻 Mínimo: ", minimum(resultados))
    println("   📈 Promedio: ", round(mean(resultados), digits=2))
end

# Ejecutar
testear_instancia("data/instancia20.txt", 50)
