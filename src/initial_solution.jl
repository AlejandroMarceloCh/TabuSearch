# initial_solution.jl
include("solution.jl")

include("pathological_fix.jl")
# ========================================
# FUNCIONES DE REPARACIÓN (OPTIMIZADAS PARA GIGANTES)
# ========================================

"""
Evalúa si una solución puede ser factible con tolerancia
"""
function es_factible_con_tolerancia(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, 
                                   LB::Int, UB::Int; tolerancia::Float64=0.1)
    if sol === nothing || isempty(sol.ordenes)
        return false
    end
    
    # Verificar límites de unidades
    unidades_totales = sum(sum(roi[o, :]) for o in sol.ordenes)
    if unidades_totales < LB || unidades_totales > UB
        return false
    end
    
    I = size(roi, 2)
    
    # Calcular demanda total por ítem
    demanda_por_item = zeros(Int, I)
    for o in sol.ordenes
        demanda_por_item .+= roi[o, :]
    end
    
    # Verificar cobertura con tolerancia
    for i in 1:I
        if demanda_por_item[i] > 0
            cobertura_total = sum(upi[p, i] for p in sol.pasillos; init=0)
            limite_tolerancia = Int(ceil(cobertura_total * (1.0 + tolerancia)))
            if demanda_por_item[i] > limite_tolerancia
                return false
            end
        end
    end
    
    return true
end

"""
Repara una solución eliminando órdenes conflictivas - OPTIMIZADA PARA GIGANTES
"""
function reparar_solucion(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, 
                         LB::Int, UB::Int; max_iteraciones::Int=50)
    if es_factible_rapido(sol, roi, upi, LB, UB)
        return sol
    end
    
    # 🔥 OPTIMIZACIÓN PARA GIGANTES: Detectar instancia gigante y reducir iteraciones
    O, I = size(roi)
    es_gigante = (O > 2000 || I > 5000 || O * I > 10_000_000)
    
    if es_gigante
        max_iteraciones = 5  # ⚡ DRÁSTICAMENTE reducido para gigantes
    elseif O > 500 || I > 1000
        max_iteraciones = 15  # Para instancias grandes normales
    end
    
    ordenes_reparadas = copy(sol.ordenes)
    
    for iter in 1:max_iteraciones
        if isempty(ordenes_reparadas)
            break
        end
        
        # 🔥 OPTIMIZACIÓN: Validación rápida antes de cálculos costosos
        demanda_total = sum(sum(roi[o, :]) for o in ordenes_reparadas)
        if demanda_total < LB || demanda_total > UB
            # Eliminar orden aleatoria si está fuera de límites
            if length(ordenes_reparadas) > 1
                orden_aleatoria = rand(collect(ordenes_reparadas))
                delete!(ordenes_reparadas, orden_aleatoria)
            else
                break
            end
            continue
        end
        
        # Solo hacer cálculo costoso si la validación básica pasa
        pasillos_actuales = calcular_pasillos_optimo(ordenes_reparadas, roi, upi)
        sol_candidata = Solucion(ordenes_reparadas, pasillos_actuales)
        
        if es_factible_rapido(sol_candidata, roi, upi, LB, UB)
            return sol_candidata
        end
        
        # 🔥 OPTIMIZACIÓN: Remoción más agresiva para gigantes
        if es_gigante && length(ordenes_reparadas) > 2
            # Remover 2-3 órdenes de una vez para gigantes
            n_remover = min(rand(2:3), length(ordenes_reparadas) - 1)
            ordenes_lista = collect(ordenes_reparadas)
            for _ in 1:n_remover
                if !isempty(ordenes_lista)
                    orden_remover = rand(ordenes_lista)
                    delete!(ordenes_reparadas, orden_remover)
                    filter!(x -> x != orden_remover, ordenes_lista)
                end
            end
        else
            # Remoción normal para instancias menores
            if length(ordenes_reparadas) > 1
                orden_aleatoria = rand(collect(ordenes_reparadas))
                delete!(ordenes_reparadas, orden_aleatoria)
            end
        end
    end
    
    return nothing
end

