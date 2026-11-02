# Sustentación: funciones no triviales

Las funciones están agrupadas en 5 bloques para que cada integrante explique funciones distintas. Un bloque se puede partir si el grupo lo necesita.

| Bloque | Tema | Archivo |
|---|---|---|
| 1 | Robot: lectura perezosa y validación recursiva | `archivo.ex`, `robot.exs` |
| 2 | Robot: relajación con Stream infinito | `robot.exs` |
| 3 | Robot: búsqueda recursiva y escritura del SVG | `robot.exs` |
| 4 | ADN: lectura, validación y agrupación | `adn.exs` |
| 5 | ADN: reversa complementaria y búsqueda de motivos | `adn.exs` |

---

## Bloque 1: robot, lectura perezosa y validación recursiva

### `Archivo.leer_lineas_utiles/1`

- **Qué hace:** retorna un Stream de tuplas `{texto_limpio, numero_linea}`, sin líneas vacías ni comentarios.
- **Por qué es perezosa:** no lee nada al llamarla. El archivo se lee línea por línea cuando alguien consume el Stream con `Enum.to_list`.
- **Punto clave:** `Stream.with_index(1)` va **antes** de `Stream.reject`. Así el número es la línea física, aunque después se ignoren otras líneas.

Ejemplo con este archivo:

```
# comentario
10
```

1. `Stream.with_index(1)` produce `{"# comentario\n", 1}` y `{"10\n", 2}`.
2. `Stream.map` limpia: `{"# comentario", 1}` y `{"10", 2}`.
3. `Stream.reject` quita el comentario. Queda `{"10", 2}`, con la línea 2 correcta.

### `recorrer_terrenos/3` y `buscar_linea/2`

- **Qué hacen:** revisan cada registro de `terrenos.csv` y detectan símbolos repetidos.
- **Por qué son recursivas:** la regla 7 prohíbe `Enum` y `Stream` en las validaciones.
- **Caso base:** lista vacía. `recorrer_terrenos` retorna los errores y `buscar_linea` retorna `nil`.
- **Caso recursivo:** procesa la cabeza y se llama con la cola. `recorrer_terrenos` además guarda `{simbolo, linea}` en `vistos`.

Ejemplo con los registros `L` en la línea 3 y `L` en la línea 4:

1. Línea 3: `buscar_linea("L", [])` retorna `nil`, no hay error. `vistos` pasa a ser `[{"L", 3}]`.
2. Línea 4: `buscar_linea("L", [{"L", 3}])` retorna `3`.
3. Se agrega el error: `el símbolo L ya estaba definido en la línea 3`.

La cláusula `buscar_linea(simbolo, [{simbolo, linea} | _cola])` repite el nombre `simbolo`: solo aplica cuando los dos valores son iguales.

### `revisar_anchos/3`

- **Qué hace:** compara el tamaño de cada fila con el de la primera.
- **Caso base:** no quedan filas.
- **Caso recursivo:** si la guarda `length(simbolos) == esperado` se cumple, sigue sin cambios. Si no, agrega el error y sigue.

Ejemplo con filas de 6, 4 y 6 símbolos, y `esperado = 6`:

1. La fila de 4 no cumple la guarda: se reporta `la fila tiene 4 símbolos y se esperaban 6`.
2. La siguiente fila de 6 la cumple y no agrega nada.
3. La lista queda vacía y se retornan los errores.

### `buscar_coordenadas/4` y `buscar_en_fila/5`

- **Qué hacen:** retornan las coordenadas donde aparece un símbolo. Sirven para exigir exactamente una `S` y una `M`, y después para saber dónde están.
- **Por qué son dos funciones:** una recorre las filas y la otra las casillas de una fila, igual que dos ciclos anidados.
- **Caso base:** no quedan filas o no quedan casillas.
- **Caso recursivo:** avanza a la siguiente fila o a la siguiente columna, sumando 1 al contador.

Ejemplo buscando `"S"` en la fila 1, `["X", "S", "."]`:

1. Columna 0: `"X"` no coincide, sigue.
2. Columna 1: `"S"` coincide, guarda `{1, 1}`.
3. Columna 2: `"."` no coincide, sigue.
4. Lista vacía: retorna `[{1, 1}]`.

### `recorrer_celdas_borde/4` y `en_borde?/2`

- **Qué hacen:** reportan cada casilla del borde que no sea `X`.
- **Caso base:** no quedan casillas.
- **Caso recursivo:** una `X` siempre está bien y sigue. Otro símbolo solo es error si `en_borde?` retorna `true`.

Ejemplo con un edificio de 5 filas y 6 columnas: la casilla `{4, 2}` con `.` está en la última fila, así que se reporta `el borde debe ser X y hay .`. La casilla `{2, 3}` con `.` no está en el borde y no se reporta.

