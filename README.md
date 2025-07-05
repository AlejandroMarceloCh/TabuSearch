# 🚀 Sistema Camaleónico de Optimización para Order Picking

Un sistema inteligente de optimización para el problema de **Order Picking en Almacenes** que se adapta automáticamente al tamaño y características de cada instancia.

## 📋 Descripción del Problema

El problema consiste en seleccionar un conjunto de órdenes de un almacén para **maximizar el ratio unidades/pasillos** sujeto a restricciones de capacidad:

- **Objetivo**: Maximizar `ratio = total_unidades / número_pasillos`
- **Restricciones**: `LB ≤ total_unidades ≤ UB`
- **Variables**: Qué órdenes seleccionar y qué pasillos usar

## 🏗️ Arquitectura del Sistema

### 🧠 **Sistema Camaleónico**
El sistema **se adapta automáticamente** según el tamaño de la instancia:

```
📊 Clasificación Automática
├── 🐣 PEQUEÑAS (< 500 órdenes)    → Solver exhaustivo
├── 🔧 MEDIANAS (500-2000 órdenes) → Solver heurístico balanceado  
├── 🚀 GRANDES (2000-5000 órdenes) → Solver escalable con VNS/LNS
└── ⚡ ENORMES (5000+ órdenes)     → Solver ultra-escalable
```

### 📁 **Estructura del Proyecto**

```
proyectoV2/
├── 📋 README.md                    # Este archivo
├── 🚀 main.jl                      # Punto de entrada principal│
├── 🧠 core/                        # Núcleo del sistema
│   ├── config_instancia.jl        # Configuración de instancias
│   ├── base.jl                     # Estructuras y funciones base
│   └── classifier.jl               # Clasificador automático
│
├── 🔧 solvers/                     # Solvers especializados
│   ├── pequenas/                   # Solver para instancias pequeñas
│   │   ├── pequenas.jl
│   │   ├── pequenas_constructivas.jl
│   │   └── pequenas_vecindarios.jl
│   ├── medianas/                   # Solver para instancias medianas
│   │   ├── medianas.jl
│   │   ├── medianas_constructivas.jl
│   │   └── medianas_vecindarios.jl
│   ├── grandes/                    # Solver para instancias grandes
│   │   ├── grandes.jl
│   │   ├── grandes_constructivas.jl
│   │   └── grandes_vecindarios.jl
│   └── enormes/                    # Solver para instancias enormes
│       ├── enormes.jl
│       ├── enormes_constructivas.jl
│       └── enormes_vecindarios.jl
│
├── 🛠️ utils/                       # Utilidades
│   └──data_loader.jl              # Cargador de instancias
│
└── 📊 data/                        # Instancias del problema
    ├── instancia01.txt - instancia20.txt
    └── INSTRUCCIONES_LECTURA_INSTANCIAS.txt
```

## ⚡ **Uso Rápido**

### 🚀 **Ejecución Simple**
```bash
julia main.jl
```

### 🎯 **Resolver Instancia Específica**
```julia
include("main.jl")

# Cargar y resolver automáticamente
roi, upi, LB, UB = cargar_instancia("data/instancia05.txt")
resultado = resolver_instancia(roi, upi, LB, UB; mostrar_detalles=true)

println("Ratio obtenido: $(resultado.valor)")
println("Tiempo: $(resultado.tiempo)s")
println("Factible: $(resultado.factible)")
```

### 🌙 **Experimentos Nocturnos (Solo Enormes)**
```bash
julia experimentos_enormes_nocturno.jl
```

## 🧬 **Algoritmos por Categoría**

### 🐣 **Solver PEQUEÑAS** 
- **Estrategia**: Búsqueda exhaustiva controlada
- **Algoritmos**: Tabu Search, enumeración inteligente
- **Fortaleza**: Garantiza óptimo local excelente
- **Uso**: Instancias < 500 órdenes

### 🔧 **Solver MEDIANAS**
- **Estrategia**: Heurísticas balanceadas
- **Algoritmos**: VNS moderado, constructivas múltiples
- **Fortaleza**: Balance calidad/tiempo
- **Uso**: Instancias 500-2000 órdenes

### 🚀 **Solver GRANDES** 
- **Estrategia**: Metaheurísticas escalables
- **Algoritmos**: VNS avanzado, LNS, constructivas inteligentes
- **Fortaleza**: Escalabilidad con buena calidad
- **Uso**: Instancias 2000-5000 órdenes

### ⚡ **Solver ENORMES**
- **Estrategia**: Ultra-escalabilidad con sampling inteligente
- **Algoritmos**: 
  - **Constructiva Ratio Alto**: Busca configuraciones de 80-150+ ratio inicial
  - **VNS Ultra-Escalable**: Sampling adaptativo, restarts frecuentes
  - **LNS Masivo**: Destroy/repair con sampling
  - **Post-optimización**: Intercambios críticos
- **Fortaleza**: Maneja 10,000+ órdenes, ratios 16-691
- **Uso**: Instancias 5000+ órdenes

