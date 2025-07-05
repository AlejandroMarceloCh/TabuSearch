# ========================================
# SOLVERS/PEQUENAS.JL - SOLVER PRINCIPAL
# INTEGRADO COMPLETAMENTE CON LA BASE CAMALEÓNICA
# ========================================

include("../../core/base.jl")
include("../../core/classifier.jl")
include("pequenas_constructivas.jl")
include("pequenas_vecindarios.jl")

using Random

# ========================================
# SOLVER PRINCIPAL PARA PEQUEÑAS
# APROVECHA 100% LA BASE CAMALEÓNICA
# ========================================

"""
Solver especializado para instancias pequeñas
USA COMPLETAMENTE la base camaleónica - NO duplica funciones
"""
function resolver_pequena(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int; semilla=nothing, mostrar_detalles=true)
    # 1. CLASIFICAR AUTOMÁTICAMENTE usando la base
    config = clasificar_instancia(roi, upi, LB, UB)
    
    if mostrar_detalles
        mostrar_info_instancia(config)
        println("\n🎯 CONFIGURACIÓN AUTOMÁTICA APLICADA:")
        println("   📦 Constructiva: $(config.estrategia_constructiva)")
        println("   ✅ Factibilidad: $(config.estrategia_factibilidad)")
        println("   🚪 Pasillos: $(config.estrategia_pasillos)")
        println("   🔄 Vecindarios: $(config.estrategia_vecindarios)")
        println("   🎲 Tabu: $(config.estrategia_tabu)")
        println("   ⚙️ Max iter: $(config.max_iteraciones) | Tabu size: $(config.tabu_size)")
        println("   ⏰ Timeout: $(config.timeout_adaptativo)s")
    end
    
    tiempo_inicio = time()
    
    # 2. GENERAR SOLUCIÓN INICIAL usando estrategia automática
    solucion_inicial = ejecutar_estrategia_constructiva_pequena(roi, upi, LB, UB, config; semilla=semilla)
    
    if solucion_inicial === nothing
        error("❌ No se pudo generar solución inicial para pequeña")
    end
    
    valor_inicial = evaluar(solucion_inicial, roi)  # USAR BASE
    
    if mostrar_detalles
        println("\n✅ SOLUCIÓN INICIAL GENERADA:")
        mostrar_solucion(solucion_inicial, roi, "INICIAL")  # USAR BASE
        println("📊 Factible: $(es_factible(solucion_inicial, roi, upi, LB, UB, config))")  # USAR BASE
    end
    
    # 3. APLICAR TABU SEARCH usando estrategia automática
    solucion_final = ejecutar_estrategia_tabu_pequena(solucion_inicial, roi, upi, LB, UB, config; 
                                                     semilla=semilla, mostrar_progreso=mostrar_detalles)
    
    # 4. RESULTADOS FINALES
    tiempo_total = time() - tiempo_inicio
    valor_final = evaluar(solucion_final, roi)  # USAR BASE
    mejora = valor_final - valor_inicial
    
    if mostrar_detalles
        println("\n🏆 RESULTADO FINAL PEQUEÑA")
        println("="^60)
        mostrar_solucion(solucion_final, roi, "FINAL")  # USAR BASE
        println("📈 Mejora: +$(round(mejora, digits=3)) ($(round((mejora/valor_inicial)*100, digits=1))%)")
        println("⏱️ Tiempo total: $(round(tiempo_total, digits=2))s")
        
        # Verificación final usando la base
        factible = es_factible(solucion_final, roi, upi, LB, UB, config)  # USAR BASE
        println("$(factible ? "✅" : "❌") Solución $(factible ? "FACTIBLE" : "NO FACTIBLE")")
    end
    
    return (
        solucion = solucion_final,
        valor = valor_final,
        tiempo = tiempo_total,
        mejora = mejora,
        config = config,
        factible = es_factible(solucion_final, roi, upi, LB, UB, config)  # USAR BASE
    )
end

# ========================================
# EJECUTOR DE ESTRATEGIA CONSTRUCTIVA
# USA ConfigInstancia para decidir estrategia
# ========================================