---

## Bloque 2: robot, relajación con Stream infinito

### `calcular_pasos/1`

- **Qué hace:** genera los estados de costo mínimo hasta que dejan de cambiar.
- **Por qué es perezosa:** `Stream.iterate` describe una secuencia infinita, pero cada estado se calcula solo cuando `Stream.take_while` lo pide.
- **Cómo se detiene:** cada elemento es `{paso, anterior, actual}`. `take_while` se detiene en el primero donde `anterior == actual`, y ese elemento no entra en la lista.

### `relajar/2` y `mejor_costo/6`

- **Qué hacen:** `relajar` calcula el estado siguiente a partir del anterior. `mejor_costo` halla el menor costo de una casilla revisando sus 4 vecinos.
- **Caso base de `mejor_costo`:** no quedan direcciones, retorna el mejor costo.
- **Caso recursivo:** calcula `costo_vecino + costo_de_entrada`, descarta lo que supere `B`, se queda con el menor y sigue con la siguiente dirección.

Ejemplo con `valido`, B = 10. Cada paso muestra solo las casillas nuevas:

| Paso | Casillas nuevas |
|---|---|
| 0 | (1,1)=0 |
| 1 | (1,2)=1, (2,1)=1 |
| 2 | (1,3)=4, (3,1)=2 |
| 3 | (1,4)=5, (2,3)=5, (3,2)=3 |
| 4 | (2,4)=6, (3,3)=4 |
| 5 | (3,4)=5 |
| 6 | Ninguna: es igual al paso 5, y el consumo se detiene |

El índice de estabilización es 5 y el costo mínimo hasta la meta (1,4) es 5.

Con B = 4 la casilla (1,4) costaría 5, que supera B, así que se descarta y la meta queda sin costo. Por eso se omite la enumeración.

### Por qué la relajación es un filtro y no reemplaza la enumeración

**Sirve como filtro** porque si una casilla no aparece en el estado final, ningún camino llega a ella sin superar `B`. La búsqueda puede ignorarla con seguridad, y si la meta no aparece no hay nada que enumerar.

**No reemplaza la enumeración** por cuatro razones:

1. **Solo guarda el costo mínimo por casilla.** No guarda los caminos. Con B = 10, el recorrido 4 llega a (1,3) con energía 8, pero el estado final solo dice (1,3)=4. Ese recorrido es válido y la relajación no lo muestra.
2. **No recuerda las casillas ya visitadas.** Los costos se calculan por vecinos, sin saber por dónde se pasó. Que una casilla tenga costo no garantiza que exista un recorrido simple que la use.
3. **No lista las rutas.** El enunciado pide coordenadas, movimientos y energía de cada recorrido.
4. **No permite contar empates ni alternativas.** En `limite_empates` hay dos recorridos de energía 2, y el estado final solo tiene un número para la meta: `2`.

---

## Bloque 3: robot, búsqueda recursiva y escritura del SVG

### `explorar/5`, `probar_direcciones/6` e `intentar_entrar/6`

Estas tres funciones forman una recursión indirecta, como `determinar_par?` y `determinar_impar?`:

- **`explorar`:** decide si ya llegó a la meta.
- **`probar_direcciones`:** recorre arriba, derecha, abajo e izquierda.
- **`intentar_entrar`:** decide si puede entrar a la casilla vecina y, si puede, vuelve a llamar a `explorar`.

**Caso base:** `explorar` llega a la meta, registra el recorrido y no sigue. `probar_direcciones` se queda sin direcciones y retorna lo encontrado.

**Rechazos, en orden:**

1. Fuera del mapa: cláusula con `nil`.
2. No transitable: pattern matching con `%Terreno{transitable: false}`.
3. Se pasa de la batería: guarda `when energia + terreno.costo > contexto.presupuesto`.
4. Ya visitada, o ausente del estado final: `if` con `visitada?`.

**Backtracking con inmutabilidad:** el camino nunca se modifica. Cada llamada recibe `camino ++ [nueva]`, una lista nueva, y al volver la llamada anterior sigue teniendo su propio camino. Por eso retroceder no exige borrar nada.

Ejemplo con `limite_empates`, donde `S` está en (1,1) y `M` en (2,2):

```
X X X X
X S . X
X . M X
X X X X
```