"""
Reparación simple y rápida para instancias gigantes
"""
function reparar_solucion_simple(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int)
    if es_factible_rapido(sol, roi, upi, LB, UB)
        return sol
    end
    
    ordenes_actuales = copy(sol.ordenes)
    
    # Solo 3 intentos máximo para reparación simple
    for _ in 1:3
        if isempty(ordenes_actuales)
            break
        end
        
        demanda_total = sum(sum(roi[o, :]) for o in ordenes_actuales)
        
        if demanda_total > UB
            # Remover orden aleatoria
            if length(ordenes_actuales) > 1
                orden_remover = rand(collect(ordenes_actuales))
                delete!(ordenes_actuales, orden_remover)
            else
                break
            end
        elseif demanda_total < LB
            # No podemos arreglar falta de demanda fácilmente, devolver null
            return nothing
        else
            # Está en rango, probar factibilidad
            nuevos_pasillos = calcular_pasillos_optimo(ordenes_actuales, roi, upi)
            candidato = Solucion(ordenes_actuales, nuevos_pasillos)
            if es_factible_rapido(candidato, roi, upi, LB, UB)
                return candidato
            else
                # Remover una orden y seguir
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

# ========================================
# FUNCIONES PRINCIPALES
# ========================================

"""
Generación estándar para instancias pequeñas/medianas
"""
function generar_solucion_inicial(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int; 
                                max_intentos::Int=50, verbose::Bool=false)
    O = size(roi, 1)
    mejor_solucion = nothing
    mejor_score = 0.0
    
    if verbose
        println("🎯 Generación estándar: objetivo conservador")
    end
    
    max_intentos = min(max_intentos, 100)  # Más intentos para casos difíciles
    for intento in 1:max_intentos
        ordenes_seleccionadas = Set{Int}()
        unidades_actuales = 0
        ordenes_disponibles = Set(1:O)
        
        # Greedy simple: seleccionar órdenes hasta llenar capacidad
        while unidades_actuales < UB && !isempty(ordenes_disponibles)
            orden_candidata = rand(collect(ordenes_disponibles))
            unidades_orden = sum(roi[orden_candidata, :])
            
            if unidades_actuales + unidades_orden <= UB
                push!(ordenes_seleccionadas, orden_candidata)
                unidades_actuales += unidades_orden
            end
            
            delete!(ordenes_disponibles, orden_candidata)
        end
        
        # Verificar si cumple límite inferior
        if unidades_actuales >= LB && !isempty(ordenes_seleccionadas)
            pasillos = calcular_pasillos_optimo(ordenes_seleccionadas, roi, upi)
            sol = Solucion(ordenes_seleccionadas, pasillos)
            
            if es_factible_rapido(sol, roi, upi, LB, UB)
                score = evaluar(sol, roi)
                
                if score > mejor_score
                    mejor_solucion = sol
                    mejor_score = score
                    
                    if verbose
                        println("✅ Nueva mejor: score=$(round(score, digits=2)), $unidades_actuales unidades")
                    end
                end
            end
        end
    end
    
    # Fallback de emergencia para instancias problemáticas
    if mejor_solucion === nothing && verbose
        println("🆘 Intentando generación de emergencia...")
        # Probar con target muy conservador
        for emergency_ratio in [0.3, 0.4, 0.5]
            target_emergency = Int(floor(UB * emergency_ratio))
            ordenes_emergency = Set{Int}()
            unidades_emergency = 0
            
            ordenes_aleatorias = randperm(O)[1:min(100, O)]
            for o in ordenes_aleatorias
                unidades_orden = sum(roi[o, :])
                if unidades_emergency + unidades_orden <= target_emergency
                    push!(ordenes_emergency, o)
                    unidades_emergency += unidades_orden
                    
                    if unidades_emergency >= LB
                        pasillos_emergency = Set([1, 2, 3, 4, 5])  # Pasillos fijos
                        sol_emergency = Solucion(ordenes_emergency, pasillos_emergency)
                        if es_factible_rapido(sol_emergency, roi, upi, LB, UB)
                            return sol_emergency
                        end
                    end
                end
            end
        end
    end
    return mejor_solucion
end

