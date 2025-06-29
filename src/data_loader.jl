# data_loader.jl
# ========================================
# CARGADOR DE DATOS SIMPLE Y EFICIENTE
# ========================================

using Random, Statistics

# ========================================
# FUNCIÓN PRINCIPAL DE CARGA (TU VERSIÓN ORIGINAL)
# ========================================

function cargar_instancia(ruta::String)
    open(ruta, "r") do archivo
        # Leer y parsear primera línea
        linea = readline(archivo)
        O, I, P = parse.(Int, split(linea))
        
        # Leer roi: O x I
        roi = [parse.(Int, split(readline(archivo))) for _ in 1:O]
        roi = reduce(vcat, map(x -> reshape(x, 1, :), roi)) # Convertir a Matrix
        
        # Leer upi: P x I
        upi = [parse.(Int, split(readline(archivo))) for _ in 1:P]
        upi = reduce(vcat, map(x -> reshape(x, 1, :), upi)) # Convertir a Matrix
        
        # Leer límites
        lb_ub = parse.(Int, split(readline(archivo)))
        LB, UB = lb_ub[1], lb_ub[2]
        
        return roi, upi, LB, UB
    end
end

# ========================================
# ALIAS PARA COMPATIBILIDAD CON SISTEMA REFACTORIZADO
# ========================================

"""
Alias para mantener compatibilidad con el sistema refactorizado
"""
function cargar_datos(ruta::String)
    return cargar_instancia(ruta)
end

# ========================================
# FUNCIONES AUXILIARES MÍNIMAS
# ========================================

"""
Resumen básico de los datos cargados
"""
function resumen_datos(roi::Matrix{Int}, upi::Matrix{Int}, LB::Int, UB::Int)
    O, I = size(roi)
    P = size(upi, 1)
    
    println("📊 Datos cargados:")
    println("   - Órdenes: $O, Ítems: $I, Pasillos: $P")
    println("   - Límites: LB=$LB, UB=$UB")
    println("   - Demanda total: $(sum(roi))")
    println("   - Capacidad total: $(sum(upi))")
end

"""
Verificación rápida de archivo
"""
function verificar_archivo(archivo::String)
    if !isfile(archivo)
        println("❌ Archivo no existe: $archivo")
        return false
    end
    
    try
        roi, upi, LB, UB = cargar_instancia(archivo)
        resumen_datos(roi, upi, LB, UB)
        println("✅ Archivo válido")
        return true
    catch e
        println("❌ Error: $e")
        return false
    end
end

