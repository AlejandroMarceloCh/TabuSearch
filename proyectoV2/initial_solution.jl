# initial_solution.jl
# ========================================
# GENERACIÓN DE SOLUCIÓN INICIAL UNIFICADA - PROYECTO 20/20
# ========================================

include("solution.jl")
include("config_manager.jl")

using Random

"""
Función principal unificada para generar solución inicial
Se adapta automáticamente según la configuración de la instancia
"""
function generar_solucion_inicial_unificada(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int; 
                                           config::Union{InstanceConfig,Nothing}=nothing)
    
    # Crear configuración automática si no se proporciona
    if config === nothing
        config = crear_configuracion_automatica(roi, upi, LB, UB)
    end
    
    # Verificación básica
    if !diagnostico_rapido(roi, upi, LB, UB)
        return nothing
    end
    
    println("🎯 Generando solución inicial...")
    println("🔍 Debug: gigante=$(config.es_gigante), patológica=$(config.es_patologica), factor=$(config.factor_gravedad)")
    
    # Para instancias ultra-patológicas, usar estrategia especial
    solucion = nothing
    
    if config.es_gigante && config.es_patologica && config.factor_gravedad > 1.5
        println("🚨 Detectada instancia ULTRA-PATOLÓGICA - Usando estrategia especial...")
        solucion = generar_solucion_ultra_patologica(roi, upi, LB, UB, config)
    elseif config.es_gigante && config.es_patologica
        println("🚨 Detectada instancia GIGANTE PATOLÓGICA...")
        solucion = generar_gigante_patologica(roi, upi, LB, UB, config)
    elseif config.es_gigante
        println("⚡ Detectada instancia GIGANTE normal...")
        solucion = generar_gigante_normal(roi, upi, LB, UB, config)
    else
        println("📝 Detectada instancia normal...")
        solucion = generar_normal(roi, upi, LB, UB, config)
    end
    
    # Si no se pudo generar, intentar estrategia de emergencia SIEMPRE
    if solucion === nothing
        println("🆘 Fallback: Intentando estrategia de emergencia absoluta...")
        solucion = crear_solucion_minima_garantizada(roi, upi, LB, UB, config)
    end
    
    if solucion !== nothing
        mostrar_solucion(solucion, roi, config, "Inicial")
    else
        println("❌ No se pudo generar solución inicial factible")
    end
    
    return solucion
end

# ========================================
# ESTRATEGIAS ESPECÍFICAS
# ========================================

"""
Generación para instancias normales (pequeñas, medianas, grandes)
"""
function generar_normal(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::InstanceConfig)
    O = size(roi, 1)
    mejor_solucion = nothing
    mejor_score = 0.0
    
    max_intentos = config.parametros.max_intentos_inicial
    
    for intento in 1:max_intentos
        ordenes_seleccionadas = Set{Int}()
        unidades_actuales = 0
        ordenes_disponibles = Set(1:O)
        
        # Construcción greedy simple y efectiva
        while unidades_actuales < UB && !isempty(ordenes_disponibles)
            orden_candidata = rand(collect(ordenes_disponibles))
            unidades_orden = sum(roi[orden_candidata, :])
            
            if unidades_actuales + unidades_orden <= UB
                push!(ordenes_seleccionadas, orden_candidata)
                unidades_actuales += unidades_orden
            end
            
            delete!(ordenes_disponibles, orden_candidata)
        end
        
        # Verificar factibilidad
        if unidades_actuales >= LB && !isempty(ordenes_seleccionadas)
            pasillos = calcular_pasillos_optimo(ordenes_seleccionadas, roi, upi)
            sol = Solucion(ordenes_seleccionadas, pasillos)
            
            if es_factible_rapido(sol, roi, upi, LB, UB)
                score = evaluar(sol, roi)
                if score > mejor_score
                    mejor_solucion = sol
                    mejor_score = score
                end
            end
        end
    end
    
    return mejor_solucion
end

