function cargar_instancia(ruta::String)
    open(ruta, "r") do archivo
        # Leer y parsear primera línea
        linea = readline(archivo)
        O, I, P = parse.(Int, split(linea))

        # Leer roi: O x I
        roi = [parse.(Int, split(readline(archivo))) for _ in 1:O]
        roi = reduce(vcat, map(x -> reshape(x, 1, :), roi))  # Convertir a Matrix

        # Leer upi: P x I
        upi = [parse.(Int, split(readline(archivo))) for _ in 1:P]
        upi = reduce(vcat, map(x -> reshape(x, 1, :), upi))  # Convertir a Matrix

        # Leer límites
        lb_ub = parse.(Int, split(readline(archivo)))
        LB, UB = lb_ub[1], lb_ub[2]

        return roi, upi, LB, UB
    end
end