"""
Generación agresiva para instancias grandes/gigantes con tolerancia y reparación - OPTIMIZADA
"""
function generar_solucion_inicial_agresiva(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int; 
                                         target_ratio::Float64=0.50, tolerancia::Float64=0.20,
                                         max_intentos::Int=80, verbose::Bool=false)
    O, I = size(roi)
    target_unidades = Int(floor(UB * target_ratio))
    
    if verbose
        println("🎯 Generación agresiva: objetivo $target_unidades unidades ($(round(target_ratio*100, digits=1))% de UB)")
        println("🔧 Tolerancia: $(round(tolerancia*100, digits=1))% - Reparación automática")
    end
    
    mejor_solucion = nothing
    mejor_score = 0.0
    
    # 🔥 REDUCIR estrategias para ser más rápido
    estrategias = [:greedy_valor, :greedy_mixto]  # Solo las 2 más efectivas
    
    for estrategia in estrategias
        if verbose
            println("🔄 Probando estrategia: $estrategia")
        end
        
        # 🔥 INTENTOS REDUCIDOS por estrategia
        intentos_por_estrategia = max_intentos ÷ length(estrategias)
        
        for intento in 1:intentos_por_estrategia
            try
                sol = construir_con_tolerancia(roi, upi, LB, UB, target_unidades, estrategia, tolerancia)
                
                if sol !== nothing
                    if es_factible_rapido(sol, roi, upi, LB, UB)
                        score = evaluar(sol, roi)
                        if score > mejor_score
                            mejor_solucion = sol
                            mejor_score = score
                            if verbose
                                unidades = sum(sum(roi[o, :]) for o in sol.ordenes)
                                println("🏆 Nueva mejor: score=$(round(score, digits=2)), $unidades unidades")
                            end
                        end
                    else
                        # 🔥 REPARACIÓN MÁS SIMPLE
                        sol_reparada = reparar_solucion_simple(sol, roi, upi, LB, UB)
                        if sol_reparada !== nothing && es_factible_rapido(sol_reparada, roi, upi, LB, UB)
                            score = evaluar(sol_reparada, roi)
                            if score > mejor_score
                                mejor_solucion = sol_reparada
                                mejor_score = score
                                if verbose
                                    unidades = sum(sum(roi[o, :]) for o in sol_reparada.ordenes)
                                    println("🔧 REPARADA: score=$(round(score, digits=2)), $unidades unidades")
                                end
                            end
                        end
                    end
                end
            catch e
                continue
            end
        end
        
        if verbose
            println("✅ Estrategia $estrategia completada")
        end
    end
    
    return mejor_solucion
end

"""
Construye solución con tolerancia para una estrategia específica
"""
function construir_con_tolerancia(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, 
                                target_unidades::Int, estrategia::Symbol, tolerancia::Float64)
    O, I = size(roi)
    ordenes_candidatas = Set(1:O)
    ordenes_seleccionadas = Set{Int}()
    
    # Pre-calcular valores
    valor_por_orden = [sum(roi[o, :]) for o in 1:O]
    
    unidades_actuales = 0
    
    while unidades_actuales < target_unidades && !isempty(ordenes_candidatas)
        mejor_orden = 0
        mejor_score = -1.0
        
        for o in ordenes_candidatas
            unidades_orden = valor_por_orden[o]
            
            # No exceder UB con demasiada tolerancia
            if unidades_actuales + unidades_orden > UB * 1.05
                continue
            end
            
            # Calcular score según estrategia
            score = 0.0
            if estrategia == :greedy_valor
                score = Float64(unidades_orden)
            elseif estrategia == :greedy_eficiencia
                items_unicos = count(x -> x > 0, roi[o, :])
                score = items_unicos > 0 ? Float64(unidades_orden) / items_unicos : 0.0
            elseif estrategia == :greedy_ratio_valor
                items_totales = count(x -> x > 0, roi[o, :])
                score = items_totales > 0 ? Float64(unidades_orden) / items_totales : 0.0
            elseif estrategia == :greedy_mixto
                items_unicos = count(x -> x > 0, roi[o, :])
                ratio = items_unicos > 0 ? Float64(unidades_orden) / items_unicos : 0.0
                score = 0.7 * Float64(unidades_orden) + 0.3 * ratio
            end
            
            # Algo de aleatoriedad
            score *= (0.9 + 0.2 * rand())
            
            if score > mejor_score
                mejor_score = score
                mejor_orden = o
            end
        end
        
        if mejor_orden > 0
            push!(ordenes_seleccionadas, mejor_orden)
            delete!(ordenes_candidatas, mejor_orden)
            unidades_actuales += valor_por_orden[mejor_orden]
        else
            break
        end
    end
    
    if isempty(ordenes_seleccionadas)
        return nothing
    end
    
    pasillos = calcular_pasillos_optimo(ordenes_seleccionadas, roi, upi)
    return Solucion(ordenes_seleccionadas, pasillos)