## 🏆 **Rendimiento del Sistema**

### 📊 **Resultados Típicos por Categoría**

| Categoría | Tamaño | Tiempo Típico | Ratio Típico | Solver Usado |
|-----------|--------|---------------|--------------|--------------|
| 🐣 Pequeñas | < 500 | 1-30s | 15-50 | Exhaustivo |
| 🔧 Medianas | 500-2K | 30s-5min | 25-80 | Heurístico |
| 🚀 Grandes | 2K-5K | 5-15min | 40-120 | VNS/LNS |
| ⚡ Enormes | 5K+ | 15-45min | 80-200+ | Ultra-escalable |


## 🔧 **Características Técnicas**

### 🧠 **Clasificador Automático**
- Analiza dimensiones de la instancia
- Detecta instancias patológicas
- Asigna solver óptimo automáticamente
- Configura parámetros adaptativos

### 🚀 **Constructiva Ratio Alto (Enormes)**
- Busca sistemáticamente configuraciones 1-8 pasillos
- Identifica órdenes TOP 10% por valor
- Maximiza ratio desde construcción inicial
- Alcanza ratios 80-200+ iniciales

### ⚡ **VNS Ultra-Escalable**
- Sampling inteligente (500-1000 órdenes/operación)
- Restarts frecuentes para escape de óptimos locales
- Diversificación extrema cada 500 iteraciones
- Modo "Ratio Hunter" para saltos dramáticos

### 🛡️ **Sistema de Fallback**
- Recuperación automática de errores
- Logs detallados de ejecución
- Checkpoints de progreso
- Continuación robusta ante fallos

## 📊 **Formato de Datos**

### 📥 **Archivo de Instancia**
```
O I P          # Órdenes, Ítems, Pasillos
roi[1][1] roi[1][2] ... roi[1][I]    # Matriz ROI (O filas)
...
roi[O][1] roi[O][2] ... roi[O][I]
upi[1][1] upi[1][2] ... upi[1][I]    # Matriz UPI (P filas)  
...
upi[P][1] upi[P][2] ... upi[P][I]
LB UB          # Lower y Upper Bound
```

### 📤 **Estructura de Solución**
```julia
struct Solucion
    ordenes::Set{Int}     # Órdenes seleccionadas
    pasillos::Set{Int}    # Pasillos utilizados
end

# Evaluación: ratio = sum(unidades) / length(pasillos)
```

## 🚀 **Ejecución y Experimentos**

### 🎯 **Modo Básico**
```bash
# Ejecutar con instancia por defecto
julia main.jl

# Ver progreso detallado
julia main.jl  # con mostrar_detalles=true
```



### ⚙️ **Personalización**
```julia
# Cambiar instancia en main.jl
archivo = "data/instancia07.txt"

# Múltiples corridas
resultado = correr_muchas_veces("instancia05", roi, upi, LB, UB; veces=5)

# Solver específico (saltando clasificación)
resultado = resolver_enorme(roi, upi, LB, UB; mostrar_detalles=true)
```

## 📈 **Métricas de Rendimiento**

### 🏆 **Métricas Principales**
- **Ratio**: `unidades_totales / numero_pasillos`
- **Utilización UB**: `(unidades/UB) * 100%`
- **Eficiencia**: `unidades/pasillo`
- **Factibilidad**: `LB ≤ unidades ≤ UB`

### ⚡ **Métricas de Escalabilidad**
- **Tiempo/orden**: Segundos por orden procesada
- **Órdenes/segundo**: Throughput del algoritmo
- **Complejidad manejada**: O×I×P elementos totales

## 🛠️ **Requisitos Técnicos**

### 📋 **Dependencias**
```julia
# Paquetes requeridos
using Random, Statistics, Printf, Dates
using StatsBase  # Para sampling
using Combinatorics  # Para pequeñas (enumeración)

# Paquetes opcionales (para experimentos)
using Plots  # Solo para experimentos nocturnos
```

### 💻 **Compatibilidad**
- **Julia**: 1.6+
- **RAM**: 4GB+ (recomendado 8GB+ para enormes)
- **CPU**: Cualquier arquitectura moderna
- **SO**: Windows, macOS, Linux



## 🏆 **Resumen Ejecutivo**

Este sistema proporciona una **solución completa y automática** para el problema de Order Picking que:

✅ **Se adapta automáticamente** al tamaño de cada instancia  
✅ **Garantiza alta calidad** con algoritmos especializados  
✅ **Escala eficientemente** hasta 10,000+ órdenes  
✅ **Es robusto y confiable** con sistema de fallback  
✅ **Genera resultados superiores** a objetivos establecidos  

El sistema ha demostrado **superar objetivos** en instancias enormes (ej: 205.0 vs objetivo 117.88 en instancia05) y está optimizado para uso tanto **interactivo** como **automatizado** mediante experimentos nocturnos.

---

*Sistema desarrollado para optimización de warehouse order picking con enfoque en escalabilidad y adaptabilidad automática.*
