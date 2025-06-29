# Optimización Tabu Search - Proyecto Refactorizado

Este proyecto implementa un algoritmo de Tabu Search modular y adaptativo para problemas de optimización combinatoria, con soporte especializado para instancias de diferentes tamaños.

## 📁 Estructura del Proyecto

```
proyecto/
├── src/
│   ├── main.jl                    # Punto de entrada principal
│   ├── solution.jl                # Funciones comunes compartidas
│   ├── data_loader.jl             # Cargador y validador de datos
│   ├── neighborhood/
│   │   ├── neighborhood_peque.jl  # Vecindarios para instancias pequeñas/medianas
│   │   └── neighborhood_grande.jl # Vecindarios para instancias grandes/enormes
│   └── tabu_search/
│       ├── tabu_search_mini.jl    # Tabu Search para instancias pequeñas/medianas
│       └── tabu_search_grande.jl  # Tabu Search para instancias grandes/enormes
├── datos/                         # Archivos de datos de entrada
├── resultados/                    # Resultados de optimización
├── .gitignore
└── README.md
```

## 🚀 Características Principales

### Detección Automática de Instancias
- **Pequeñas**: ≤ 5,000 variables efectivas
- **Medianas**: ≤ 50,000 variables efectivas  
- **Grandes**: ≤ 200,000 variables efectivas
- **Gigantes**: > 200,000 variables efectivas

### Algoritmos Especializados
- **Instancias Pequeñas/Medianas**: Tabu Search clásico optimizado
- **Instancias Grandes/Enormes**: Tabu Search tolerante con reparación automática

### Estrategias Adaptativas
- Control adaptativo de intensificación/diversificación
- Gestión inteligente de listas tabú
- Vecindarios con probabilidades dinámicas
- Mecanismos de escape automático

## 📊 Uso Básico

### Ejecución Simple

```bash
julia src/main.jl datos/mi_instancia.txt
```

### Ejecución con Parámetros

```bash
julia src/main.jl datos/mi_instancia.txt 200 30 123
#                 archivo              iter mejora semilla
```

### Uso Programático

```julia
include("src/main.jl")

# Ejecutar optimización
resultado = ejecutar_optimizacion("datos/instancia.txt";
                                 max_iter=150,
                                 max_no_improve=25,
                                 semilla=123,
                                 devolver_evolucion=true)

# Acceder a resultados
mejor_sol, mejor_obj, evolucion, _, mejoras = resultado
```

## 📝 Formato de Datos

Los archivos de datos deben seguir este formato:

```
# Línea 1: O I P (órdenes, ítems, pasillos)
10 5 3

# Línea 2: LB UB (límites inferior y superior)
20 50

# Líneas 3 a O+2: Matriz ROI (demanda de órdenes por ítem)
2 0 1 0 3
0 2 0 1 1
1 1 0 0 2
...

# Líneas O+3 a O+P+2: Matriz UPI (capacidad de pasillos por ítem)
5 3 0 2 4
0 4 3 1 2
2 0 2 3 1
```

### Generar Datos de Ejemplo

```julia
include("src/data_loader.jl")
archivo = generar_datos_ejemplo(20, 8, 5, "datos/ejemplo.txt")
```

## 🔧 Configuración Avanzada

### Parámetros por Tipo de Instancia

| Tipo | Max Iter | Max No Improve | Max Vecinos | Estrategias |
|------|----------|----------------|-------------|-------------|
| Pequeña | 150 | 20 | 40 | Clásicas optimizadas |
| Mediana | 175 | 25 | 45 | Intercambio múltiple |
| Grande | 200 | 30 | 40 | Tolerancia + reparación |
| Gigante | 250 | 40 | 35 | Reinicio parcial |

### Personalización

```julia
# Modificar parámetros específicos
resultado = ejecutar_optimizacion("datos/instancia.txt";
                                 max_iter=300,        # Más iteraciones
                                 max_no_improve=50,   # Más paciencia
                                 semilla=42)          # Reproducibilidad
```

## 📊 Interpretación de Resultados

### Salida Estándar
```
🎯 RESULTADOS FINALES
🏆 Mejor valor objetivo: 15.750
📦 Órdenes seleccionadas: 8 → [1, 3, 5, 7, 9, 12, 15, 18]
🚪 Pasillos utilizados: 4 → [1, 2, 4, 6]
✅ Solución FACTIBLE verificada
```

### Análisis de Convergencia
```
📈 ANÁLISIS DE CONVERGENCIA
📊 Total de iteraciones: 127
🔄 Mejoras encontradas: 8
🎯 Evolución de mejores soluciones:
   1. Iter 0: 12.450
   2. Iter 15: 13.200
   3. Iter 42: 14.100
   4. Iter 78: 15.750
```

## 🛠️ Funcionalidades Avanzadas

### Verificación de Datos
```julia
include("src/data_loader.jl")
verificar_archivo("datos/mi_instancia.txt")
```

### Exportación de Resultados
```julia
include("src/data_loader.jl")
exportar_solucion(mejor_solucion, "resultados/solucion.txt", roi, mejor_objetivo)
```

### Análisis Detallado
```julia
include("src/tabu_search/tabu_search_mini.jl")
stats = analizar_solucion_mini(solucion, roi, upi, LB, UB)
```

## 🔍 Debugging y Monitoreo

### Logs Detallados
- `🔎` Detección de tipo de instancia
- `✅` Nuevas mejores soluciones
- `⚠️` Iteraciones sin vecinos factibles
- `🔄` Aplicación de estrategias de escape
- `📈` Progreso cada 25 iteraciones

### Estadísticas de Vecindarios (Instancias Grandes)
```
📊 Estadísticas de vecindarios:
   intercambio: 0.234 (éxito: 23.4%)
   crecimiento: 0.187 (éxito: 18.7%)
   reduccion: 0.156 (éxito: 15.6%)
   mutacion_multiple: 0.298 (éxito: 29.8%)
   reconstruccion_parcial: 0.125 (éxito: 12.5%)
```

## ⚡ Optimización de Rendimiento

### Recomendaciones por Tamaño

**Instancias Pequeñas (< 100 variables)**:
- Usar `optimizacion_rapida_mini()` para búsqueda exhaustiva parcial
- Aumentar `max_vecinos` para mayor exploración

**Instancias Medianas (100-1000 variables)**:
- Configuración estándar es óptima
- Considerar múltiples ejecuciones con diferentes semillas

**Instancias Grandes (> 1000 variables)**:
- Aumentar `max_iter` y `max_no_improve`
- El algoritmo tolerante maneja automáticamente la factibilidad

## 🐛 Solución de Problemas

### Error: "No se pudo generar solución inicial factible"
- Verificar que LB ≤ UB
- Asegurar que existe capacidad suficiente en UPI
- Verificar formato de archivo de datos

### Advertencia: "Solución final NO FACTIBLE"
- Normal en instancias grandes, se aplica reparación automática
- Verificar límites LB/UB realistas para la instancia

### Performance Lenta
- Reducir `max_vecinos` para instancias muy grandes
- Verificar que el tipo de instancia se detecta correctamente
- Considerar usar semilla fija para debugging

## 📈 Extensiones Futuras

- [ ] Soporte para restricciones adicionales
- [ ] Paralelización para instancias gigantes
- [ ] Interfaz gráfica para visualización
- [ ] Exportación a formatos CSV/JSON
- [ ] Benchmarking automático

## 📄 Licencia

Este proyecto está disponible bajo los términos que determines para tu uso académico o comercial.

---

**Desarrollado con Julia** 🚀