"""
Ejecuta la estrategia constructiva configurada automáticamente
"""
function ejecutar_estrategia_constructiva_pequena(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia; semilla=nothing)
    
    println("🔧 Ejecutando estrategia: $(config.estrategia_constructiva)")
    
    # Usar estrategia según configuración automática
    if config.estrategia_constructiva == :multiples_greedy_estandar
        if :ratio_extremo in config.tipos_patologia && UB <= 5
            # Caso especial: UB extremo requiere enumeración
            return constructiva_enumeracion_extrema(roi, upi, LB, UB, config; semilla=semilla)
        else
            return constructiva_multiples_greedy_estandar(roi, upi, LB, UB, config; semilla=semilla)
        end
    else
        # Fallback a estrategia estándar
        return constructiva_multiples_greedy_estandar(roi, upi, LB, UB, config; semilla=semilla)
    end
end

# ========================================
# EJECUTOR DE ESTRATEGIA TABU
# USA ConfigInstancia para decidir estrategia
# ========================================

"""
Ejecuta la estrategia Tabu configurada automáticamente
"""
function ejecutar_estrategia_tabu_pequena(solucion_inicial::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia; semilla=nothing, mostrar_progreso=true)
    
    println("\n🎲 Ejecutando Tabu Search: $(config.estrategia_tabu)")
    
    # Usar estrategia según configuración automática
    if config.estrategia_tabu == :tabu_multiple_restart
        return tabu_multiple_restart_pequena(solucion_inicial, roi, upi, LB, UB, config; 
                                           semilla=semilla, mostrar_progreso=mostrar_progreso)
    else
        # Fallback a Tabu simple
        return tabu_simple_pequena(solucion_inicial, roi, upi, LB, UB, config; 
                                 semilla=semilla, mostrar_progreso=mostrar_progreso)
    end
end

# ========================================
# TABU SEARCH MULTIPLE RESTART
# USA PARÁMETROS DE ConfigInstancia
# ========================================

"""
Tabu Search con múltiple restart para pequeñas
USA COMPLETAMENTE los parámetros de ConfigInstancia
"""
function tabu_multiple_restart_pequena(solucion_inicial::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia; semilla=nothing, mostrar_progreso=true)
    
    mejor_global = solucion_inicial
    mejor_valor_global = evaluar(mejor_global, roi)  # USAR BASE
    
    # Usar configuración automática de la base
    n_restarts = config.es_patologica ? 5 : 3
    max_iter_por_restart = config.max_iteraciones ÷ n_restarts
    
    if mostrar_progreso
        println("🔁 MULTIPLE RESTART CONFIGURADO AUTOMÁTICAMENTE:")
        println("   🔄 Restarts: $n_restarts")
        println("   📊 Iteraciones por restart: $max_iter_por_restart")
        println("   ⚙️ Tabu size: $(config.tabu_size)")
        println("   👥 Max vecinos: $(config.max_vecinos)")
    end
    
    for restart in 1:n_restarts
        semilla_actual = semilla !== nothing ? semilla + restart * 179 : nothing
        
        if mostrar_progreso && restart > 1
            println("\n🚀 RESTART $restart/$n_restarts")
        end
        
        # Generar solución inicial para restart
        solucion_inicio = if restart == 1
            solucion_inicial
        else
            # Usar función auxiliar específica para pequeñas
            perturbar_solucion_pequena(mejor_global, roi, upi, LB, UB, config, restart)
        end
        
        # Ejecutar Tabu Search para este restart
        sol_resultado = tabu_simple_pequena(solucion_inicio, roi, upi, LB, UB, config, max_iter_por_restart; 
                                          semilla=semilla_actual, mostrar_progreso=(restart<=2))
        
        valor_resultado = evaluar(sol_resultado, roi)  # USAR BASE
        
        if mostrar_progreso
            println("   📊 Restart $restart: ratio=$(round(valor_resultado, digits=3))")
        end
        
        if valor_resultado > mejor_valor_global
            mejor_global = sol_resultado
            mejor_valor_global = valor_resultado
            if mostrar_progreso
                println("   ⭐ NUEVO MEJOR GLOBAL: $(round(mejor_valor_global, digits=3))")
            end
        end
    end
    
    return mejor_global
end

# ========================================
# TABU SEARCH SIMPLE
# USA COMPLETAMENTE ConfigInstancia
# ========================================

