# utils/data_loader.jl
# ========================================
# CARGADOR BÁSICO DE INSTANCIAS
# ========================================

"""
Carga una instancia desde ruta y retorna roi, upi, LB, UB
"""
function cargar_instancia(path::String)
    open(path, "r") do f
        O, I, P = parse.(Int, split(strip(readline(f))))
        roi = [parse.(Int, split(strip(readline(f)))) for _ in 1:O]
        roi = reduce(vcat, map(row -> reshape(row, 1, :), roi))
        upi = [parse.(Int, split(strip(readline(f)))) for _ in 1:P]
        upi = reduce(vcat, map(row -> reshape(row, 1, :), upi))
        LB, UB = parse.(Int, split(strip(readline(f))))
        return roi, upi, LB, UB
    end
end