1. Desde (1,1), arriba: (0,1) es `X`, se rechaza.
2. Derecha: entra a (1,2) con energía 1.
3. Desde (1,2), arriba y derecha son `X`.
4. Abajo: entra a (2,2) con energía 2. Es la meta y se registra el **recorrido 1**.
5. Izquierda: (1,1) ya está en el camino, se rechaza. Termina esta rama.
6. De vuelta en (1,1), el camino otra vez es `[(1,1)]`. Abajo: entra a (2,1) con energía 1.
7. Desde (2,1), arriba: (1,1) ya fue visitada. Derecha: entra a (2,2) con energía 2. Es la meta y se registra el **recorrido 2**.
8. Las direcciones restantes se rechazan y se retornan los 2 recorridos.

### `visitada?/2`

- **Caso base:** camino vacío, retorna `false`.
- **Coincidencia:** si la cabeza es la posición, retorna `true`.
- **Caso recursivo:** sigue buscando en la cola.

Ejemplo: `visitada?({1, 2}, [{1, 1}, {1, 2}])` descarta `{1, 1}`, encuentra `{1, 2}` y retorna `true`.

### `calcular_direcciones/1`

- **Qué hace:** convierte posiciones consecutivas en nombres de dirección.
- **Caso base:** queda una sola posición, no hay más movimientos.
- **Caso recursivo:** resta las dos primeras posiciones, nombra el movimiento y sigue desde la segunda.

Ejemplo con `[{1, 1}, {1, 2}, {2, 2}]`:

1. `{1, 2} - {1, 1} = {0, 1}`, que es `derecha`.
2. `{2, 2} - {1, 2} = {1, 0}`, que es `abajo`.
3. Queda `{2, 2}` y termina: `["derecha", "abajo"]`.

### `dibujar_svg/1`: escritura progresiva

- **Qué hace:** genera `ruta_optima.svg` por partes, en este orden: apertura, fondo, casillas, ruta, leyenda y cierre.
- **Por qué es progresiva:** `Archivo.crear` escribe la apertura y `Archivo.agregar_lineas` envía cada elemento por separado al archivo. Nunca existe un string con todo el documento.
- **Ruta dibujada:** `Enum.min_by` retorna el primer recorrido de menor energía, y ese es el criterio de desempate.

### `segmentos_ruta/1`

- **Caso base:** queda una sola posición.
- **Caso recursivo:** crea un `<line>` entre las dos primeras y sigue desde la segunda.

Ejemplo: para (1,1) y (1,2) los centros son x = 1·40+20 = 60, y = 60, y x = 2·40+20 = 100, y = 60. El elemento es una línea de (60,60) a (100,60).

### `escapar_xml/1`

- **Qué hace:** reemplaza los caracteres especiales de XML para que el SVG abra sin errores.
- **Por qué `&` va primero:** si fuera después, también dañaría los `&` de los reemplazos anteriores. `<` se convertiría en `&lt;` y luego en `&amp;lt;`.

Ejemplo: `a<b & c` se convierte en `a&lt;b &amp; c`.

---

## Bloque 4: ADN, lectura, validación y agrupación

### `clasificar_linea/1`

- **Qué hace:** convierte cada línea útil en `{:encabezado, id, linea}` o `{:secuencia, texto_en_mayusculas, linea}`.
- **Por qué es perezosa:** se aplica con `Stream.map`, una línea a la vez.

Ejemplo: `{"> muestra_1", 1}` se convierte en `{:encabezado, "muestra_1", 1}`, y `{"acgt", 2}` en `{:secuencia, "ACGT", 2}`.

### `recorrer_lineas/4`

- **Qué hace:** valida `muestras.txt` y recuerda la muestra abierta en `actual`, que vale `nil` antes del primer encabezado o `{id, linea, bases}` después.
- **Caso base:** no quedan líneas, y se revisa que la última muestra tenga bases.
- **Casos recursivos:** uno por forma. Encabezado, secuencia sin encabezado y secuencia de una muestra.

Ejemplo con el caso `invalido`:

1. Línea 1, `GATTACA` con `actual = nil`: error, hay datos antes del primer encabezado.
2. Línea 2, `>muestra_a`: abre la muestra.
3. Línea 3, `ACGT`: suma 4 bases.
4. Línea 4, `>`: la muestra anterior tiene bases. Error: el encabezado no tiene identificador.
5. Línea 6, `>muestra_a`: error, el id ya se usó en la línea 2.
6. Línea 7, `ACNT`: error en la posición 2, carácter `N`.
7. Línea 9, `>muestra_c`: al cerrar `muestra_vacia`, que quedó con 0 bases, se reporta el error con su línea, la 8.

### `revisar_caracteres/4` y `base_valida?/1`

- **Qué hacen:** revisan carácter por carácter con un contador de posición. Sirven para secuencias y para motivos.
- **Caso base:** no quedan caracteres.
- **Caso recursivo:** revisa la cabeza y sigue con `posicion + 1`.

Ejemplo con `["A", "X", "G"]`: en la posición 0 `A` es válida, en la 1 `X` genera un error, y en la 2 `G` es válida.