"""
Tabu Search simple usando TODOS los parámetros de ConfigInstancia
"""
function tabu_simple_pequena(solucion_inicial::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_iter_override=nothing; semilla=nothing, mostrar_progreso=true)
    
    if semilla !== nothing
        Random.seed!(semilla)
    end
    
    # USAR PARÁMETROS DE ConfigInstancia - NO hardcoding
    max_iter = max_iter_override !== nothing ? max_iter_override : config.max_iteraciones
    max_sin_mejora = config.max_sin_mejora
    tabu_size = config.tabu_size
    max_vecinos = config.max_vecinos
    timeout = config.timeout_adaptativo
    
    # Inicializar
    actual = solucion_inicial
    mejor = copiar_solucion(actual)  # USAR BASE
    mejor_valor = evaluar(mejor, roi)  # USAR BASE
    
    # Lista tabú simple para pequeñas
    tabu_lista = Vector{Set{Int}}()
    
    iteraciones_sin_mejora = 0
    iter = 0
    tiempo_inicio = time()
    
    if mostrar_progreso
        println("⚙️ PARÁMETROS DE ConfigInstancia:")
        println("   📊 Max iter: $max_iter | Max sin mejora: $max_sin_mejora")
        println("   📝 Tabu size: $tabu_size | Max vecinos: $max_vecinos")
        println("   ⏰ Timeout: $(timeout)s")
    end
    
    while iter < max_iter && iteraciones_sin_mejora < max_sin_mejora
        iter += 1
        tiempo_transcurrido = time() - tiempo_inicio
        
        if tiempo_transcurrido > timeout
            if mostrar_progreso
                println("⏰ Timeout alcanzado ($(timeout)s)")
            end
            break
        end
        
        # Generar vecinos usando estrategia configurada
        vecinos = generar_vecinos_pequena_inteligente(actual, roi, upi, LB, UB, config)
        
        if isempty(vecinos)
            # Perturbación usando función específica
            actual = perturbar_solucion_pequena(actual, roi, upi, LB, UB, config, iter)
            continue
        end
        
        # Seleccionar mejor vecino no tabú
        mejor_vecino = nothing
        mejor_valor_vecino = -Inf
        
        for vecino in vecinos
            if !es_tabu_pequena(vecino.ordenes, tabu_lista)
                valor_vecino = evaluar(vecino, roi)  # USAR BASE
                if valor_vecino > mejor_valor_vecino
                    mejor_vecino = vecino
                    mejor_valor_vecino = valor_vecino
                end
            end
        end
        
        # Criterio de aspiración sensible para pequeñas
        if mejor_vecino === nothing
            for vecino in vecinos
                valor_vecino = evaluar(vecino, roi)  # USAR BASE
                if valor_vecino > mejor_valor * 1.001  # 0.1% mejora
                    mejor_vecino = vecino
                    mejor_valor_vecino = valor_vecino
                    if mostrar_progreso
                        println("   ⭐ Aspiración: ratio=$(round(valor_vecino, digits=3))")
                    end
                    break
                end
            end
        end
        
        if mejor_vecino === nothing
            actual = perturbar_solucion_pequena(actual, roi, upi, LB, UB, config, iter)
            continue
        end
        
        # Actualizar solución actual
        actual = mejor_vecino
        agregar_tabu_pequena!(tabu_lista, actual.ordenes, tabu_size)
        
        # Verificar mejora global
        if mejor_valor_vecino > mejor_valor
            mejor = copiar_solucion(actual)  # USAR BASE
            mejor_valor = mejor_valor_vecino
            iteraciones_sin_mejora = 0
            
            if mostrar_progreso
                mostrar_solucion(mejor, roi, "MEJOR ⭐")  # USAR BASE
            end
        else
            iteraciones_sin_mejora += 1
        end
        
        # Log periódico
        if mostrar_progreso && iter % 20 == 0
            println("   📊 Iter $iter | Mejor: $(round(mejor_valor, digits=3)) | Sin mejora: $iteraciones_sin_mejora")
        end
        
        # Intensificación cada 15 iteraciones sin mejora
        if iteraciones_sin_mejora > 0 && iteraciones_sin_mejora % 15 == 0
            actual = intensificar_busqueda_pequena(mejor, roi, upi, LB, UB, config)
        end
    end
    
    tiempo_total = time() - tiempo_inicio
    
    if mostrar_progreso
        println("\n🎯 TABU SEARCH COMPLETADO")
        println("⏱️ Tiempo: $(round(tiempo_total, digits=2))s | Iteraciones: $iter")
    end
    
    return mejor
end

# ========================================
# FUNCIONES AUXILIARES ESPECÍFICAS
# USAN LA BASE CAMALEÓNICA
# ========================================