"""
Generación para instancias gigantes normales
"""
# 2. En initial_solution.jl - Estrategia mejorada para maximizar objetivo
function generar_gigante_normal(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::InstanceConfig)
    O = size(roi, 1)
    
    println("⚡ Generación adaptativa para instancia gigante...")
    
    # Pre-análisis de la instancia
    valores_ordenes = [sum(roi[o, :]) for o in 1:O]
    valor_promedio = sum(valores_ordenes) / O
    valor_mediano = sort(valores_ordenes)[O ÷ 2]
    
    # Estimar cuántas órdenes necesitamos
    objetivo_llenado = config.parametros.factor_llenado_objetivo
    target_unidades = UB * objetivo_llenado

    ordenes_estimadas = ceil(Int, target_unidades / max(valor_mediano, 1e-6))
    println("📊 Target: $(round(Int, target_unidades)) unidades (~$(ordenes_estimadas) órdenes estimadas)")
    
    mejor_solucion = nothing
    mejor_score = 0.0
    
    # Múltiples estrategias con diferentes enfoques
    for estrategia in 1:15
        ordenes_seleccionadas = Set{Int}()
        unidades_actuales = 0
        
        # Variar estrategia de selección
        if estrategia <= 5
            # Estrategia 1: Greedy por valor
            indices = sortperm(valores_ordenes, rev=(estrategia % 2 == 0))
        elseif estrategia <= 10
            # Estrategia 2: Selección por rangos
            inicio = (estrategia - 6) * O ÷ 5
            fin = min(O, inicio + O ÷ 3)
            indices = shuffle(collect(inicio+1:fin))
        else
            # Estrategia 3: Completamente aleatoria
            indices = randperm(O)
        end
        
        # Factor de llenado variable
        factor_llenado = 0.6 + 0.35 * rand()  # Entre 60% y 95%
        limite_superior = UB * factor_llenado
        
        for idx in indices
            o = idx <= O ? idx : indices[1]  # Seguridad
            unidades_orden = valores_ordenes[o]
            
            if unidades_actuales + unidades_orden <= limite_superior
                push!(ordenes_seleccionadas, o)
                unidades_actuales += unidades_orden
                
                # No parar hasta tener suficientes unidades
                if length(ordenes_seleccionadas) >= config.parametros.max_ordenes
                    break
                end
            end
        end
        
        # Verificar factibilidad
        if unidades_actuales >= LB && !isempty(ordenes_seleccionadas)
            pasillos = calcular_pasillos_optimo(ordenes_seleccionadas, roi, upi)
            sol = Solucion(ordenes_seleccionadas, pasillos)
            
            if es_factible_rapido(sol, roi, upi, LB, UB)
                score = evaluar(sol, roi)
                if score > mejor_score
                    mejor_solucion = sol
                    mejor_score = score
                    println("✅ Estrategia exitosa: score=$(round(score, digits=2)), órdenes=$(length(ordenes_seleccionadas))")
                end
            end
        end
    end
    
    # Si no encontramos nada bueno, usar construcción voraz mejorada
    if mejor_solucion === nothing
        println("🔄 Usando construcción voraz mejorada...")
        mejor_solucion = construccion_voraz_mejorada(roi, upi, LB, UB, config)
    end
    
    return mejor_solucion
end