### `agrupar_muestras/3`

- **Qué hace:** une las líneas de cada muestra en un `%Muestra{}`.
- **Caso base:** no quedan líneas, y se guarda la última muestra abierta.
- **Caso recursivo:** un encabezado guarda la muestra abierta y abre otra. Una secuencia crea una muestra nueva con el texto concatenado.

Ejemplo con `valido`:

1. `>muestra_1` abre la muestra con secuencia `""`.
2. `ACGT` deja la secuencia en `"ACGT"`.
3. `ACG` la deja en `"ACGTACG"`.
4. `>muestra_2` guarda la primera muestra y abre otra.
5. `GGTACA` deja la segunda en `"GGTACA"`.
6. Al terminar la lista se guarda la segunda muestra.

### `quitar_duplicados/3` y `motivo_visto?/2`

- **Qué hacen:** eliminan motivos repetidos y conservan la primera aparición.
- **Caso base:** no quedan motivos, retorna `{unicos, descartados}`.
- **Caso recursivo:** si ya se vio, va a `descartados`. Si no, va al final de `unicos`.

Ejemplo con `ACG`, `TAC`, `GGA`, `ACG`: los tres primeros van a `unicos` y el cuarto va a `descartados` con su línea.

---

## Bloque 5: ADN, reversa complementaria y búsqueda de motivos

### `reversa_complementaria/2`

- **Qué hace:** invierte y complementa una lista de bases en una sola pasada.
- **Caso base:** no quedan bases, retorna el acumulado.
- **Caso recursivo:** antepone `complemento(cabeza)` al acumulado. Como lo nuevo queda adelante, la lista termina invertida.

Ejemplo con `ACG`:

| Cabeza | Complemento | Acumulado |
|---|---|---|
| A | T | `[T]` |
| C | G | `[G, T]` |
| G | C | `[C, G, T]` |

El resultado es `CGT`.

### `contar_diferencias/3`

- **Qué hace:** compara el motivo con la ventana base por base. Solo cuenta sustituciones, porque las dos listas avanzan siempre al mismo tiempo.
- **Corte:** la guarda `when diferencias > @maximo_diferencias` detiene la comparación cuando ya hay 2 diferencias.
- **Caso base:** se acabó el motivo.
- **Caso recursivo:** si las cabezas son iguales no suma. Si son distintas suma 1.

Ejemplo sin corte, `GGA` contra `GTA`:

1. `G` y `G` son iguales, 0 diferencias.
2. `G` y `T` son distintas, 1 diferencia.
3. `A` y `A` son iguales, 1 diferencia.
4. Se acabó el motivo: retorna 1, y es coincidencia.

Ejemplo con corte, `ACG` contra `GTA`:

1. `A` y `G` son distintas, 1 diferencia.
2. `C` y `T` son distintas, 2 diferencias.
3. La guarda corta y retorna 2, sin comparar `G` con `A`.

### `buscar_en_secuencia/5`

- **Qué hace:** recorre la secuencia ventana por ventana y registra cada coincidencia, incluso si se superponen.
- **Caso base:** quedan menos bases que la longitud del motivo. Esto también descarta sin comparar un motivo más largo que la muestra.
- **Caso recursivo:** compara en la posición actual y sigue con la `cola`, en `posicion + 1`.

Ejemplo buscando `TAC` en `GGTACA`:

| Posición | Ventana | Diferencias | Resultado |
|---|---|---|---|
| 0 | GGT | 2 (corta) | No |
| 1 | GTA | 2 (corta) | No |
| 2 | TAC | 0 | Coincidencia, inicio 2, fin 4 |
| 3 | ACA | 2 (corta) | No |
| 4 | quedan 2 bases | | Caso base |

### `buscar_motivo/2`: orientación `-`

- **Qué hace:** busca el motivo y su reversa complementaria sobre la **misma** secuencia directa.
- **Por qué así:** las posiciones `-` quedan en las mismas coordenadas que las `+`.

Ejemplo: con el motivo `ACGT`, la reversa complementaria es `ACGT`. En la muestra `ACGT` hay una coincidencia `+` en 0–3 y otra `-` en 0–3, y se cuentan por separado.

### `clave_orden/1` y `orden_orientacion/1`

- **Qué hacen:** `Enum.sort_by` ordena por la tupla `{muestra, motivo, inicio, orden}`.
- **Por qué existe `orden_orientacion`:** convierte `+` en 0 y `-` en 1, para que `+` quede antes de `-` en la misma posición.

Ejemplo: `{"m", "ACG", 0, 1}` queda después de `{"m", "ACG", 0, 0}` y antes de `{"m", "ACG", 1, 0}`.