"""
Perturbación inteligente para pequeñas usando ConfigInstancia
"""
function perturbar_solucion_pequena(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, semilla::Int)
    O = size(roi, 1)
    Random.seed!(semilla * 211)
    
    # Intensidad basada en configuración
    intensidad = config.es_patologica ? 0.3 : 0.2
    
    ordenes_actuales = collect(sol.ordenes)
    if length(ordenes_actuales) < 2
        return sol
    end
    
    # Perturbación controlada
    n_cambios = max(1, Int(ceil(length(ordenes_actuales) * intensidad)))
    n_cambios = min(n_cambios, 2)  # Máximo 2 para pequeñas
    
    ordenes_a_cambiar = sample(ordenes_actuales, min(n_cambios, length(ordenes_actuales)-1), replace=false)
    nuevas_ordenes = setdiff(sol.ordenes, Set(ordenes_a_cambiar))
    
    # Agregar órdenes compatibles
    candidatos_ordenes = setdiff(1:O, nuevas_ordenes)
    
    for o_candidato in sample(candidatos_ordenes, min(5, length(candidatos_ordenes)), replace=false)
        if es_orden_compatible(o_candidato, sol.pasillos, roi, upi)  # USAR BASE
            valor_nuevo = sum(sum(roi[o, :]) for o in nuevas_ordenes) + sum(roi[o_candidato, :])
            if valor_nuevo <= UB
                push!(nuevas_ordenes, o_candidato)
                break
            end
        end
    end
    
    # Verificar factibilidad usando la base
    if !isempty(nuevas_ordenes)
        # USAR BASE para calcular pasillos óptimos
        nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
        candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
        
        # USAR BASE para verificar factibilidad
        if es_factible(candidato, roi, upi, LB, UB, config)
            return candidato
        end
    end
    
    return sol
end

