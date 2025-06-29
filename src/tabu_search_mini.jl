# tabu_search_mini.jl
# ========================================
# TABU SEARCH PARA INSTANCIAS PEQUEÑAS Y MEDIANAS
# ========================================

using Random

# ========================================
# ALGORITMO PRINCIPAL
# ========================================

"""
Algoritmo de Tabu Search para instancias pequeñas y medianas
"""
function tabu_search(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int;
                     max_iter::Int=150, max_no_improve::Int=20, max_vecinos::Int=50,
                     semilla::Union{Int,Nothing}=nothing, devolver_evolucion::Bool=false,
                     solucion_inicial::Union{Solucion,Nothing}=nothing)
    
    if semilla !== nothing
        Random.seed!(semilla)
    end
    
    O = size(roi, 1)
    tipo_instancia = clasificar_instancia(roi, upi)
    println("🔎 Tipo de instancia detectado: $tipo_instancia")
    
    # Ajustar parámetros según instancia
    if tipo_instancia == :mediana
        max_iter = max(max_iter, 175)
        max_no_improve = max(max_no_improve, 25)
        max_vecinos = min(max_vecinos, 45)
    elseif tipo_instancia == :pequeña
        max_vecinos = min(max_vecinos, 40)
    end
    
    # Inicializar estructuras de control
    control = ControlAdaptativoMejorado()
    tabu_lista = TabuListaInteligente(max(5, O ÷ 8))
    
    # Generar o usar solución inicial
    if solucion_inicial === nothing
        actual = generar_solucion_inicial(roi, upi, LB, UB)
    else
        actual = solucion_inicial
    end
    
    mejor = actual
    mejor_obj = evaluar(mejor, roi)
    control.mejor_valor_historico = mejor_obj
    
    # Métricas y seguimiento
    evolucion_obj = Float64[]
    contador_vecinos_vacios = 0
    mejores_encontrados = [(mejor_obj, 0)]
    
    iter = 0
    sin_mejora = 0
    
    println("🚀 Tabu Search mejorado iniciado...")
    println("📊 Solución inicial: $(round(mejor_obj, digits=3))")
    
    while iter < max_iter && sin_mejora < max_no_improve
        iter += 1
        
        # Generar vecinos usando la función específica para instancias pequeñas/medianas
        vecinos = generar_vecinos_mejorado(actual, roi, upi, LB, UB;
                                          max_vecinos=max_vecinos, control=control)
        
        if isempty(vecinos)
            contador_vecinos_vacios += 1
            println("⚠️ Iter $iter: Sin vecinos factibles (total vacíos: $contador_vecinos_vacios)")
            
            # Estrategia de escape: perturbar solución actual
            if contador_vecinos_vacios >= 3
                println("🔄 Aplicando perturbación de escape...")
                actual = perturbar_solucion(actual, roi, upi, LB, UB)
                contador_vecinos_vacios = 0
                
                # Limpiar parte de la lista tabú para permitir más exploración
                if length(tabu_lista.lista) > 3
                    for _ in 1:min(3, length(tabu_lista.lista)÷2)
                        popfirst!(tabu_lista.lista)
                    end
                end
            end
            continue
        end
        
        # Reset contador de vecinos vacíos si encontramos vecinos
        if contador_vecinos_vacios > 0
            contador_vecinos_vacios = 0
        end
        
        # Evaluar vecinos con criterio de aspiración y penalización por frecuencia
        mejor_vecino = nothing
        mejor_score = -Inf
        
        for vecino in vecinos
            obj_vecino = evaluar(vecino, roi)
            penalizacion = calcular_penalizacion_frecuencia(tabu_lista, vecino.ordenes)
            score = obj_vecino - penalizacion
            
            # Criterio de aspiración: aceptar si es mejor que el mejor global
            es_aspiracion = obj_vecino > mejor_obj * 1.001  # 0.1% mejor
            
            if (!es_tabu(tabu_lista, vecino.ordenes) || es_aspiracion) && score > mejor_score
                mejor_vecino = vecino
                mejor_score = score
            end
        end
        
        # Si no hay vecino válido, tomar el mejor aunque sea tabú (intensificación)
        if mejor_vecino === nothing && control.intensidad == :intensificar
            vecinos_evaluados = [(v, evaluar(v, roi)) for v in vecinos]
            sort!(vecinos_evaluados, by=x -> x[2], rev=true)
            mejor_vecino = vecinos_evaluados[1][1]
        elseif mejor_vecino === nothing
            # En modo diversificación, saltar esta iteración
            continue
        end
        
        # Actualizar solución actual
        actual = mejor_vecino
        obj_actual = evaluar(actual, roi)
        push!(evolucion_obj, obj_actual)
        
        # Agregar a lista tabú
        agregar_tabu!(tabu_lista, actual.ordenes)
        
        # Verificar mejora
        es_mejor = obj_actual > mejor_obj
        if es_mejor
            mejor = actual
            mejor_obj = obj_actual
            sin_mejora = 0
            push!(mejores_encontrados, (mejor_obj, iter))
            println("✅ Iter $iter: Nuevo mejor → $(round(mejor_obj, digits=3)) [$(control.intensidad)]")
        else
            sin_mejora += 1
        end
        
        # Actualizar control adaptativo
        actualizar_control_mejorado!(control, obj_actual, es_mejor)
        
        # Log de progreso cada 25 iteraciones
        if iter % 25 == 0
            println("📈 Iter $iter: Actual=$(round(obj_actual, digits=3)), " *
                   "Mejor=$(round(mejor_obj, digits=3)), " *
                   "Sin mejora=$sin_mejora, Modo=$(control.intensidad)")
        end
    end
    
    # Estadísticas finales
    println("\n🎯 Búsqueda completada!")
    println("🏆 Mejor valor encontrado: $(round(mejor_obj, digits=3))")
    println("📦 Órdenes seleccionadas: $(length(mejor.ordenes))")
    println("🚪 Pasillos utilizados: $(length(mejor.pasillos))")
    println("📊 Iteraciones realizadas: $iter")
    println("⚠️ Iteraciones sin vecinos: $contador_vecinos_vacios")
    println("🔄 Mejoras encontradas: $(length(mejores_encontrados))")
    
    # Verificación final
    if es_factible_rapido(mejor, roi, upi, LB, UB)
        println("✅ Solución final FACTIBLE verificada")
    else
        println("❌ ADVERTENCIA: Solución final NO FACTIBLE")
    end
    
    if devolver_evolucion
        return mejor, mejor_obj, evolucion_obj, contador_vecinos_vacios, mejores_encontrados
    else
        return mejor, contador_vecinos_vacios
    end