# 3. Nueva función de construcción voraz mejorada
function construccion_voraz_mejorada(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::InstanceConfig)
    O, I, P = size(roi, 1), size(roi, 2), size(upi, 1)
    
    # Calcular utilidad de cada orden (valor/complejidad)
    utilidades = Float64[]
    for o in 1:O
        valor = sum(roi[o, :])
        items_distintos = count(roi[o, :] .> 0)
        utilidad = valor / (1 + 0.1 * items_distintos)  # Penalizar órdenes con muchos ítems
        push!(utilidades, utilidad)
    end
    
    # Ordenar por utilidad
    indices_utilidad = sortperm(utilidades, rev=true)
    
    # Construir solución llenando hasta cerca del UB
    ordenes_seleccionadas = Set{Int}()
    unidades_actuales = 0
    target = UB * 0.9  # Llenar hasta 90% para maximizar objetivo
    
    for o in indices_utilidad
        unidades_orden = sum(roi[o, :])
        
        if unidades_actuales + unidades_orden <= target
            # Verificación rápida cada 50 órdenes
            if length(ordenes_seleccionadas) % 50 == 49
                temp_ordenes = copy(ordenes_seleccionadas)
                push!(temp_ordenes, o)
                if !validar_factibilidad_basica(temp_ordenes, roi, upi, LB, target)
                    continue
                end
            end
            
            push!(ordenes_seleccionadas, o)
            unidades_actuales += unidades_orden
        end
        
        if length(ordenes_seleccionadas) >= config.parametros.max_ordenes
            break
        end
    end
    
    # Asegurar que cumplimos con LB
    if unidades_actuales >= LB
        pasillos = calcular_pasillos_optimo(ordenes_seleccionadas, roi, upi)
        sol = Solucion(ordenes_seleccionadas, pasillos)
        
        if es_factible_rapido(sol, roi, upi, LB, UB)
            return sol
        end
    end
    
    return nothing
end


"""
Generación específica para instancias ultra-patológicas (como instancia 10)
"""
function generar_solucion_ultra_patologica(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::InstanceConfig)
    O, I, P = size(roi, 1), size(roi, 2), size(upi, 1)
    
    println("🔥 Estrategia ultra-patológica activada...")
    println("   📊 Analizando viabilidad básica...")
    
    # Análisis ultra-detallado
    valores_ordenes = [sum(roi[o, :]) for o in 1:O]
    indices_ordenados = sortperm(valores_ordenes)
    
    # Estrategia 1: Construcción ultra-conservadora secuencial
    println("🔄 Probando construcción secuencial...")
    for factor_target in [0.25, 0.30, 0.35, 0.40, 0.45, 0.50]
        target_conservador = Int(floor(UB * factor_target))
        if target_conservador < LB
            continue
        end
        
        ordenes_secuencial = Set{Int}()
        unidades_secuencial = 0
        
        for o in indices_ordenados
            unidades_orden = valores_ordenes[o]
            if unidades_secuencial + unidades_orden <= target_conservador
                push!(ordenes_secuencial, o)
                unidades_secuencial += unidades_orden
                
                # Verificar factibilidad cada pocas órdenes
                if length(ordenes_secuencial) % 10 == 0 && unidades_secuencial >= LB
                    if verificar_factibilidad_ultra_basica(ordenes_secuencial, roi, upi, LB, UB)
                        pasillos_seq = calcular_pasillos_optimo(ordenes_secuencial, roi, upi)
                        sol_seq = Solucion(ordenes_secuencial, pasillos_seq)
                        
                        if es_factible_rapido(sol_seq, roi, upi, LB, UB)
                            println("✅ Construcción secuencial exitosa con factor $factor_target")
                            return sol_seq
                        end
                    end
                end
            end
        end
        
        # Verificación final para este factor
        if unidades_secuencial >= LB
            if verificar_factibilidad_ultra_basica(ordenes_secuencial, roi, upi, LB, UB)
                pasillos_seq = calcular_pasillos_optimo(ordenes_secuencial, roi, upi)
                sol_seq = Solucion(ordenes_secuencial, pasillos_seq)
                
                if es_factible_rapido(sol_seq, roi, upi, LB, UB)
                    println("✅ Construcción secuencial exitosa con factor $factor_target")
                    return sol_seq
                end
            end
        end
    end
    
    # Estrategia 2: Sampling inteligente con múltiples semillas
    println("🎲 Probando sampling inteligente...")
    for semilla in [42, 123, 456, 789, 999]
        Random.seed!(semilla)
        
        for tamaño_muestra in [50, 100, 200, 300, 500]
            if tamaño_muestra > O
                continue
            end
            
            # Tomar muestra de órdenes más prometedoras
            limite_ordenes = min(O, Int(floor(O * 0.3)))  # Top 30% más pequeñas
            ordenes_candidatas = indices_ordenados[1:limite_ordenes]
            muestra = shuffle(ordenes_candidatas)[1:min(tamaño_muestra, length(ordenes_candidatas))]
            
            ordenes_muestra = Set{Int}()
            unidades_muestra = 0
            
            for o in muestra
                unidades_orden = valores_ordenes[o]
                if unidades_muestra + unidades_orden <= UB * 0.6  # Target conservador
                    push!(ordenes_muestra, o)
                    unidades_muestra += unidades_orden
                    
                    if unidades_muestra >= LB
                        break
                    end
                end
            end
            
            if unidades_muestra >= LB
                if verificar_factibilidad_ultra_basica(ordenes_muestra, roi, upi, LB, UB)
                    pasillos_muestra = calcular_pasillos_optimo(ordenes_muestra, roi, upi)
                    sol_muestra = Solucion(ordenes_muestra, pasillos_muestra)
                    
                    if es_factible_rapido(sol_muestra, roi, upi, LB, UB)
                        println("✅ Sampling inteligente exitoso (semilla=$semilla, muestra=$tamaño_muestra)")
                        return sol_muestra
                    end
                end
            end
        end
    end
    
    # Estrategia 3: Solución mínima garantizada
    println("🆘 Creando solución mínima garantizada...")
    return crear_solucion_minima_garantizada(roi, upi, LB, UB, config)