"""
Intensificación específica para pequeñas usando la base
"""
function intensificar_busqueda_pequena(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    O = size(roi, 1)
    
    mejor_local = copiar_solucion(sol)  # USAR BASE
    mejor_valor = evaluar(mejor_local, roi)  # USAR BASE
    
    # 1. Re-optimizar pasillos usando la base
    pasillos_optimizados = calcular_pasillos_optimos(sol.ordenes, roi, upi, LB, UB, config)  # USAR BASE
    if pasillos_optimizados != sol.pasillos
        candidato = Solucion(sol.ordenes, pasillos_optimizados)
        if es_factible(candidato, roi, upi, LB, UB, config)  # USAR BASE
            valor_candidato = evaluar(candidato, roi)  # USAR BASE
            if valor_candidato > mejor_valor
                mejor_local = candidato
                mejor_valor = valor_candidato
            end
        end
    end
    
    # 2. Intentar agregar una orden compatible
    candidatos_agregar = setdiff(1:O, sol.ordenes)
    for o_agregar in candidatos_agregar[1:min(3, length(candidatos_agregar))]
        if es_orden_compatible(o_agregar, mejor_local.pasillos, roi, upi)  # USAR BASE
            nuevas_ordenes = copy(mejor_local.ordenes)
            push!(nuevas_ordenes, o_agregar)
            
            valor_test = sum(sum(roi[o, :]) for o in nuevas_ordenes)
            if LB <= valor_test <= UB
                candidato = Solucion(nuevas_ordenes, mejor_local.pasillos)
                if es_factible(candidato, roi, upi, LB, UB, config)  # USAR BASE
                    valor_candidato = evaluar(candidato, roi)  # USAR BASE
                    if valor_candidato > mejor_valor
                        mejor_local = candidato
                        mejor_valor = valor_candidato
                        break
                    end
                end
            end
        end
    end
    
    return mejor_local
end

"""
Funciones tabú auxiliares
"""
function es_tabu_pequena(ordenes::Set{Int}, tabu_lista::Vector{Set{Int}})
    return ordenes in tabu_lista
end

function agregar_tabu_pequena!(tabu_lista::Vector{Set{Int}}, ordenes::Set{Int}, tabu_size::Int)
    push!(tabu_lista, copy(ordenes))
    if length(tabu_lista) > tabu_size
        popfirst!(tabu_lista)
    end
end

# ========================================
# PEQUENAS_CONSTRUCTIVAS.JL INTEGRADAS
# USA COMPLETAMENTE LA BASE CAMALEÓNICA
# ========================================

"""
Constructiva con enumeración para UB extremos (≤5)
USA la base para verificar factibilidad y calcular pasillos
"""
function constructiva_enumeracion_extrema(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia; semilla=nothing)
    O = size(roi, 1)
    
    println("   ⚡ ENUMERACIÓN EXTREMA para UB=$UB")
    
    mejor_solucion = nothing
    mejor_ratio = 0.0
    
    # 1. Evaluar órdenes individuales
    for o in 1:O
        valor = sum(roi[o, :])
        if LB <= valor <= UB
            ordenes = Set([o])
            # USAR BASE para calcular pasillos
            pasillos = calcular_pasillos_optimos(ordenes, roi, upi, LB, UB, config)
            
            candidato = Solucion(ordenes, pasillos)
            # USAR BASE para verificar factibilidad
            if es_factible(candidato, roi, upi, LB, UB, config)
                ratio = evaluar(candidato, roi)  # USAR BASE
                if ratio > mejor_ratio
                    mejor_solucion = candidato
                    mejor_ratio = ratio
                    println("   ✅ Orden $o: ratio=$(round(ratio, digits=3))")
                end
            end
        end
    end
    
    # 2. Combinaciones de 2 órdenes (si UB permite)
    if UB >= 2
        contador = 0
        for i in 1:O
            for j in (i+1):O
                valor_total = sum(roi[i, :]) + sum(roi[j, :])
                if LB <= valor_total <= UB
                    ordenes = Set([i, j])
                    # USAR BASE
                    pasillos = calcular_pasillos_optimos(ordenes, roi, upi, LB, UB, config)
                    candidato = Solucion(ordenes, pasillos)
                    
                    if es_factible(candidato, roi, upi, LB, UB, config)  # USAR BASE
                        ratio = evaluar(candidato, roi)  # USAR BASE
                        if ratio > mejor_ratio
                            mejor_solucion = candidato
                            mejor_ratio = ratio
                            println("   ✅ Combo [$i,$j]: ratio=$(round(ratio, digits=3))")
                        end
                    end
                    
                    contador += 1
                    if contador >= 20  # Límite de seguridad
                        break
                    end
                end
            end
            if contador >= 20
                break
            end
        end
    end
    
    return mejor_solucion
end

"""
Constructiva múltiples greedy estándar
USA la base para todo el procesamiento
"""
function constructiva_multiples_greedy_estandar(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia; semilla=nothing)
    println("   🔄 MÚLTIPLES GREEDY ESTÁNDAR")
    
    mejor_solucion = nothing
    mejor_ratio = 0.0
    
    # Estrategias adaptadas según configuración
    estrategias = if config.es_patologica
        [
            (:valor_puro, "Greedy valor puro"),
            (:eficiencia_items, "Greedy eficiencia"),
            (:objetivo_90pct, "Objetivo 90% UB"),
            (:objetivo_95pct, "Objetivo 95% UB")
        ]
    else
        [
            (:valor_puro, "Greedy valor puro"),
            (:eficiencia_items, "Greedy eficiencia"),
            (:balanceado, "Greedy balanceado"),
            (:objetivo_dinamico, "Objetivo dinámico")
        ]
    end
    
    for (estrategia, descripcion) in estrategias
        candidato = aplicar_greedy_pequena(roi, upi, LB, UB, config, estrategia)
        
        if candidato !== nothing && es_factible(candidato, roi, upi, LB, UB, config)  # USAR BASE
            ratio = evaluar(candidato, roi)  # USAR BASE
            if ratio > mejor_ratio
                mejor_solucion = candidato
                mejor_ratio = ratio
                println("   ✅ $descripcion: ratio=$(round(ratio, digits=3))")
            end
        end
    end
    
    return mejor_solucion
end

"""
Aplica estrategia greedy específica USANDO LA BASE
"""
function aplicar_greedy_pequena(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, estrategia::Symbol)
    O = size(roi, 1)
    
    # Calcular métricas según estrategia
    metricas = []
    for o in 1:O
        valor = sum(roi[o, :])
        items = count(roi[o, :] .> 0)
        
        metrica = if estrategia == :valor_puro
            valor
        elseif estrategia == :eficiencia_items
            items > 0 ? valor / items : 0
        elseif estrategia == :balanceado
            eficiencia = items > 0 ? valor / items : 0
            valor * 0.7 + eficiencia * 0.3  # Peso balanceado
        else  # :objetivo_90pct, :objetivo_95pct, :objetivo_dinamico
            valor  # Usar valor puro para objetivos
        end
        
        push!(metricas, (o, valor, metrica))
    end
    
    sort!(metricas, by=x -> x[3], rev=true)
    
    # Construir solución greedy
    ordenes_seleccionadas = Set{Int}()
    valor_actual = 0
    
    # Target según estrategia
    target = if estrategia == :objetivo_90pct
        UB * 0.90
    elseif estrategia == :objetivo_95pct
        UB * 0.95
    else
        UB  # Sin target específico
    end
    
    for (o, valor, metrica) in metricas
        if valor_actual + valor <= UB
            # Decisión según estrategia
            agregar = if estrategia in [:objetivo_90pct, :objetivo_95pct]
                abs(valor_actual + valor - target) <= abs(valor_actual - target)
            elseif estrategia == :objetivo_dinamico
                progreso = valor_actual / UB
                target_dinamico = progreso < 0.5 ? UB * 0.85 : UB * 0.95
                valor_actual < target_dinamico
            else
                true  # Greedy normal
            end
            
            if agregar
                push!(ordenes_seleccionadas, o)
                valor_actual += valor
            end
        end
    end
    
    # Crear solución usando la base
    if LB <= valor_actual <= UB && !isempty(ordenes_seleccionadas)
        # USAR BASE para calcular pasillos óptimos
        pasillos = calcular_pasillos_optimos(ordenes_seleccionadas, roi, upi, LB, UB, config)
        return Solucion(ordenes_seleccionadas, pasillos)
    end
    
    return nothing
end

# ========================================
# PEQUENAS_VECINDARIOS.JL INTEGRADOS
# USA COMPLETAMENTE LA BASE CAMALEÓNICA
# ========================================

"""
Generador principal de vecinos para pequeñas
USA ConfigInstancia para determinar estrategia
"""
function generar_vecinos_pequena_inteligente(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    
    # Usar estrategia configurada automáticamente
    if config.estrategia_vecindarios == :vecindarios_exhaustivos
        return generar_vecinos_exhaustivos_pequena(sol, roi, upi, LB, UB, config)
    else
        # Fallback a vecindarios inteligentes
        return generar_vecinos_inteligentes_pequena(sol, roi, upi, LB, UB, config)
    end
end

"""
Vecindarios exhaustivos para pequeñas usando ConfigInstancia
"""
function generar_vecinos_exhaustivos_pequena(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    vecinos = Solucion[]
    max_vecinos = config.max_vecinos
    
    # Distribución de esfuerzo según patología
    if :ratio_extremo in config.tipos_patologia && UB <= 5
        # Para UB extremos: vecindarios controlados
        append!(vecinos, intercambio_1_1_controlado(sol, roi, upi, LB, UB, config, Int(ceil(max_vecinos * 0.5))))
        append!(vecinos, agregar_quitar_controlado(sol, roi, upi, LB, UB, config, Int(ceil(max_vecinos * 0.3))))
        append!(vecinos, reoptimizar_pasillos_pequena(sol, roi, upi, LB, UB, config, Int(ceil(max_vecinos * 0.2))))
    else
        # Para casos normales: exploración completa
        append!(vecinos, intercambio_1_1_completo(sol, roi, upi, LB, UB, config, Int(ceil(max_vecinos * 0.4))))
        append!(vecinos, agregar_quitar_completo(sol, roi, upi, LB, UB, config, Int(ceil(max_vecinos * 0.3))))
        append!(vecinos, intercambio_pasillos_pequena(sol, roi, upi, LB, UB, config, Int(ceil(max_vecinos * 0.3))))
    end
    
    return filtrar_vecinos_pequena(vecinos, roi, upi, LB, UB, config)
end

"""
Vecindarios inteligentes para pequeñas (fallback)
"""
function generar_vecinos_inteligentes_pequena(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    vecinos = Solucion[]
    max_vecinos = config.max_vecinos
    
    # Enfoque más selectivo para casos complejos
    append!(vecinos, intercambio_1_1_controlado(sol, roi, upi, LB, UB, config, max_vecinos ÷ 2))
    append!(vecinos, agregar_quitar_controlado(sol, roi, upi, LB, UB, config, max_vecinos ÷ 2))
    
    return filtrar_vecinos_pequena(vecinos, roi, upi, LB, UB, config)
end

"""
Intercambio 1-1 controlado USANDO LA BASE
"""
function intercambio_1_1_controlado(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_vecinos::Int)
    vecinos = Solucion[]
    O = size(roi, 1)
    
    ordenes_actuales = collect(sol.ordenes)
    candidatos_externos = setdiff(1:O, sol.ordenes)
    
    if isempty(ordenes_actuales) || isempty(candidatos_externos)
        return vecinos
    end
    
    contador = 0
    for o_out in ordenes_actuales
        for o_in in candidatos_externos
            # Verificar límites básicos primero
            valor_sin_out = sum(sum(roi[o, :]) for o in sol.ordenes if o != o_out)
            nuevo_valor_total = valor_sin_out + sum(roi[o_in, :])
            
            if LB <= nuevo_valor_total <= UB
                nuevas_ordenes = copy(sol.ordenes)
                delete!(nuevas_ordenes, o_out)
                push!(nuevas_ordenes, o_in)
                
                # USAR BASE para calcular pasillos óptimos
                nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
                candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
                
                # USAR BASE para verificar factibilidad
                if es_factible(candidato, roi, upi, LB, UB, config)
                    push!(vecinos, candidato)
                    contador += 1
                    
                    if contador >= max_vecinos
                        return vecinos
                    end
                end
            end
        end
    end
    
    return vecinos
end

"""
Intercambio 1-1 completo USANDO LA BASE
"""
function intercambio_1_1_completo(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_vecinos::Int)
    vecinos = Solucion[]
    O = size(roi, 1)
    
    ordenes_actuales = collect(sol.ordenes)
    candidatos_externos = setdiff(1:O, sol.ordenes)
    
    if isempty(ordenes_actuales) || isempty(candidatos_externos)
        return vecinos
    end
    
    contador = 0
    # Exploración completa pero limitada
    for o_out in ordenes_actuales
        for o_in in candidatos_externos
            nuevas_ordenes = copy(sol.ordenes)
            delete!(nuevas_ordenes, o_out)
            push!(nuevas_ordenes, o_in)
            
            # Verificar límites básicos
            valor_total = sum(sum(roi[o, :]) for o in nuevas_ordenes)
            if LB <= valor_total <= UB
                # USAR BASE para calcular pasillos
                nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
                candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
                
                # USAR BASE para verificar factibilidad
                if es_factible(candidato, roi, upi, LB, UB, config)
                    push!(vecinos, candidato)
                    contador += 1
                    
                    if contador >= max_vecinos
                        return vecinos
                    end
                end
            end
        end
    end
    
    return vecinos
end

"""
Agregar/quitar controlado USANDO LA BASE
"""
function agregar_quitar_controlado(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_vecinos::Int)
    vecinos = Solucion[]
    O = size(roi, 1)
    
    valor_actual = sum(sum(roi[o, :]) for o in sol.ordenes)
    margen_disponible = UB - valor_actual
    
    contador = 0
    
    # AGREGAR órdenes (si hay margen)
    if margen_disponible > 0
        candidatos_externos = setdiff(1:O, sol.ordenes)
        
        for o_nuevo in candidatos_externos
            valor_nuevo = sum(roi[o_nuevo, :])
            
            if valor_nuevo <= margen_disponible
                nuevas_ordenes = copy(sol.ordenes)
                push!(nuevas_ordenes, o_nuevo)
                
                # USAR BASE para calcular pasillos
                nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
                candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
                
                # USAR BASE para verificar factibilidad
                if es_factible(candidato, roi, upi, LB, UB, config)
                    push!(vecinos, candidato)
                    contador += 1
                    
                    if contador >= max_vecinos ÷ 2
                        break
                    end
                end
            end
        end
    end
    
    # QUITAR órdenes (si no rompe LB)
    ordenes_actuales = collect(sol.ordenes)
    for o_quitar in ordenes_actuales
        if length(sol.ordenes) > 1  # No dejar solución vacía
            valor_quitar = sum(roi[o_quitar, :])
            nuevo_valor = valor_actual - valor_quitar
            
            if nuevo_valor >= LB
                nuevas_ordenes = setdiff(sol.ordenes, [o_quitar])
                
                # USAR BASE para calcular pasillos
                nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
                candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
                
                # USAR BASE para verificar factibilidad
                if es_factible(candidato, roi, upi, LB, UB, config)
                    push!(vecinos, candidato)
                    contador += 1
                    
                    if contador >= max_vecinos
                        break
                    end
                end
            end
        end
    end
    
    return vecinos
end

"""
Agregar/quitar completo USANDO LA BASE
"""
function agregar_quitar_completo(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_vecinos::Int)
    vecinos = Solucion[]
    O = size(roi, 1)
    
    valor_actual = sum(sum(roi[o, :]) for o in sol.ordenes)
    contador = 0
    
    # AGREGAR órdenes
    candidatos_externos = setdiff(1:O, sol.ordenes)
    for o_nuevo in candidatos_externos
        valor_nuevo = sum(roi[o_nuevo, :])
        
        if valor_actual + valor_nuevo <= UB
            nuevas_ordenes = copy(sol.ordenes)
            push!(nuevas_ordenes, o_nuevo)
            
            # USAR BASE
            nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
            candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
            
            if es_factible(candidato, roi, upi, LB, UB, config)
                push!(vecinos, candidato)
                contador += 1
                
                if contador >= max_vecinos ÷ 2
                    break
                end
            end
        end
    end
    
    # QUITAR órdenes
    ordenes_actuales = collect(sol.ordenes)
    for o_quitar in ordenes_actuales
        if length(sol.ordenes) > 1
            valor_quitar = sum(roi[o_quitar, :])
            nuevo_valor = valor_actual - valor_quitar
            
            if nuevo_valor >= LB
                nuevas_ordenes = setdiff(sol.ordenes, [o_quitar])
                
                # USAR BASE
                nuevos_pasillos = calcular_pasillos_optimos(nuevas_ordenes, roi, upi, LB, UB, config)
                candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
                
                if es_factible(candidato, roi, upi, LB, UB, config)
                    push!(vecinos, candidato)
                    contador += 1
                    
                    if contador >= max_vecinos
                        break
                    end
                end
            end
        end
    end
    
    return vecinos
end

"""
Intercambio de pasillos USANDO LA BASE
"""
function intercambio_pasillos_pequena(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_vecinos::Int)
    vecinos = Solucion[]
    P = size(upi, 1)
    
    if length(sol.pasillos) == 0
        return vecinos
    end
    
    pasillos_actuales = collect(sol.pasillos)
    candidatos_pasillos = setdiff(1:P, sol.pasillos)
    
    contador = 0
    
    # Intercambio 1-1 de pasillos
    for p_out in pasillos_actuales
        for p_in in candidatos_pasillos
            nuevos_pasillos = copy(sol.pasillos)
            delete!(nuevos_pasillos, p_out)
            push!(nuevos_pasillos, p_in)
            
            candidato = Solucion(sol.ordenes, nuevos_pasillos)
            
            # USAR BASE para verificar factibilidad
            if es_factible(candidato, roi, upi, LB, UB, config)
                push!(vecinos, candidato)
                contador += 1
                
                if contador >= max_vecinos
                    return vecinos
                end
            end
        end
    end
    
    return vecinos
end

"""
Re-optimización de pasillos USANDO LA BASE
"""
function reoptimizar_pasillos_pequena(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia, max_vecinos::Int)
    vecinos = Solucion[]
    
    # USAR BASE para recalcular pasillos óptimos
    pasillos_optimizados = calcular_pasillos_optimos(sol.ordenes, roi, upi, LB, UB, config)
    
    if pasillos_optimizados != sol.pasillos
        candidato = Solucion(sol.ordenes, pasillos_optimizados)
        
        # USAR BASE para verificar factibilidad
        if es_factible(candidato, roi, upi, LB, UB, config)
            push!(vecinos, candidato)
        end
    end
    
    # Intentar reducir número de pasillos
    contador = 1
    if length(sol.pasillos) > 1
        for p_remover in sol.pasillos
            pasillos_reducidos = setdiff(sol.pasillos, [p_remover])
            candidato = Solucion(sol.ordenes, pasillos_reducidos)
            
            # USAR BASE para verificar factibilidad
            if es_factible(candidato, roi, upi, LB, UB, config)
                push!(vecinos, candidato)
                contador += 1
                
                if contador >= max_vecinos
                    break
                end
            end
        end
    end
    
    return vecinos
end

"""
Filtra vecinos eliminando duplicados y verificando factibilidad USANDO LA BASE
"""
function filtrar_vecinos_pequena(vecinos::Vector{Solucion}, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::ConfigInstancia)
    if isempty(vecinos)
        return vecinos
    end
    
    # Eliminar duplicados usando hash de órdenes
    vecinos_unicos = []
    hashes_vistos = Set{UInt64}()
    
    for vecino in vecinos
        if !isempty(vecino.ordenes) && !isempty(vecino.pasillos)
            # Hash basado en órdenes para detectar duplicados
            hash_vecino = hash(sort(collect(vecino.ordenes)))
            
            if !(hash_vecino in hashes_vistos)
                push!(hashes_vistos, hash_vecino)
                
                # Verificación final de factibilidad USANDO LA BASE
                if es_factible(vecino, roi, upi, LB, UB, config)
                    push!(vecinos_unicos, vecino)
                    
                    # Limitar según configuración
                    if length(vecinos_unicos) >= config.max_vecinos
                        break
                    end
                end
            end
        end
    end
    
    return vecinos_unicos
end