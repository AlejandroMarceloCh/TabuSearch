# ----------------------------------------
# Estructura de Solución y Funciones Base
# ----------------------------------------

mutable struct Solucion
    ordenes::Set{Int}
    pasillos::Set{Int}
end

# ✅ Función objetivo: maximiza unidades recolectadas por pasillo
function evaluar(sol::Solucion, roi)
    demanda_total = sum(sum(roi[o, :] for o in sol.ordenes))
    num_pasillos = length(sol.pasillos)
    return num_pasillos > 0 ? demanda_total / num_pasillos : 0.0
end

# Verifica factibilidad (lenta pero segura)
function es_factible(sol::Solucion, roi, upi, LB, UB)
    P = size(upi, 1)
    demanda = sum(roi[collect(sol.ordenes), :], dims=1)
    cobertura = sum(upi[collect(sol.pasillos), :], dims=1)

    if any(cobertura .< demanda)
        return false
    end

    total = sum(demanda)
    return LB ≤ total ≤ UB
end

# Verificación rápida
function es_factible_rapido(sol::Solucion, roi, upi, LB, UB)
    total = sum(sum(roi[o, :] for o in sol.ordenes))
    if total < LB || total > UB
        return false
    end

    cobertura = zeros(Int, size(roi, 2))
    for p in sol.pasillos
        cobertura .+= upi[p, :]
    end

    for o in sol.ordenes
        for i in 1:size(roi, 2)
            if roi[o, i] > 0 && cobertura[i] < roi[o, i]
                return false
            end
        end
    end

    return true
end

# ----------------------------------------
# Cálculo de pasillos para una solución
# ----------------------------------------

function calcular_pasillos(ordenes::Set{Int}, roi, upi)
    I = size(roi, 2)
    demanda_total = zeros(Int, I)
    for o in ordenes
        demanda_total .+= roi[o, :]
    end

    P = size(upi, 1)
    pasillos = Set{Int}()
    for i in 1:I
        if demanda_total[i] == 0
            continue
        end
        for p in 1:P
            if upi[p, i] > 0
                push!(pasillos, p)
                break  # Tomamos el primer pasillo que cubre el ítem
            end
        end
    end
    return pasillos
end

# ----------------------------------------
# Generación de solución inicial válida
# ----------------------------------------

function generar_solucion_inicial(roi, upi, LB, UB; modo::Symbol = :progresiva, max_intentos::Int = 100)
    O = size(roi, 1)
    intentos = 0

    while intentos < max_intentos
        intentos += 1
        ordenes = Set{Int}()
        unidades = zeros(Int, size(roi, 2))  # acumulador por ítem
        total_recolectado = 0

        ordenes_disponibles = randperm(O)
        for o in ordenes_disponibles
            # Simula agregar la orden
            unidades_tmp = unidades .+ roi[o, :]
            total_tmp = sum(unidades_tmp)

            # Solo agregamos si no nos pasamos del UB
            if total_tmp <= UB
                push!(ordenes, o)
                unidades = unidades_tmp
                total_recolectado = total_tmp
            end

            # Early stop si estamos dentro del rango factible
            if LB ≤ total_recolectado ≤ UB
                break
            end
        end

        if LB ≤ total_recolectado ≤ UB
            pasillos = calcular_pasillos(ordenes, roi, upi)
            return Solucion(ordenes, pasillos)
        end
    end

    error("❌ No se pudo generar una solución inicial factible tras $max_intentos intentos")
end


# ----------------------------------------
# Control Adaptativo para la Búsqueda Tabú
# ----------------------------------------

mutable struct ControlAdaptativo
    iteraciones_sin_mejora::Int
    mejoras_recientes::Vector{Float64}
    intensidad::Symbol  # :intensificar o :diversificar
    contador_diversificacion::Int

    ControlAdaptativo() = new(0, Float64[], :intensificar, 0)
end

function actualizar_control!(control::ControlAdaptativo, mejora::Float64)
    push!(control.mejoras_recientes, mejora)
    if length(control.mejoras_recientes) > 10
        popfirst!(control.mejoras_recientes)
    end

    if mejora > 0
        control.iteraciones_sin_mejora = 0
        control.intensidad = :intensificar
    else
        control.iteraciones_sin_mejora += 1

        # Verificar si hay estancamiento por falta de variabilidad
        varianza_baja = std(control.mejoras_recientes) < 0.05
        demasiadas_sin_mejora = control.iteraciones_sin_mejora > 7

        if demasiadas_sin_mejora || varianza_baja
            control.intensidad = :diversificar
        end
    end
end