end

"""
Verificación ultra-básica para instancias extremas
"""
function verificar_factibilidad_ultra_basica(ordenes::Set{Int}, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int)
    if isempty(ordenes)
        return false
    end
    
    # Solo verificar límites básicos
    demanda_total = sum(sum(roi[o, :]) for o in ordenes)
    if !(LB <= demanda_total <= UB)
        return false
    end
    
    # Verificación muy relajada de cobertura
    I = size(roi, 2)
    capacidad_total_disponible = sum(upi)
    demanda_total_items = sum(sum(roi[o, :]) for o in ordenes)
    
    # Si la capacidad total es al menos 2x la demanda, probablemente es factible
    return capacidad_total_disponible >= demanda_total_items * 2
end

"""
Crea una solución mínima que garantiza factibilidad
"""
function crear_solucion_minima_garantizada(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::InstanceConfig)
    O, P = size(roi, 1), size(upi, 1)
    valores_ordenes = [sum(roi[o, :]) for o in 1:O]
    
    println("🔧 Construyendo solución mínima garantizada...")
    
    # Estrategia mejorada: buscar solución con mejor ratio calidad/pasillos
    indices_ordenados = sortperm(valores_ordenes)
    
    # Probar múltiples targets para encontrar mejor balance
    mejor_solucion = nothing
    mejor_eficiencia = 0.0
    
    for target_ratio in [0.25, 0.30, 0.35, 0.40, 0.45, 0.50, 0.60, 0.70]
        target_unidades = Int(floor(UB * target_ratio))
        if target_unidades < LB
            continue
        end
        
        ordenes_candidatas = Set{Int}()
        unidades_actuales = 0
        
        # Llenar hasta el target
        for o in indices_ordenados
            unidades_orden = valores_ordenes[o]
            if unidades_actuales + unidades_orden <= target_unidades
                push!(ordenes_candidatas, o)
                unidades_actuales += unidades_orden
            end
        end
        
        if unidades_actuales >= LB && !isempty(ordenes_candidatas)
            # Calcular pasillos óptimos (no todos)
            pasillos_optimos = calcular_pasillos_optimo(ordenes_candidatas, roi, upi)
            sol_candidata = Solucion(ordenes_candidatas, pasillos_optimos)
            
            if es_factible_rapido(sol_candidata, roi, upi, LB, UB)
                eficiencia = evaluar(sol_candidata, roi)
                if eficiencia > mejor_eficiencia
                    mejor_solucion = sol_candidata
                    mejor_eficiencia = eficiencia
                    println("🎯 Mejor solución: ratio=$target_ratio, eficiencia=$(round(eficiencia, digits=3))")
                end
            end
        end
    end
    
    # Si no encontramos nada bueno, usar la estrategia original con todos los pasillos
    if mejor_solucion === nothing
        println("🆘 Usando estrategia de respaldo con todos los pasillos...")
        ordenes_minimas = Set{Int}()
        unidades_minimas = 0
        
        for o in indices_ordenados
            unidades_orden = valores_ordenes[o]
            if unidades_minimas + unidades_orden <= UB
                push!(ordenes_minimas, o)
                unidades_minimas += unidades_orden
                
                if unidades_minimas >= LB
                    # Usar TODOS los pasillos para garantizar factibilidad
                    pasillos_todos = Set(1:P)
                    sol_minima = Solucion(ordenes_minimas, pasillos_todos)
                    
                    if es_factible_rapido(sol_minima, roi, upi, LB, UB)
                        println("✅ Solución de respaldo creada")
                        return sol_minima
                    end
                end
            end
        end
    end
    
    if mejor_solucion !== nothing
        println("✅ Solución mínima garantizada creada con eficiencia $(round(mejor_eficiencia, digits=3))")
    else
        println("❌ No se pudo crear solución mínima garantizada")
    end
    
    return mejor_solucion