end

# ========================================
# FUNCIONES ULTRA-OPTIMIZADAS PARA GIGANTES
# ========================================

"""
SOBRESCRIBIR: generar_solucion_gigante_ultra_rapida con límites adaptativos
"""
function generar_solucion_gigante_ultra_rapida(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int, verbose::Bool=false)
    O = size(roi, 1)
    
    if verbose
        println("⚡ Generación mejorada para gigante iniciada...")
    end
    
    for intento in 1:20  # Más intentos
        ordenes_seleccionadas = Set{Int}()
        unidades_actuales = 0
        valores_ordenes = [sum(roi[o, :]) for o in 1:O]
        
        # Estrategia: seleccionar órdenes por valor hasta llegar a UB
        ordenes_ordenadas = sortperm(valores_ordenes, rev=false)  # Empezar por las más pequeñas
        
        for o in ordenes_ordenadas
            unidades_orden = valores_ordenes[o]
            if unidades_actuales + unidades_orden <= UB
                push!(ordenes_seleccionadas, o)
                unidades_actuales += unidades_orden
                
                # Parar cuando tengamos suficiente
                if unidades_actuales >= LB && unidades_actuales >= UB * 0.5
                    break
                end
            end
            
            # Límite de órdenes para evitar complejidad
            if length(ordenes_seleccionadas) >= min(1000, O ÷ 2)
                break
            end
        end
        
        if unidades_actuales >= LB && !isempty(ordenes_seleccionadas)
            # Calcular pasillos usando algoritmo mejorado
            pasillos = calcular_pasillos_optimo(ordenes_seleccionadas, roi, upi)
            sol = Solucion(ordenes_seleccionadas, pasillos)
            
            # Verificación completa de factibilidad
            if es_factible_rapido(sol, roi, upi, LB, UB)
                if verbose
                    println("✅ Solución gigante factible: $(length(ordenes_seleccionadas)) órdenes, $unidades_actuales unidades")
                end
                return sol
            end
        end
        
        if verbose && intento % 5 == 0
            println("⚡ Intento $intento completado...")
        end
    end
    
    # Fallback: solución muy conservadora
    if verbose
        println("🆘 Creando solución conservadora...")
    end
    return crear_solucion_conservadora(roi, upi, LB, UB)
end

"""
Cálculo de pasillos ultra-rápido para gigantes
SOBRESCRIBIR: calcular_pasillos_rapido_gigante con límites adaptativos
"""
function calcular_pasillos_rapido_gigante(ordenes::Set{Int}, roi::Matrix{Int}, upi::Matrix{Int})
    if isempty(ordenes)
        return Set([1])
    end
    
    I = size(roi, 2)
    P = size(upi, 1)
    
    # Obtener límites adaptativos
    limites = get(INSTANCIA_STATE, "limites", nothing)
    if limites === nothing
        # Usar límites por defecto si no hay estado
        limites = (max_pasillos_normal = min(P ÷ 4, max(25, length(ordenes) ÷ 15)),
                  max_pasillos_masiva = min(P ÷ 3, max(50, length(ordenes) ÷ 20)))
    end
    
    pasillos_necesarios = Set{Int}()
    items_con_demanda = Set{Int}()
    for o in ordenes
        for i in 1:I
            if roi[o, i] > 0
                push!(items_con_demanda, i)
            end
        end
    end
    
    # LÍMITE ADAPTATIVO DE PASILLOS
    max_pasillos = if length(ordenes) > 1000
        limites.max_pasillos_masiva
    else
        limites.max_pasillos_normal
    end
    
    for p in 1:min(P, max_pasillos * 2)  # Permitir explorar más pasillos
        cubre_algun_item = false
        for i in items_con_demanda
            if upi[p, i] > 0
                cubre_algun_item = true
                break
            end
        end
        
        if cubre_algun_item
            push!(pasillos_necesarios, p)
        end
        
        if length(pasillos_necesarios) >= max_pasillos
            break
        end
    end
    
    return isempty(pasillos_necesarios) ? Set([1, 2, 3]) : pasillos_necesarios
