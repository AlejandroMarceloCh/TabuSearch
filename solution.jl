#solution.jl:

struct Solucion
    ordenes::Set{Int}         # Ej: {1, 3, 5}
    pasillos::Set{Int}        # Ej: {2, 4}
end

"""
    es_factible(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int)

Verifica si la solución cubre todos los ítems requeridos por las órdenes y respeta los límites de unidades.
"""
function es_factible(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int)
    O, I = size(roi)
    P, _ = size(upi)

    demanda_total = zeros(Int, I)
    for o in sol.ordenes
        demanda_total .+= roi[o, :]
    end

    disponibilidad_total = zeros(Int, I)
    for p in sol.pasillos
        disponibilidad_total .+= upi[p, :]
    end

    for i in 1:I
        if demanda_total[i] > disponibilidad_total[i]
            return false
        end
    end

    total_unidades = sum(demanda_total)
    return LB <= total_unidades <= UB
end

"""
    calcular_objetivo(sol::Solucion, roi::Matrix{Int})

Devuelve la cantidad total de unidades atendidas dividida entre el número de pasillos.
"""
function calcular_objetivo(sol::Solucion, roi::Matrix{Int})
    demanda_total = zeros(Int, size(roi, 2))
    for o in sol.ordenes
        demanda_total .+= roi[o, :]
    end
    total_unidades = sum(demanda_total)
    num_pasillos = length(sol.pasillos)

    return num_pasillos > 0 ? total_unidades / num_pasillos : 0.0
end



function es_factible_rapido(sol::Solucion, roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int)
    I = size(roi, 2)
    
    # Pre-calcular demanda total (ya tenemos pasillos)
    demanda_total = zeros(Int, I)
    for o in sol.ordenes
        @views demanda_total .+= roi[o, :]
    end
    
    total_unidades = sum(demanda_total)
    
    # Verificar límites primero (más rápido)
    if !(LB <= total_unidades <= UB)
        return false
    end
    
    # Verificar cobertura solo si límites OK
    disponibilidad_total = zeros(Int, I)
    for p in sol.pasillos
        @views disponibilidad_total .+= upi[p, :]
    end
    
    # Verificación vectorizada
    return all(demanda_total .<= disponibilidad_total)
end