function tabu_search(roi, upi, LB, UB; max_iter=100, max_no_improve=10, max_vecinos=40)
    O = size(roi, 1)
    I = size(roi, 2)
    P = size(upi, 1)

    visitas = Dict{Set{Int}, Int}()
    lista_tabu = Vector{Set{Int}}()

    tamaño_efectivo = I * (O + P)
    tipo_instancia = clasificar_instancia(roi, upi)
    println("🔎 Tipo de instancia detectado: $tipo_instancia (tamaño efectivo: $tamaño_efectivo)")

    control = ControlAdaptativo()

    # ✅ Solución inicial factible construida progresivamente
    actual = generar_solucion_inicial(roi, upi, LB, UB)
    mejor = actual
    mejor_obj = evaluar(mejor, roi)
    evolucion_obj = Float64[]

    iter = 0
    sin_mejora = 0
    println("\n🚀 Tabu Search iniciado...")

    while iter < max_iter && sin_mejora < max_no_improve
        vecinos = generar_vecinos(actual, roi, upi, LB, UB;
                                  max_vecinos=max_vecinos, control=control)

        if isempty(vecinos)
            println("⚠️ Iter $iter: Sin vecinos factibles.")
            iter += 1
            continue
        end

        # Se penaliza ligeramente la frecuencia de visita
        scored_vecinos = [(v, evaluar(v, roi) - get(visitas, v.ordenes, 0) * 0.2) for v in vecinos]
        sorted_vecinos = sort(scored_vecinos, by = x -> x[2], rev=true)

        # Selección con lista tabú
        candidato = findfirst(v -> v[1].ordenes ∉ lista_tabu, sorted_vecinos)
        nuevo = candidato !== nothing ? sorted_vecinos[candidato][1] : sorted_vecinos[1][1]

        visitas[nuevo.ordenes] = get(visitas, nuevo.ordenes, 0) + 1
        obj_nuevo = evaluar(nuevo, roi)
        push!(evolucion_obj, obj_nuevo)

        mejora = obj_nuevo - evaluar(actual, roi)
        actualizar_control!(control, float(mejora))

        if obj_nuevo > mejor_obj
            mejor = nuevo
            mejor_obj = obj_nuevo
            sin_mejora = 0
            println("✅ Iter $iter: Nuevo mejor → $(round(mejor_obj, digits=5))")
        else
            sin_mejora += 1
        end

        # 📌 Actualización lista tabú adaptativa
        L = clamp(length(actual.ordenes) ÷ 2 + rand(-2:2), 1, O)
        push!(lista_tabu, copy(actual.ordenes))
        length(lista_tabu) > L && popfirst!(lista_tabu)

        actual = nuevo
        iter += 1
    end

    println("\n🎯 Mejor valor encontrado: $(round(mejor_obj, digits=5))")
    println("📦 Órdenes: ", mejor.ordenes)
    println("🚪 Pasillos: ", mejor.pasillos)

    plot(1:length(evolucion_obj), evolucion_obj,
         title = "Evolución de la función objetivo",
         xlabel = "Iteración", ylabel = "Evaluación",
         label = "Objetivo", linewidth = 2, legend = :bottomright)
    savefig("results/evolucion_tabu.png")

    return mejor, mejor_obj
end
