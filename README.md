# Parcial 2: Programación III (Elixir), grupo G2D

Solución de la combinación **1 y 3** del Parcial 2 (docente Julián Esteban Gutiérrez Posada, Universidad del Quindío):

- **Problema 1:** robot de rescate con energía limitada y mapa SVG.
- **Problema 3:** búsqueda de motivos de ADN con hasta un error.

Otros documentos:

- [PRUEBAS.md](PRUEBAS.md): entradas y salidas de cada caso, para el informe.
- [SUSTENTACION.md](SUSTENTACION.md): explicación de las funciones no triviales, para repartir en los videos.

## Requisitos

- Elixir 1.20.3 con Erlang/OTP 29 (versión con la que se probó).
- No usa `mix` ni librerías externas.

## Estructura

```
parcial dos/
├── README.md, PRUEBAS.md, SUSTENTACION.md
├── util2.ex                 módulo Util2 del curso
├── archivo.ex               lectura y escritura compartidas
├── problema1_robot/
│   ├── terreno.ex, recorrido.ex
│   ├── robot.exs
│   ├── datos/<caso>/        edificio.txt, terrenos.csv, bateria.txt
│   └── salidas/<caso>/      se generan al ejecutar
└── problema3_adn/
    ├── muestra.ex, coincidencia.ex
    ├── adn.exs
    ├── datos/<caso>/        muestras.txt, motivos.txt
    └── salidas/<caso>/      se generan al ejecutar
```

## Cómo compilar y ejecutar

Todos los comandos se ejecutan desde la raíz del proyecto, la carpeta `parcial dos`.

Compilar (se repite cada vez que cambie un `.ex`):

```bash
elixirc util2.ex archivo.ex problema1_robot/terreno.ex problema1_robot/recorrido.ex problema3_adn/muestra.ex problema3_adn/coincidencia.ex
```

La primera compilación no muestra warnings. Si se compila de nuevo con los `.beam` ya creados, Elixir avisa `redefining module`. Ese aviso es inofensivo y desaparece si antes se borran los `.beam`.

Ejecutar cada problema. El programa pide el nombre del caso:

```bash
elixir problema1_robot/robot.exs
```

```bash
elixir problema3_adn/adn.exs
```

Ejecutar un caso sin escribirlo a mano:

```bash
echo valido | elixir problema1_robot/robot.exs
```

```bash
echo valido | elixir problema3_adn/adn.exs
```

### Casos del problema 1

| Caso | Qué prueba |
|---|---|
| `valido` | Ejemplo del enunciado, B = 10: 6 recorridos |
| `valido_comentarios` | El mismo ejemplo con comentarios, líneas vacías y fin de línea de Windows |
| `invalido` | Fila corta, símbolo `Z`, dos `S`, huecos en el borde, terreno repetido, registros mal formados, `abc` y dos líneas en la batería |
| `invalido_vacio` | Edificio sin filas |
| `invalido_b_cero` | B = 0 y meta no transitable |
| `limite_b5` | B = 5: exactamente 1 recorrido |
| `limite_sin_ruta` | B = 4: la meta no es alcanzable |
| `limite_empates` | Dos recorridos empatados en movimientos y energía |
| `limite_criterios` | El recorrido de menos movimientos no es el de menor energía |
| `limite_xml` | Símbolo y nombre de terreno con `&`, `<`, `>`, comillas y apóstrofo |
| `faltante` | Falta `bateria.txt` |

### Casos del problema 3

| Caso | Qué prueba |
|---|---|
| `valido` | Ejemplo del enunciado: 14 coincidencias |
| `valido_comentarios` | El mismo ejemplo con comentarios, líneas vacías, minúsculas y fin de línea de Windows |
| `invalido` | Secuencia antes del encabezado, `>` vacío, id repetido, muestra sin bases, `N` en secuencia, `X` en motivo |
| `limite_palindromo` | Motivo `ACGT` en muestra `ACGT`: una coincidencia `+` y otra `-` en 0–3 |
| `limite_motivo_largo` | Motivo más largo que las muestras y muestra de una sola base |
| `faltante` | Falta `motivos.txt` |

## Problema 1: pensamiento computacional

### Abstracción

- **¿Qué se solicita?** Todos los recorridos simples de `S` a `M` que no superan la batería `B`, cuál tiene menos movimientos, cuál consume menos energía, y un mapa SVG con la ruta de menor energía.
- **¿Qué información es relevante?** La matriz del edificio, el costo y la transitabilidad de cada terreno, y `B`. Se modela con `%Terreno{}`, `%Recorrido{}`, un mapa `%{{fila, columna} => simbolo}` y un mapa `%{simbolo => %Terreno{}}`.

### Descomposición

Es el contenido de `main`:

1. Ingresar el caso y preparar las rutas.
2. Verificar que existan los 3 archivos.
3. Leer terrenos, edificio y batería con streams.
4. Validar recursivamente y escribir `validacion_edificio.txt`. Si hay errores, avisar y terminar.
5. Generar la relajación con un Stream infinito y escribir `expansion_energia.txt`.
6. Enumerar recursivamente los recorridos, si la meta es alcanzable.
7. Escribir `recorridos_rescate.csv`.
8. Generar y guardar el resumen.
9. Dibujar `ruta_optima.svg`.
10. Mostrar el resultado en pantalla.

### Reconocimiento de patrones

