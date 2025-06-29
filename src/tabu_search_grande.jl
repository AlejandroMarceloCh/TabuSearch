# tabu_search_grande.jl
# ========================================
# TABU SEARCH PARA INSTANCIAS GRANDES Y ENORMES
# ========================================

using Random

# ========================================
# ALGORITMO PRINCIPAL PARA INSTANCIAS GRANDES
# ========================================

"""
Tabu Search para instancias grandes con estrategias de tolerancia
"""
function tabu_search_tolerante(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int;
                              max_iter::Int=200, max_no_improve::Int=30, max_vecinos::Int=40,
                              semilla::Union{Int,Nothing}=nothing, devolver_evolucion::Bool=false,
                              solucion_inicial::Union{Solucion,Nothing}=nothing)
    
    if semilla !== nothing
        Random.seed!(semilla)
    end
    
    O, I = size(roi)
    tipo_instancia = clasificar_instancia(roi, upi)
    es_gigante = (O > 2000 || I > 5000 || O * I > 10_000_000)
    
    println("🔎 Tipo de instancia detectado: $tipo_instancia")
    
    # 🔥 PARÁMETROS ULTRA-AGRESIVOS PARA GIGANTES
    if es_gigante
        # Detectar si es una instancia MASIVA vs gigante normal
        es_masiva = (O > 8000 || I > 8000 || O * I > 70_000_000)
        
        if es_masiva
            max_iter = 150
            max_no_improve = 25
            max_vecinos = 35
            log_interval = 60
            println("🔥 MODO MASIVO: Parámetros intensivos activados")
        else
            max_iter = 80
            max_no_improve = 12
            max_vecinos = 20
            log_interval = 50
            println("🔥 MODO GIGANTE: Parámetros ultra-agresivos activados")
        end
    elseif tipo_instancia == :grande
        max_iter = max(max_iter, 150)  # Reducido de 250 a 150
        max_no_improve = max(max_no_improve, 20)  # Reducido de 40 a 20
        max_vecinos = min(max_vecinos, 30)  # Reducido de 35 a 30
        log_interval = 40
    else
        log_interval = 30  # Original
    end
    
    # Inicializar estructuras de control
    control = ControlAdaptativoMejorado()
    tabu_lista = TabuListaInteligente(max(5, O ÷ 12))
    gestor_vecindarios = GestorVecindarios()
    
    # 🔥 GENERAR SOLUCIÓN INICIAL ADAPTATIVA
    if solucion_inicial === nothing
        if get(INSTANCIA_STATE, "es_patologica", false)
            println("🔥 Generando solución inicial adaptativa para patológica...")
            actual = generar_solucion_gigante_ultra_rapida(roi, upi, LB, UB, !es_gigante)
        else
            actual = generar_mejor_solucion_inicial_adaptativa(roi, upi, LB, UB; verbose=!es_gigante)
        end
    else
        actual = solucion_inicial
    end
    
    if actual === nothing
        error("❌ No se pudo generar solución inicial factible")
    end
    
    mejor = actual
    mejor_obj = evaluar(mejor, roi)
    control.mejor_valor_historico = mejor_obj
    
    # Métricas
    evolucion_obj = Float64[]
    contador_vecinos_vacios = 0
    mejores_encontrados = [(mejor_obj, 0)]
    iteraciones_criticas = 0
    
    iter = 0
    sin_mejora = 0
    
    println("🚀 Tabu Search tolerante iniciado...")
    println("📊 Solución inicial: $(round(mejor_obj, digits=3))")
    
    while iter < max_iter && sin_mejora < max_no_improve
        iter += 1
        
        # Generar vecinos
        vecinos = generar_vecinos_con_tolerancia(actual, roi, upi, LB, UB;
                                               max_vecinos=max_vecinos, 
                                               gestor_vecindarios=gestor_vecindarios)
        
        if isempty(vecinos)
            contador_vecinos_vacios += 1
            iteraciones_criticas += 1
            
            if !es_gigante  # Solo log detallado para no-gigantes
                println("⚠️ Iter $iter: Sin vecinos factibles (total vacíos: $contador_vecinos_vacios)")
            end
            
            # 🔥 ESCAPE MÁS AGRESIVO PARA GIGANTES
            if es_gigante && contador_vecinos_vacios >= 2  # Reducido de 3 a 2
                actual = perturbar_solucion_grande(actual, roi, upi, LB, UB, 0.4)  # Más intenso
                contador_vecinos_vacios = 0
            elseif !es_gigante && contador_vecinos_vacios >= 3
                println("🔄 Aplicando perturbación intensa...")
                actual = perturbar_solucion_grande(actual, roi, upi, LB, UB, 0.5)
                contador_vecinos_vacios = 0
            elseif iteraciones_criticas >= (es_gigante ? 5 : 8)  # Más rápido para gigantes
                if es_gigante
                    # 🔥 USAR GENERACIÓN ADAPTATIVA PARA REINICIO EN PATOLÓGICAS
                    if get(INSTANCIA_STATE, "es_patologica", false)
                        actual = generar_solucion_gigante_ultra_rapida(roi, upi, LB, UB, false)
                    else
                        actual = generar_mejor_solucion_inicial_adaptativa(roi, upi, LB, UB; verbose=false)
                    end
                else
                    println("🆘 Aplicando reinicio parcial...")
                    # 🔥 USAR GENERACIÓN ADAPTATIVA PARA REINICIO EN PATOLÓGICAS
                    if get(INSTANCIA_STATE, "es_patologica", false)
                        actual = generar_solucion_gigante_ultra_rapida(roi, upi, LB, UB, false)
                    else
                        actual = generar_mejor_solucion_inicial_adaptativa(roi, upi, LB, UB; verbose=false)
                    end
                end
                
                if actual === nothing
                    println("❌ No se pudo generar nueva solución inicial")
                    break
                end
                
                iteraciones_criticas = 0
                contador_vecinos_vacios = 0
                tabu_lista = TabuListaInteligente(max(3, O ÷ 15))
            end
            
            continue
        end
        
        # Reset contadores si encontramos vecinos
        if contador_vecinos_vacios > 0
            contador_vecinos_vacios = 0
        end
        if iteraciones_criticas > 0
            iteraciones_criticas = max(0, iteraciones_criticas - 1)
        end
        
        # Evaluar vecinos
        mejor_vecino = nothing
        mejor_score = -Inf
        
        for vecino in vecinos
            obj_vecino = evaluar(vecino, roi)
            penalizacion = calcular_penalizacion_frecuencia(tabu_lista, vecino.ordenes)
            score = obj_vecino - penalizacion
            
            es_aspiracion = (obj_vecino > mejor_obj * 1.001) || 
                           (obj_vecino > control.mejor_valor_historico * 0.995 && sin_mejora > 5) ||
                           (sin_mejora > max_no_improve ÷ 2 && obj_vecino > mejor_obj * 0.99)
            
            if (!es_tabu(tabu_lista, vecino.ordenes) || es_aspiracion) && score > mejor_score
                mejor_vecino = vecino
                mejor_score = score
            end
        end
        
        # Si no hay vecino válido, selección diversificada
        if mejor_vecino === nothing
            if !es_gigante
                println("🔀 Aplicando selección diversificada...")
            end
            vecinos_evaluados = [(v, evaluar(v, roi)) for v in vecinos]
            sort!(vecinos_evaluados, by=x -> x[2], rev=true)
            
            top_k = min(3, length(vecinos_evaluados))
            mejor_vecino = vecinos_evaluados[rand(1:top_k)][1]
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
            
            if es_gigante
                println("✅ Iter $iter: Mejor → $(round(mejor_obj, digits=3))")
            else
                println("✅ Iter $iter: Nuevo mejor → $(round(mejor_obj, digits=3)) [$(control.intensidad)] 🎯")
            end
        else
            sin_mejora += 1
        end
        
        # Actualizar control adaptativo
        actualizar_control_mejorado!(control, obj_actual, es_mejor)
        
        # 🔥 LOG MENOS FRECUENTE PARA GIGANTES
        if iter % log_interval == 0 && !es_gigante
            println("📈 Iter $iter: Actual=$(round(obj_actual, digits=3)), " *
                   "Mejor=$(round(mejor_obj, digits=3)), Sin mejora=$sin_mejora")
            println("🎲 Probabilidades vecindarios: $(round_dict(gestor_vecindarios.probabilidades, 3))")
        elseif iter % log_interval == 0 && es_gigante
            println("📈 Iter $iter: $(round(obj_actual, digits=3)) | Mejor: $(round(mejor_obj, digits=3))")
        end
    end
    
    # 🔥 ESTADÍSTICAS FINALES LIMPIAS
    println("\n🎯 Búsqueda completada!")
    println("🏆 Mejor valor encontrado: $(round(mejor_obj, digits=3))")
    println("📦 Órdenes seleccionadas: $(length(mejor.ordenes))")
    println("🚪 Pasillos utilizados: $(length(mejor.pasillos))")
    println("📊 Iteraciones realizadas: $iter")
    
    # 🔥 SOLO MOSTRAR DETALLES PARA NO-GIGANTES
    if !es_gigante
        println("⚠️ Iteraciones sin vecinos: $contador_vecinos_vacios")
        println("🔄 Mejoras encontradas: $(length(mejores_encontrados))")
        mostrar_estadisticas_vecindarios(gestor_vecindarios)
        
        # Mostrar listas solo si son pequeñas
        if length(mejor.ordenes) <= 50
            ordenes = sort(collect(mejor.ordenes))
            println("   Órdenes detalle: $ordenes")
        end
        
        if length(mejor.pasillos) <= 20
            pasillos = sort(collect(mejor.pasillos))
            println("   Pasillos detalle: $pasillos")
        end
    end
    
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
# FUNCIÓN DE PERTURBACIÓN ESPECÍFICA PARA GRANDES
# ========================================