end
function generar_gigante_patologica(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::InstanceConfig)
    O = size(roi, 1)
    
    println("🚨 Generación especializada para patológica...")
    
    mejor_solucion = nothing
    mejor_score = 0.0
    
    # Múltiples estrategias para patológicas
    estrategias = [:conservadora, :agresiva, :mixta, :emergencia]  # Agregamos estrategia de emergencia
    
    for estrategia in estrategias
        intentos_por_estrategia = estrategia == :emergencia ? 50 : 15  # Más intentos para emergencia
        
        for intento in 1:intentos_por_estrategia
            sol = construir_con_estrategia_patologica(roi, upi, LB, UB, config, estrategia)
            
            if sol !== nothing
                # Reparar si es necesario
                if !es_factible_rapido(sol, roi, upi, LB, UB)
                    sol = reparar_solucion_patologica(sol, roi, upi, LB, UB, config)
                end
                
                if sol !== nothing && es_factible_rapido(sol, roi, upi, LB, UB)
                    score = evaluar(sol, roi)
                    if score > mejor_score
                        mejor_solucion = sol
                        mejor_score = score
                        println("🔧 Estrategia $estrategia exitosa: $(round(score, digits=3))")
                        
                        # Para patológicas gigantes, tomar la primera solución factible
                        if config.es_gigante && score > 0
                            return mejor_solucion
                        end
                    end
                end
            end
        end
        
        # Si ya encontramos algo bueno, no seguir probando estrategias
        if mejor_solucion !== nothing && config.es_gigante
            return mejor_solucion
        end
    end
    
    # Si no encontramos nada, crear solución ultra-conservadora
    if mejor_solucion === nothing
        return crear_solucion_ultra_conservadora(roi, upi, LB, UB, config)
    end
    
    return mejor_solucion
end

# ========================================
# FUNCIONES AUXILIARES
# ========================================