end


"""
Validación ultra-básica para gigantes
"""
function validacion_basica_gigante(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int)
    if isempty(sol.ordenes) || isempty(sol.pasillos)
        return false
    end
    
    # 🔥 SOLO verificar límites de demanda total
    demanda_total = sum(sum(roi[o, :]) for o in sol.ordenes)
    return LB <= demanda_total <= UB
end

"""
Solución fallback ultra-simple para cuando todo falla
SOBRESCRIBIR: crear_solucion_fallback_gigante con más pasillos
"""
function crear_solucion_fallback_gigante(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int)
    O = size(roi, 1)
    
    # Obtener límites adaptativos
    limites = get(INSTANCIA_STATE, "limites", nothing)
    pasillos_fallback_count = if limites !== nothing
        limites.pasillos_fallback
    else
        3
    end
    
    ordenes_fallback = Set{Int}()
    unidades_actuales = 0
    valores_ordenes = [sum(roi[o, :]) for o in 1:O]
    ordenes_ordenadas = sortperm(valores_ordenes, rev=true)
    
    for o in ordenes_ordenadas
        unidades_orden = valores_ordenes[o]
        if unidades_actuales + unidades_orden <= UB
            push!(ordenes_fallback, o)
            unidades_actuales += unidades_orden
            if unidades_actuales >= LB
                break
            end
        end
    end
    
    if unidades_actuales >= LB
        # PASILLOS ADAPTATIVOS PARA FALLBACK
        pasillos_fallback = Set(1:min(pasillos_fallback_count * 3, size(upi, 1)))
        return Solucion(ordenes_fallback, pasillos_fallback)
    end
    
    # Último recurso: solución mínima
    return Solucion(Set([1]), Set([1]))
end


# ========================================
# FUNCIÓN PRINCIPAL PÚBLICA OPTIMIZADA
# ========================================

"""
Genera solución inicial adaptativa: estándar para pequeñas, agresiva para gigantes - ULTRA-OPTIMIZADA
"""


function generar_mejor_solucion_inicial_adaptativa(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int; 
    max_intentos::Int=50, verbose::Bool=false)
O, I, P = size(roi, 1), size(roi, 2), size(upi, 1)
es_gigante = (O > 2000 || I > 5000 || O * I > 10_000_000)

if verbose
println("🔎 Tipo de instancia detectado: $(es_gigante ? "gigante" : "normal")")
end

# 🔥 PARA GIGANTES: usar versión adaptativa SIEMPRE
if es_gigante
if verbose
println("🔥 MODO GIGANTE: Generación ultra-rápida adaptativa")
end
return generar_solucion_gigante_ultra_rapida(roi, upi, LB, UB, verbose)
end

# Para instancias normales: lógica original
if O > 500 || I > 1000 || O * I > 1_000_000  
sol = generar_solucion_inicial_agresiva(roi, upi, LB, UB, 
target_ratio=0.50,
tolerancia=0.20,
max_intentos=40,
verbose=verbose)
return sol !== nothing ? sol : generar_solucion_inicial(roi, upi, LB, UB, max_intentos=50, verbose=verbose)
else
return generar_solucion_inicial(roi, upi, LB, UB, max_intentos=max_intentos, verbose=verbose)
end
end



function crear_solucion_conservadora(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int)
    O = size(roi, 1)
    ordenes_fallback = Set{Int}()
    unidades_actuales = 0
    valores_ordenes = [sum(roi[o, :]) for o in 1:O]
    
    # Tomar las órdenes más pequeñas hasta LB
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
    
    if unidades_actuales >= LB
        pasillos_fallback = calcular_pasillos_optimo(ordenes_fallback, roi, upi)
        sol_candidata = Solucion(ordenes_fallback, pasillos_fallback)
        
        if es_factible_rapido(sol_candidata, roi, upi, LB, UB)
            return sol_candidata
        end
    end
    
    # Último recurso
    return Solucion(Set([1]), Set([1, 2, 3, 4, 5]))
end