"""
Perturbación específica para instancias grandes con mayor intensidad
"""
function perturbar_solucion_grande(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, 
                                  LB::Int, UB::Int, intensidad::Float64=0.5)
    O = size(roi, 1)
    ordenes_actuales = collect(sol.ordenes)
    n_ordenes = length(ordenes_actuales)
    
    if n_ordenes < 3
        return sol
    end
    
    # Perturbación más intensa para instancias grandes
    n_cambios = max(2, Int(ceil(n_ordenes * intensidad)))
    
    # Remover múltiples órdenes
    n_remover = min(n_cambios, length(ordenes_actuales) - 1)
    indices_remover = randperm(length(ordenes_actuales))[1:n_remover]
    ordenes_a_remover = ordenes_actuales[indices_remover]
    nuevas_ordenes = setdiff(sol.ordenes, ordenes_a_remover)
    
    # Agregar órdenes aleatorias
    candidatos = setdiff(1:O, nuevas_ordenes)
    if !isempty(candidatos)
        n_agregar = min(n_cambios + rand(-2:3), length(candidatos))
        if n_agregar > 0
            indices_agregar = randperm(length(candidatos))[1:n_agregar]
            ordenes_a_agregar = candidatos[indices_agregar]
            for o in ordenes_a_agregar
                push!(nuevas_ordenes, o)
            end
        end
    end
    
    # Intentar reparar
    for intento in 1:5
        if validar_factibilidad_basica(nuevas_ordenes, roi, upi, LB, UB)
            nuevos_pasillos = calcular_pasillos_optimo(nuevas_ordenes, roi, upi)
            candidato = Solucion(nuevas_ordenes, nuevos_pasillos)
            
            if es_factible_rapido(candidato, roi, upi, LB, UB)
                return candidato
            end
        end
        
        # Ajustar para siguiente intento
        if length(nuevas_ordenes) > 2
            ordenes_lista = collect(nuevas_ordenes)
            o_rem = ordenes_lista[rand(1:length(ordenes_lista))]
            delete!(nuevas_ordenes, o_rem)
        end
    end
    
    # Si falla, retornar solución original
    return sol