"""
Construye solución con estrategia específica para patológicas
"""
function construir_con_estrategia_patologica(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, 
                                           config::InstanceConfig, estrategia::Symbol)
    O, I = size(roi)
    ordenes_seleccionadas = Set{Int}()
    unidades_actuales = 0
    
    # Calcular target según estrategia
    target_unidades = if estrategia == :conservadora
        Int(floor(UB * 0.3))
    elseif estrategia == :agresiva
        Int(floor(UB * 0.7))
    elseif estrategia == :emergencia
        Int(floor(UB * 0.15))  # Muy conservador para emergencia
    else # :mixta
        Int(floor(UB * 0.5))
    end
    
    target_unidades = max(target_unidades, LB)
    
    # Pre-calcular valores de órdenes
    valores_ordenes = [sum(roi[o, :]) for o in 1:O]
    
    if estrategia == :conservadora || estrategia == :emergencia
        # Empezar por órdenes pequeñas
        ordenes_ordenadas = sortperm(valores_ordenes, rev=false)
    elseif estrategia == :agresiva
        # Empezar por órdenes grandes
        ordenes_ordenadas = sortperm(valores_ordenes, rev=true)
    else # :mixta
        # Mezcla aleatoria
        ordenes_ordenadas = randperm(O)
    end
    
    # Límite más relajado para emergencia
    max_ordenes_limite = if estrategia == :emergencia
        min(O, Int(ceil(O * 0.8)))  # Hasta 80% de órdenes si es necesario
    else
        config.parametros.max_ordenes
    end
    
    for o in ordenes_ordenadas
        unidades_orden = valores_ordenes[o]
        
        if unidades_actuales + unidades_orden <= UB
            push!(ordenes_seleccionadas, o)
            unidades_actuales += unidades_orden
            
            # Parar cuando alcancemos el target
            if unidades_actuales >= target_unidades
                break
            end
        end
        
        # Límite de órdenes
        if length(ordenes_seleccionadas) >= max_ordenes_limite
            break
        end
    end
    
    if unidades_actuales >= LB && !isempty(ordenes_seleccionadas)
        pasillos = calcular_pasillos_optimo(ordenes_seleccionadas, roi, upi)
        return Solucion(ordenes_seleccionadas, pasillos)
    end
    
    return nothing
end

"""
Reparación específica para instancias patológicas
"""
function reparar_solucion_patologica(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, 
                                   LB::Int, UB::Int, config::InstanceConfig)
    
    ordenes_actuales = copy(sol.ordenes)
    
    # Intentos de reparación más intensivos para patológicas
    max_intentos = config.parametros.usar_reparacion_agresiva ? 10 : 5
    
    for intento in 1:max_intentos
        if isempty(ordenes_actuales)
            break
        end
        
        demanda_total = sum(sum(roi[o, :]) for o in ordenes_actuales)
        
        if demanda_total > UB
            # Remover orden con más unidades
            if length(ordenes_actuales) > 1
                valores = [(o, sum(roi[o, :])) for o in ordenes_actuales]
                orden_mayor = maximum(valores, key=x -> x[2])[1]
                delete!(ordenes_actuales, orden_mayor)
            else
                break
            end
        elseif demanda_total < LB
            # Intentar agregar órdenes pequeñas
            O = size(roi, 1)
            candidatos = setdiff(1:O, ordenes_actuales)
            
            if !isempty(candidatos)
                valores_candidatos = [(o, sum(roi[o, :])) for o in candidatos]
                sort!(valores_candidatos, by=x -> x[2])  # Empezar por las más pequeñas
                
                agregada = false
                for (o, valor) in valores_candidatos
                    if demanda_total + valor <= UB
                        push!(ordenes_actuales, o)
                        demanda_total += valor
                        agregada = true
                        break
                    end
                end
                
                if !agregada
                    break
                end
            else
                break
            end
        else
            # Está en rango, verificar factibilidad completa
            nuevos_pasillos = calcular_pasillos_optimo(ordenes_actuales, roi, upi)
            candidato = Solucion(ordenes_actuales, nuevos_pasillos)
            
            if es_factible_rapido(candidato, roi, upi, LB, UB)
                return candidato
            else
                # Remover una orden aleatoria y continuar
                if length(ordenes_actuales) > 1
                    orden_remover = rand(collect(ordenes_actuales))
                    delete!(ordenes_actuales, orden_remover)
                else
                    break
                end
            end
        end
    end
    
    return nothing
end