end

# ========================================
# FUNCIONES AUXILIARES ESPECÍFICAS
# ========================================

"""
Análisis post-optimización para instancias pequeñas/medianas
"""
function analizar_solucion_mini(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int)
    stats = estadisticas_solucion(sol, roi, upi)
    
    println("\n📋 ANÁLISIS DETALLADO DE LA SOLUCIÓN")
    println("-"^50)
    println("📦 Órdenes: $(stats.ordenes_count)")
    println("🚪 Pasillos: $(stats.pasillos_count)")
    println("📊 Unidades totales: $(stats.unidades_totales)")
    println("⚡ Eficiencia (unidades/pasillo): $(round(stats.eficiencia, digits=3))")
    println("🎯 Cobertura promedio: $(round(stats.cobertura_promedio * 100, digits=1))%")
    
    # Análisis de utilización
    if stats.pasillos_count > 0
        utilizacion = stats.unidades_totales / (UB * stats.pasillos_count) * 100
        println("📈 Utilización de capacidad: $(round(utilizacion, digits=1))%")
    end
    
    return stats
end

"""
Función de optimización rápida para instancias muy pequeñas
"""
function optimizacion_rapida_mini(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int)
    O = size(roi, 1)
    
    # Para instancias muy pequeñas (< 20 órdenes), probar enfoque más exhaustivo
    if O <= 20
        println("🔍 Instancia muy pequeña detectada - usando búsqueda exhaustiva parcial")
        
        mejores_soluciones = Solucion[]
        
        # Probar múltiples soluciones iniciales
        for _ in 1:min(10, O)
            try
                sol_inicial = generar_solucion_inicial(roi, upi, LB, UB)
                sol_optimizada, _ = tabu_search(roi, upi, LB, UB;
                                              max_iter=50, max_no_improve=15,
                                              solucion_inicial=sol_inicial)
                push!(mejores_soluciones, sol_optimizada)
            catch
                continue
            end
        end
        
        if !isempty(mejores_soluciones)
            return argmax(sol -> evaluar(sol, roi), mejores_soluciones)
        end
    end
    
    # Fallback a optimización normal
    sol, _ = tabu_search(roi, upi, LB, UB)
    return sol
end