end

# ========================================
# FUNCIONES AUXILIARES ESPECÍFICAS PARA GRANDES
# ========================================

"""
Análisis post-optimización específico para instancias grandes
"""
function analizar_solucion_grande(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int)
    stats = estadisticas_solucion(sol, roi, upi)
    
    # 🔥 DETECTAR SI ES GIGANTE PARA LIMITAR OUTPUT
    O, I = size(roi)
    es_gigante = (O > 2000 || I > 5000 || O * I > 10_000_000)
    
    if !es_gigante
        println("\n📋 ANÁLISIS DETALLADO - INSTANCIA GRANDE")
        println("-"^60)
        println("📦 Órdenes seleccionadas: $(stats.ordenes_count)")
        println("🚪 Pasillos utilizados: $(stats.pasillos_count)")
        println("📊 Unidades totales: $(stats.unidades_totales)")
        println("⚡ Eficiencia (unidades/pasillo): $(round(stats.eficiencia, digits=3))")
        println("🎯 Cobertura de ítems: $(round(stats.cobertura_promedio * 100, digits=1))%")
        
        # Análisis específico para instancias grandes
        if stats.pasillos_count > 0
            densidad_ordenes = stats.ordenes_count / size(roi, 1) * 100
            densidad_pasillos = stats.pasillos_count / size(upi, 1) * 100
            println("📈 Densidad de órdenes: $(round(densidad_ordenes, digits=1))%")
            println("📈 Densidad de pasillos: $(round(densidad_pasillos, digits=1))%")
            
            # Análisis de utilización de capacidad
            ratio_utilizacion = stats.unidades_totales / UB * 100
            println("💾 Utilización de capacidad total: $(round(ratio_utilizacion, digits=1))%")
            
            # Eficiencia por orden
            eficiencia_por_orden = stats.unidades_totales / stats.ordenes_count
            println("📦 Unidades promedio por orden: $(round(eficiencia_por_orden, digits=1))")
        end
    else
        println("\n✅ Análisis completado para instancia gigante")
    end
    
    return stats