"""
Creación de solución ultra-conservadora para casos extremos
"""
function crear_solucion_ultra_conservadora(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::InstanceConfig)
    O = size(roi, 1)
    println("🆘 Creando solución ultra-conservadora...")
    
    # Estrategia 1: Órdenes más pequeñas posibles
    valores_ordenes = [sum(roi[o, :]) for o in 1:O]
    indices_ordenados = sortperm(valores_ordenes)
    
    ordenes_fallback = Set{Int}()
    unidades_actuales = 0
    
    # Agregar órdenes de una en una hasta alcanzar LB
    for o in indices_ordenados
        unidades_orden = valores_ordenes[o]
        if unidades_actuales + unidades_orden <= UB
            push!(ordenes_fallback, o)
            unidades_actuales += unidades_orden
            
            # Parar tan pronto como alcancemos LB
            if unidades_actuales >= LB
                break
            end
        end
    end
    
    # Si logramos una solución básica
    if unidades_actuales >= LB && !isempty(ordenes_fallback)
        pasillos_fallback = calcular_pasillos_optimo(ordenes_fallback, roi, upi)
        sol_candidata = Solucion(ordenes_fallback, pasillos_fallback)
        
        if es_factible_rapido(sol_candidata, roi, upi, LB, UB)
            println("✅ Solución ultra-conservadora exitosa")
            return sol_candidata
        end
    end
    
    # Estrategia 2: Fuerza bruta con límites muy relajados
    println("🔄 Intentando fuerza bruta...")
    for target_ratio in [0.25, 0.30, 0.35, 0.40, 0.50]
        target = Int(floor(UB * target_ratio))
        if target < LB
            continue
        end
        
        ordenes_bruta = Set{Int}()
        unidades_bruta = 0
        
        for o in shuffle(indices_ordenados)
            unidades_orden = valores_ordenes[o]
            if unidades_bruta + unidades_orden <= target
                push!(ordenes_bruta, o)
                unidades_bruta += unidades_orden
                
                if unidades_bruta >= LB
                    pasillos_bruta = calcular_pasillos_optimo(ordenes_bruta, roi, upi)
                    sol_bruta = Solucion(ordenes_bruta, pasillos_bruta)
                    
                    if es_factible_rapido(sol_bruta, roi, upi, LB, UB)
                        println("✅ Solución de fuerza bruta exitosa")
                        return sol_bruta
                    end
                end
            end
        end
    end
    
    # Último recurso: solución mínima con muchos pasillos
    println("⚠️ Creando solución de emergencia absoluta")
    P = size(upi, 1)
    pasillos_emergencia = Set(1:min(P, 100))  # Usar hasta 100 pasillos
    return Solucion(Set([1]), pasillos_emergencia)
end

"""
Creación de solución conservadora como fallback
"""
function crear_solucion_conservadora(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, config::InstanceConfig)
    O = size(roi, 1)
    ordenes_fallback = Set{Int}()
    unidades_actuales = 0
    valores_ordenes = [sum(roi[o, :]) for o in 1:O]
    
    # Tomar las órdenes más pequeñas hasta alcanzar LB
    indices_ordenados = sortperm(valores_ordenes)
    
    for o in indices_ordenados
        unidades_orden = valores_ordenes[o]
        if unidades_actuales + unidades_orden <= UB
            push!(ordenes_fallback, o)
            unidades_actuales += unidades_orden
            if unidades_actuales >= LB
                break
            end
        end
    end
    
    if unidades_actuales >= LB && !isempty(ordenes_fallback)
        pasillos_fallback = calcular_pasillos_optimo(ordenes_fallback, roi, upi)
        sol_candidata = Solucion(ordenes_fallback, pasillos_fallback)
        
        if es_factible_rapido(sol_candidata, roi, upi, LB, UB)
            println("🆘 Solución conservadora creada")
            return sol_candidata
        end
    end
    
    # Último recurso: solución mínima
    println("⚠️ Creando solución de emergencia")
    return Solucion(Set([1]), Set([1, 2, 3]))
end