- `Util2.ingresar` y `Util2.mostrar` para la entrada y la salida (diapositivas 2-06 y 2-07).
- El módulo de estructura con `crear` (`Cliente`, diapositiva 2-06a).
- Mapa de coordenadas con `Enum.with_index` y `Enum.flat_map` (ejemplo del laberinto).
- `Stream.iterate` con `Stream.take_while` (primos, Guía 10).
- `File.stream!` y tuplas `{:ok, ...}` / `{:error, ...}` con una cláusula por forma (Guía 11).
- Recursión con caso base y acumulador (Fibonacci, listado de asistencia).

### Codificación

Está en [problema1_robot/robot.exs](problema1_robot/robot.exs), con [terreno.ex](problema1_robot/terreno.ex) y [recorrido.ex](problema1_robot/recorrido.ex). El script está dividido en secciones marcadas con comentarios, en el mismo orden de la descomposición.

## Problema 3: pensamiento computacional

### Abstracción

- **¿Qué se solicita?** Todas las ventanas donde un motivo coincide con 0 o 1 sustituciones, en orientación `+` y `-`, en un CSV ordenado, y un resumen por motivo y muestra.
- **¿Qué información es relevante?** El id y la secuencia de cada muestra, la lista de motivos sin repetir y la línea física de cada dato para reportar errores. Se modela con `%Muestra{}` y `%Coincidencia{}`.

### Descomposición

Es el contenido de `main`:

1. Ingresar el caso y preparar las rutas.
2. Verificar que existan los archivos.
3. Leer muestras y motivos con streams.
4. Validar recursivamente y escribir `validacion_adn.txt`. Si hay errores, avisar y terminar.
5. Agrupar las muestras y quitar los motivos duplicados.
6. Buscar las coincidencias en las dos orientaciones.
7. Ordenarlas y escribir `coincidencias_adn.csv`.
8. Generar y guardar el resumen.
9. Mostrar el resultado en pantalla.

### Reconocimiento de patrones

- `Util2`, el módulo `Archivo` y las tuplas de resultado son los mismos del problema 1.
- `Enum.frequencies_by` para contar por grupo (Guía 11).
- `String.graphemes` y el recorrido `[cabeza | cola]` para trabajar base por base.
- Funciones con una cláusula por valor (`complemento`, `base_valida?`), como `determinar_par?` (diapositiva 2-07c).

### Codificación

Está en [problema3_adn/adn.exs](problema3_adn/adn.exs), con [muestra.ex](problema3_adn/muestra.ex) y [coincidencia.ex](problema3_adn/coincidencia.ex).

## Decisiones de interpretación

### Problema 1

- **Índice de estabilización:** es el paso del último estado distinto. En `valido` hay 6 pasos distintos, del 0 al 5, y el índice es 5, porque el paso 6 repetiría el 5.
- **Formato de posiciones:** `(1,1)->(1,2)`, sin espacios, en el CSV y el resumen. En los mensajes de validación las coordenadas se escriben `{fila, columna}`.
- **Coordenadas y líneas:** las coordenadas cuentan solo las filas útiles, desde 0. Las líneas son físicas, desde 1, y sí cuentan comentarios y líneas vacías.
- **Validación adicional:** además de lo pedido, se exige que los terrenos `S` y `M` sean transitables, porque si no la búsqueda no tendría sentido.
- **Relajación a través de `M`:** la relajación calcula costos para toda casilla transitable y también pasa por `M`. La búsqueda sí se detiene al llegar a `M`.
- **Empate en el SVG:** se dibuja el primero encontrado, porque `Enum.min_by` retorna el primer mínimo.
- **Ancho del SVG:** las casillas miden 40 × 40 px, y el dibujo se ensancha si un nombre largo de terreno lo necesita, para que la leyenda no se corte.

### Problema 3

- **Orientación `-`:** se busca la reversa complementaria del motivo sobre la secuencia directa. Las posiciones `-` quedan en las mismas coordenadas que las `+`. El CSV muestra siempre el motivo original.
- **Palíndromos:** un motivo como `ACGT` produce una coincidencia `+` y otra `-` en la misma posición, y se cuentan por separado.
- **Mayúsculas:** las secuencias y los motivos se pasan a mayúsculas al normalizar, y después se valida que solo tengan `A`, `C`, `G` y `T`.
- **Orden de las muestras:** el CSV y el resumen van ordenados por id de muestra, no por orden de aparición en el archivo.
- **Duplicados:** se reportan ya en mayúsculas, con su línea física: `acg` aparece como `ACG (línea 4)`.
- **Posición de un carácter inválido:** cuenta desde 0 dentro de la línea física, no dentro de la secuencia completa.

### Generales

- Cada `main` crea `salidas/<caso>/` solo después de confirmar que existen las entradas. Por eso `faltante` no genera carpeta de salida.
- Cuando hay errores de validación solo se genera el archivo de validación. Si un caso ya tenía salidas de una ejecución anterior, esos archivos no se borran.
- Los avisos de errores y de archivos faltantes salen por la salida de error, con `Util2.mostrar(mensaje, :error)`.

## Elementos que conviene conocer antes de sustentar

Todo el código usa lo visto en clase. Estos detalles no aparecen tal cual en las diapositivas, y vale la pena saber explicarlos:

- **`or` en guardas y en `if`:** operador lógico, de la misma familia que el `and` de la Guía 10.
- **Un nombre repetido en un patrón:** en `defp visitada?(posicion, [posicion | _cola])`, la cláusula solo aplica si los dos valores son iguales.
- **`[a, b | cola]`:** toma los dos primeros elementos de una lista y deja el resto en `cola`.
- **`[_cabeza | cola] = bases`:** separa la lista y además conserva la lista completa en `bases`.
- **`Enum.at(lista, -1)`:** retorna el último elemento de la lista.