end

"""
Optimización específica para instancias muy grandes
Incluye estrategias de manejo de memoria y tiempo
"""
function optimizacion_intensiva_grande(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int;
                                      max_tiempo_minutos::Int=30, intentos_multiples::Int=3)
    
    println("🏭 Iniciando optimización intensiva para instancia grande...")
    println("⏰ Tiempo máximo: $max_tiempo_minutos minutos")
    
    mejores_soluciones = Solucion[]
    tiempo_inicio = time()
    tiempo_limite = tiempo_inicio + (max_tiempo_minutos * 60)
    
    for intento in 1:intentos_multiples
        if time() >= tiempo_limite
            println("⏰ Tiempo límite alcanzado")
            break
        end
        
        tiempo_restante = tiempo_limite - time()
        iter_maximas = Int(ceil(tiempo_restante / intentos_multiples * 10))  # Estimación
        
        println("🔄 Intento $intento/$intentos_multiples (max_iter: $iter_maximas)")
        
        try
            sol_optimizada, _ = tabu_search_tolerante(roi, upi, LB, UB;
                                                    max_iter=iter_maximas,
                                                    max_no_improve=max(20, iter_maximas ÷ 10),
                                                    semilla=intento * 42)
            push!(mejores_soluciones, sol_optimizada)
            
            # Mostrar progreso
            obj = evaluar(sol_optimizada, roi)
            println("📊 Intento $intento completado: $(round(obj, digits=3))")
            
        catch e
            println("⚠️ Error en intento $intento: $e")
            continue
        end
    end
    
    tiempo_total = time() - tiempo_inicio
    println("⏰ Tiempo total utilizado: $(round(tiempo_total/60, digits=2)) minutos")
    
    if !isempty(mejores_soluciones)
        mejor_final = argmax(sol -> evaluar(sol, roi), mejores_soluciones)
        println("🏆 Mejor solución encontrada: $(round(evaluar(mejor_final, roi), digits=3))")
        return mejor_final
    else
        error("❌ No se pudo encontrar ninguna solución factible")
    end
end

"""
Función de diagnóstico para instancias problemáticas
"""
function diagnosticar_instancia_grande(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int)
    println("🔍 DIAGNÓSTICO DE INSTANCIA GRANDE")
    println("="^50)
    
    O, I = size(roi)
    P = size(upi, 1)
    
    # Estadísticas básicas
    println("📏 Dimensiones: $O órdenes × $I ítems × $P pasillos")
    println("📊 Tamaño efectivo: $(I * (O + P))")
    
    # Análisis de distribución
    demandas = [sum(roi[o, :]) for o in 1:O]
    capacidades = [sum(upi[p, :]) for p in 1:P]
    
    println("📈 Demanda total posible: $(sum(demandas))")
    println("📈 Capacidad total disponible: $(sum(capacidades))")
    println("📈 Límites: LB=$LB, UB=$UB")
    
    # Detectar posibles problemas
    if sum(demandas) < UB
        println("⚠️ ADVERTENCIA: Demanda total menor que UB")
    end
    
    if sum(capacidades) < UB
        println("❌ ERROR CRÍTICO: Capacidad insuficiente para UB")
    end
    
    # Densidad de matrices
    densidad_roi = count(x -> x > 0, roi) / (O * I) * 100
    densidad_upi = count(x -> x > 0, upi) / (P * I) * 100
    
    println("📊 Densidad ROI: $(round(densidad_roi, digits=1))%")
    println("📊 Densidad UPI: $(round(densidad_upi, digits=1))%")
    
    if densidad_roi < 10 || densidad_upi < 10
        println("⚠️ ADVERTENCIA: Matrices muy dispersas, considerar estrategias especializadas")
    end
    
    return (
        dimension_efectiva = I * (O + P),
        densidad_roi = densidad_roi,
        densidad_upi = densidad_upi,
        ratio_capacidad = sum(capacidades) / UB,
        factible_basico = sum(capacidades) >= UB && sum(demandas) >= LB
    )
end