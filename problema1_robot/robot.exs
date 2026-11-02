defmodule RobotRescate do
  @moduledoc """
  Problema 1: robot de rescate con energía limitada y mapa SVG.
  Encuentra todos los recorridos simples de S a M que no superan la batería B.
  - autor: Grupo Parcial 2, Programación III G2D
  - fecha: 2026-11-02
  - licencia: GNU GPL v3
  """

  @archivo_edificio "edificio.txt"
  @archivo_terrenos "terrenos.csv"
  @archivo_bateria "bateria.txt"
  @archivo_validacion "validacion_edificio.txt"
  @archivo_expansion "expansion_energia.txt"
  @archivo_recorridos "recorridos_rescate.csv"
  @archivo_resumen "resumen_rescate.txt"
  @archivo_svg "ruta_optima.svg"

  # Estos tres símbolos los exige el enunciado. Solo la validación los usa.
  @simbolo_inicio "S"
  @simbolo_meta "M"
  @simbolo_borde "X"

  # Orden fijo de exploración: arriba, derecha, abajo, izquierda.
  @direcciones [{-1, 0}, {0, 1}, {1, 0}, {0, -1}]

  # Datos del dibujo SVG.
  @tamano 40
  @mitad_tamano 20
  @alto_leyenda 24
  @ancho_minimo 320
  @margen_texto 34
  @ancho_caracter 8
  @paleta ["#e9ecef", "#f8f9fa", "#b08968", "#80ed99", "#ffd166", "#90e0ef", "#cdb4db", "#ffafcc"]
  @color_no_transitable "#495057"
  @color_ruta "#d62828"
  @color_inicio "#2a9d8f"

  @doc """
  Función principal. Cada línea del pipeline es un paso de la descomposición.
  """
  def main do
    "Carpeta de datos (valido, invalido, limite_...): "
    |> Util2.ingresar(:texto)
    |> preparar_rutas()
    |> verificar_archivos()
    |> leer_entradas()
    |> validar_entradas()
    |> generar_relajacion()
    |> enumerar_recorridos()
    |> escribir_recorridos()
    |> generar_resumen()
    |> dibujar_svg()
    |> mostrar_resultado()
  end

  # ======================================================================
  # RUTAS Y VERIFICACIÓN DE ARCHIVOS
  # ======================================================================

  # Recibe el nombre del caso y retorna un mapa con todas las rutas de entrada y salida.
  defp preparar_rutas(caso) do
    datos = __DIR__ |> Path.join("datos") |> Path.join(caso)
    salida = __DIR__ |> Path.join("salidas") |> Path.join(caso)

    %{
      edificio: Path.join(datos, @archivo_edificio),
      terrenos: Path.join(datos, @archivo_terrenos),
      bateria: Path.join(datos, @archivo_bateria),
      salida: salida,
      validacion: Path.join(salida, @archivo_validacion),
      expansion: Path.join(salida, @archivo_expansion),
      recorridos: Path.join(salida, @archivo_recorridos),
      resumen: Path.join(salida, @archivo_resumen),
      svg: Path.join(salida, @archivo_svg)
    }
  end

  # Retorna {:ok, rutas} si existen las 3 entradas, o {:error, aviso} con las que faltan.
  defp verificar_archivos(rutas) do
    [rutas.edificio, rutas.terrenos, rutas.bateria]
    |> Stream.reject(&Archivo.existe?/1)
    |> Enum.to_list()
    |> resultado_verificacion(rutas)
  end

  defp resultado_verificacion([], rutas), do: {:ok, rutas}

  defp resultado_verificacion(faltantes, _rutas) do
    aviso =
      faltantes
      |> Enum.map(fn ruta -> "Error: no existe el archivo #{ruta}" end)
      |> Enum.join("\n")

    {:error, aviso}
  end

  # ======================================================================
  # LECTURA PEREZOSA
  # ======================================================================

  # Si un paso anterior falló, el error pasa de largo. Todos los pasos del
  # pipeline tienen esta primera cláusula, una cláusula por forma de resultado.
  defp leer_entradas({:error, motivo}), do: {:error, motivo}

  # Lee los 3 archivos. Retorna {:ok, rutas, entradas}.
  defp leer_entradas({:ok, rutas}) do
    entradas = %{
      registros: leer_terrenos(rutas.terrenos),
      filas: leer_edificio(rutas.edificio),
      lineas_bateria: leer_bateria(rutas.bateria)
    }

    {:ok, rutas, entradas}
  end

  # Retorna una lista de {:ok, %Terreno{}, linea} o {:error, mensaje, linea}.
  defp leer_terrenos(ruta) do
    ruta
    |> Archivo.leer_lineas_utiles()
    |> Stream.map(&convertir_terreno/1)
    |> Enum.to_list()
  end

  # Retorna una lista de {lista_de_simbolos, linea}.
  defp leer_edificio(ruta) do
    ruta
    |> Archivo.leer_lineas_utiles()
    |> Stream.map(fn {texto, linea} -> {String.split(texto), linea} end)
    |> Enum.to_list()
  end

  # Retorna una lista de {texto, linea}.
  defp leer_bateria(ruta) do
    ruta
    |> Archivo.leer_lineas_utiles()
    |> Enum.to_list()
  end

  # Recibe {texto, linea} de terrenos.csv y lo convierte en un registro.
  defp convertir_terreno({texto, linea}) do
    texto
    |> String.split(",")
    |> armar_terreno(linea)
  end

  # Con 4 campos revisa cada uno; con otra cantidad, el registro es incorrecto.
  defp armar_terreno([simbolo, nombre, transitable, costo], linea) do
    simbolo = String.trim(simbolo)
    transitable = transitable |> String.trim() |> convertir_transitable()
    costo = costo |> String.trim() |> convertir_entero()

    motivos =
      motivo_simbolo(simbolo) ++ motivo_transitable(transitable) ++ motivo_costo(costo)

    resultado_terreno(motivos, simbolo, String.trim(nombre), transitable, costo, linea)
  end

  defp armar_terreno(campos, linea) do
    {:error, "se esperaban 4 campos y hay #{length(campos)}", linea}
  end

  # Sin motivos de error se crea el terreno; con motivos se reportan todos juntos.
  defp resultado_terreno([], simbolo, nombre, transitable, {:ok, costo}, linea) do
    {:ok, Terreno.crear(simbolo, nombre, transitable, costo), linea}
  end

  defp resultado_terreno(motivos, _simbolo, _nombre, _transitable, _costo, linea) do
    {:error, Enum.join(motivos, "; "), linea}
  end

  defp convertir_transitable("si"), do: true
  defp convertir_transitable("no"), do: false
  defp convertir_transitable(_), do: :invalido

  # Cada función retorna [] si el campo está bien, o una lista con su motivo de error.
  defp motivo_simbolo(""), do: ["el símbolo está vacío"]
  defp motivo_simbolo(_), do: []

  defp motivo_transitable(:invalido), do: ["transitable debe ser si o no"]
  defp motivo_transitable(_), do: []

  defp motivo_costo(:error), do: ["el costo no es un entero"]
  defp motivo_costo({:ok, costo}) when costo < 0, do: ["el costo no puede ser negativo"]
  defp motivo_costo(_), do: []

  # Convierte texto a entero. Retorna {:ok, numero} o :error si el texto no es entero.
  defp convertir_entero(texto) do
    try do
      {:ok, String.to_integer(texto)}
    rescue
      ArgumentError -> :error
    end
  end

  # ======================================================================
  # VALIDACIÓN RECURSIVA (regla 7: aquí no se llama ninguna función de los
  # módulos de colecciones ni de flujos; todo es recursión propia)
  # ======================================================================

  defp validar_entradas({:error, motivo}), do: {:error, motivo}

  # Valida, escribe el archivo de validación y decide si se puede continuar.
  defp validar_entradas({:ok, rutas, entradas}) do
    Archivo.crear_carpeta(rutas.salida)

    entradas
    |> validar_datos()
    |> escribir_validacion(rutas.validacion)
    |> decidir_continuar(rutas, entradas)
  end

  # Corre todas las comprobaciones sobre un acumulador de errores y lo retorna.
  defp validar_datos(entradas) do
    []
    |> validar_terrenos(entradas.registros)
    |> validar_no_vacio(entradas.filas)
    |> validar_rectangular(entradas.filas)
    |> validar_simbolos_definidos(entradas.filas, extraer_simbolos(entradas.registros))
    |> validar_unico(@simbolo_inicio, entradas.filas)
    |> validar_unico(@simbolo_meta, entradas.filas)
    |> validar_borde(entradas.filas)
    |> validar_bateria(entradas.lineas_bateria)
  end

  # --- Terrenos ---

  defp validar_terrenos(errores, registros), do: recorrer_terrenos(registros, [], errores)

  # Patrón [cabeza | cola]: cabeza es el primer elemento de la lista y cola es
  # la lista con el resto. Así se recorre una lista sin usar funciones externas.
  # Caso base: la lista [] ya no tiene registros, se retornan los errores.
  defp recorrer_terrenos([], _vistos, errores), do: errores

  # Caso recursivo (registro mal formado): anota el error y sigue con la cola.
  defp recorrer_terrenos([{:error, mensaje, linea} | cola], vistos, errores) do
    recorrer_terrenos(cola, vistos, errores ++ ["terrenos.csv, línea #{linea}: #{mensaje}"])
  end

  # Caso recursivo (registro bien formado): revisa el terreno, lo recuerda en
  # vistos para detectar repetidos y sigue con la cola.
  defp recorrer_terrenos([{:ok, terreno, linea} | cola], vistos, errores) do
    nuevos =
      errores
      |> revisar_repetido(terreno.simbolo, linea, vistos)
      |> revisar_costo(terreno, linea)
      |> revisar_extremo_transitable(terreno, linea)

    recorrer_terrenos(cola, vistos ++ [{terreno.simbolo, linea}], nuevos)
  end

  defp revisar_repetido(errores, simbolo, linea, vistos) do
    reportar_repetido(buscar_linea(simbolo, vistos), simbolo, linea, errores)
  end

  defp reportar_repetido(nil, _simbolo, _linea, errores), do: errores

  defp reportar_repetido(linea_anterior, simbolo, linea, errores) do
    errores ++
      ["terrenos.csv, línea #{linea}: el símbolo #{simbolo} ya estaba definido en la línea #{linea_anterior}"]
  end

  # Busca un símbolo en la lista de {simbolo, linea}. Retorna la línea o nil.
  # Caso base: lista vacía, no está. Si el primero tiene el mismo símbolo (el
  # nombre simbolo aparece dos veces en el patrón, deben ser iguales), lo encontró.
  # Caso recursivo: busca en la cola.
  defp buscar_linea(_simbolo, []), do: nil
  defp buscar_linea(simbolo, [{simbolo, linea} | _cola]), do: linea
  defp buscar_linea(simbolo, [_cabeza | cola]), do: buscar_linea(simbolo, cola)

  # S puede costar 0; toda otra casilla transitable debe tener costo positivo.
  defp revisar_costo(errores, %Terreno{simbolo: @simbolo_inicio}, _linea), do: errores

  defp revisar_costo(errores, %Terreno{transitable: true, costo: 0, simbolo: simbolo}, linea) do
    errores ++ ["terrenos.csv, línea #{linea}: el terreno transitable #{simbolo} debe tener costo positivo"]
  end

  defp revisar_costo(errores, _terreno, _linea), do: errores

  # Sin S y M transitables no tendría sentido buscar una ruta.
  defp revisar_extremo_transitable(errores, %Terreno{simbolo: simbolo, transitable: false}, linea)
       when simbolo == @simbolo_inicio or simbolo == @simbolo_meta do
    errores ++ ["terrenos.csv, línea #{linea}: el terreno #{simbolo} debe ser transitable"]
  end

  defp revisar_extremo_transitable(errores, _terreno, _linea), do: errores

  # Retorna la lista de símbolos de los registros bien formados.
  # Caso base: lista vacía. Caso recursivo: toma el símbolo si el registro es
  # correcto y continúa con la cola.
  defp extraer_simbolos([]), do: []
  defp extraer_simbolos([{:ok, terreno, _linea} | cola]), do: [terreno.simbolo | extraer_simbolos(cola)]
  defp extraer_simbolos([_cabeza | cola]), do: extraer_simbolos(cola)

  # --- Forma del edificio ---

  defp validar_no_vacio(errores, []), do: errores ++ ["edificio.txt: el edificio está vacío"]
  defp validar_no_vacio(errores, _filas), do: errores

  defp validar_rectangular(errores, []), do: errores

  defp validar_rectangular(errores, [{primera, _linea} | cola]) do
    revisar_anchos(cola, length(primera), errores)
  end

  # Compara el tamaño de cada fila con el de la primera.
  # Caso base: no quedan filas. Caso recursivo: revisa la cabeza y sigue con la cola.
  defp revisar_anchos([], _esperado, errores), do: errores

  defp revisar_anchos([{simbolos, _linea} | cola], esperado, errores)
       when length(simbolos) == esperado do
    revisar_anchos(cola, esperado, errores)
  end

  defp revisar_anchos([{simbolos, linea} | cola], esperado, errores) do
    error = "edificio.txt, línea #{linea}: la fila tiene #{length(simbolos)} símbolos y se esperaban #{esperado}"
    revisar_anchos(cola, esperado, errores ++ [error])
  end

  # --- Símbolos definidos ---

  defp validar_simbolos_definidos(errores, filas, simbolos) do
    recorrer_filas_simbolos(filas, 0, simbolos, errores)
  end

  # Recorre las filas. Caso base: no quedan filas. Caso recursivo: revisa las
  # casillas de la fila actual y sigue con la siguiente fila.
  defp recorrer_filas_simbolos([], _fila, _simbolos, errores), do: errores

  defp recorrer_filas_simbolos([{celdas, _linea} | cola], fila, simbolos, errores) do
    nuevos = recorrer_celdas_simbolos(celdas, fila, 0, simbolos, errores)
    recorrer_filas_simbolos(cola, fila + 1, simbolos, nuevos)
  end

  # Recorre las casillas de una fila. Caso base: no quedan casillas.
  # Caso recursivo: revisa la cabeza y sigue con la siguiente columna.
  defp recorrer_celdas_simbolos([], _fila, _columna, _simbolos, errores), do: errores

  defp recorrer_celdas_simbolos([celda | cola], fila, columna, simbolos, errores) do
    nuevos = reportar_indefinido(simbolo_definido?(celda, simbolos), celda, fila, columna, errores)
    recorrer_celdas_simbolos(cola, fila, columna + 1, simbolos, nuevos)
  end

  defp reportar_indefinido(true, _celda, _fila, _columna, errores), do: errores

  defp reportar_indefinido(false, celda, fila, columna, errores) do
    errores ++ ["edificio.txt, coordenada {#{fila}, #{columna}}: el símbolo #{celda} no está definido en terrenos.csv"]
  end

  # Caso base: lista vacía, no está definido. Si la cabeza es igual, sí lo está.
  # Caso recursivo: sigue buscando en la cola.
  defp simbolo_definido?(_celda, []), do: false
  defp simbolo_definido?(celda, [celda | _cola]), do: true
  defp simbolo_definido?(celda, [_cabeza | cola]), do: simbolo_definido?(celda, cola)

  # --- Exactamente una S y una M ---

  defp validar_unico(errores, simbolo, filas) do
    reportar_cantidad(buscar_coordenadas(filas, simbolo, 0, []), simbolo, errores)
  end

  defp reportar_cantidad([_unica], _simbolo, errores), do: errores

  defp reportar_cantidad(coordenadas, simbolo, errores) do
    errores ++
      ["edificio.txt: debe existir exactamente un #{simbolo} y hay #{length(coordenadas)}#{coordenadas_a_texto(coordenadas)}"]
  end

  # Retorna la lista de coordenadas donde aparece un símbolo.
  # Caso base: no quedan filas. Caso recursivo: busca en la fila y sigue con la cola.
  defp buscar_coordenadas([], _simbolo, _fila, encontradas), do: encontradas

  defp buscar_coordenadas([{celdas, _linea} | cola], simbolo, fila, encontradas) do
    buscar_coordenadas(cola, simbolo, fila + 1, buscar_en_fila(celdas, simbolo, fila, 0, encontradas))
  end

  # Caso base: no quedan casillas. Si la cabeza es el símbolo buscado, guarda la
  # coordenada. Caso recursivo: sigue con la siguiente columna.
  defp buscar_en_fila([], _simbolo, _fila, _columna, encontradas), do: encontradas

  defp buscar_en_fila([simbolo | cola], simbolo, fila, columna, encontradas) do
    buscar_en_fila(cola, simbolo, fila, columna + 1, encontradas ++ [{fila, columna}])
  end

  defp buscar_en_fila([_otro | cola], simbolo, fila, columna, encontradas) do
    buscar_en_fila(cola, simbolo, fila, columna + 1, encontradas)
  end

  # Convierte una lista de coordenadas en texto: " en {1, 1} {3, 1}".
  # Caso base: lista vacía. Caso recursivo: agrega la cabeza y sigue con la cola.
  defp coordenadas_a_texto([]), do: ""
  defp coordenadas_a_texto(coordenadas), do: " en" <> unir_coordenadas(coordenadas)

  defp unir_coordenadas([]), do: ""

  defp unir_coordenadas([{fila, columna} | cola]) do
    " {#{fila}, #{columna}}" <> unir_coordenadas(cola)
  end

  # --- Borde ---

  defp validar_borde(errores, filas) do
    recorrer_filas_borde(filas, 0, length(filas) - 1, errores)
  end

  # Caso base: no quedan filas. Caso recursivo: revisa una fila y sigue con la cola.
  defp recorrer_filas_borde([], _fila, _ultima_fila, errores), do: errores

  defp recorrer_filas_borde([{celdas, _linea} | cola], fila, ultima_fila, errores) do
    limites = {fila, ultima_fila, length(celdas) - 1}
    nuevos = recorrer_celdas_borde(celdas, 0, limites, errores)
    recorrer_filas_borde(cola, fila + 1, ultima_fila, nuevos)
  end

  # Caso base: no quedan casillas. Una X siempre está bien, en el borde o no.
  # Caso recursivo: cualquier otro símbolo solo es error si está en el borde.
  defp recorrer_celdas_borde([], _columna, _limites, errores), do: errores

  defp recorrer_celdas_borde([@simbolo_borde | cola], columna, limites, errores) do
    recorrer_celdas_borde(cola, columna + 1, limites, errores)
  end

  defp recorrer_celdas_borde([celda | cola], columna, limites, errores) do
    nuevos = reportar_borde(en_borde?(columna, limites), celda, columna, limites, errores)
    recorrer_celdas_borde(cola, columna + 1, limites, nuevos)
  end

  # Una casilla está en el borde si está en la primera o última fila o columna.
  defp en_borde?(columna, {fila, ultima_fila, ultima_columna})
       when fila == 0 or fila == ultima_fila or columna == 0 or columna == ultima_columna,
       do: true

  defp en_borde?(_columna, _limites), do: false

  defp reportar_borde(false, _celda, _columna, _limites, errores), do: errores

  defp reportar_borde(true, celda, columna, {fila, _ultima_fila, _ultima_columna}, errores) do
    errores ++ ["edificio.txt, coordenada {#{fila}, #{columna}}: el borde debe ser #{@simbolo_borde} y hay #{celda}"]
  end

  # --- Batería ---

  defp validar_bateria(errores, []) do
    errores ++ ["bateria.txt: no hay ninguna línea de datos con B"]
  end

  defp validar_bateria(errores, [{texto, linea}]), do: revisar_valor_bateria(errores, texto, linea)

  defp validar_bateria(errores, lineas) do
    nuevos = errores ++ ["bateria.txt: se esperaba una sola línea de datos y hay #{length(lineas)}"]
    recorrer_lineas_bateria(lineas, nuevos)
  end

  # Caso base: no quedan líneas. Caso recursivo: revisa la cabeza y sigue con la cola.
  defp recorrer_lineas_bateria([], errores), do: errores

  defp recorrer_lineas_bateria([{texto, linea} | cola], errores) do
    recorrer_lineas_bateria(cola, revisar_valor_bateria(errores, texto, linea))
  end

  defp revisar_valor_bateria(errores, texto, linea) do
    reportar_valor_bateria(convertir_entero(texto), texto, linea, errores)
  end

  defp reportar_valor_bateria({:ok, valor}, _texto, _linea, errores) when valor > 0, do: errores

  defp reportar_valor_bateria({:ok, valor}, _texto, linea, errores) do
    errores ++ ["bateria.txt, línea #{linea}: B debe ser positivo y es #{valor}"]
  end

  defp reportar_valor_bateria(:error, texto, linea, errores) do
    errores ++ ["bateria.txt, línea #{linea}: B debe ser un entero y es #{texto}"]
  end

  # ======================================================================
  # FIN DE LA VALIDACIÓN RECURSIVA
  # ======================================================================

  # Escribe el archivo de validación línea por línea y retorna los errores.
  defp escribir_validacion([], ruta) do
    Archivo.crear(ruta, "Sin errores de validación\n")
    []
  end

  defp escribir_validacion(errores, ruta) do
    Archivo.crear(ruta, "Errores de validación encontrados: #{length(errores)}\n")
    Archivo.agregar_lineas(ruta, errores)
    errores
  end

  # Sin errores se construyen los datos; con errores no se hace relajación ni búsqueda.
  defp decidir_continuar([], rutas, entradas), do: {:ok, rutas, construir_datos(entradas)}

  defp decidir_continuar(errores, rutas, _entradas) do
    {:error, "Se encontraron #{length(errores)} errores de validación. Detalles en #{rutas.validacion}"}
  end

  # Arma los datos del problema. Solo se llama cuando la validación no halló errores.
  defp construir_datos(entradas) do
    terrenos = Enum.map(entradas.registros, fn {:ok, terreno, _linea} -> terreno end)
    [inicio] = buscar_coordenadas(entradas.filas, @simbolo_inicio, 0, [])
    [meta] = buscar_coordenadas(entradas.filas, @simbolo_meta, 0, [])
    [{texto_bateria, _linea}] = entradas.lineas_bateria
    [{primera_fila, _linea} | _resto] = entradas.filas

    %{
      lista_terrenos: terrenos,
      tabla_terrenos: construir_tabla_terrenos(terrenos),
      mapa_edificio: construir_mapa_edificio(entradas.filas),
      presupuesto: String.to_integer(texto_bateria),
      inicio: inicio,
      meta: meta,
      cantidad_filas: length(entradas.filas),
      cantidad_columnas: length(primera_fila)
    }
  end

  # Retorna %{simbolo => %Terreno{}}.
  defp construir_tabla_terrenos(terrenos) do
    terrenos
    |> Enum.map(fn terreno -> {terreno.simbolo, terreno} end)
    |> Enum.into(%{})
  end

  # Retorna %{{fila, columna} => simbolo}, como en el ejemplo del laberinto.
  defp construir_mapa_edificio(filas) do
    filas
    |> Enum.with_index()
    |> Enum.flat_map(fn {{celdas, _linea}, fila} -> celdas_con_coordenada(celdas, fila) end)
    |> Enum.into(%{})
  end

  defp celdas_con_coordenada(celdas, fila) do
    celdas
    |> Enum.with_index()
    |> Enum.map(fn {simbolo, columna} -> {{fila, columna}, simbolo} end)
  end

  # ======================================================================
  # STREAM INFINITO: RELAJACIÓN DE ENERGÍA MÍNIMA
  # ======================================================================

  defp generar_relajacion({:error, motivo}), do: {:error, motivo}

  # Calcula los pasos, los escribe y retorna el estado final.
  defp generar_relajacion({:ok, rutas, datos}) do
    pasos = calcular_pasos(datos)
    # Enum.at con -1 retorna el último elemento de la lista.
    {indice, _anterior, estado_final} = Enum.at(pasos, -1)
    escribir_expansion(pasos, indice, estado_final, rutas.expansion, datos)
    {:ok, rutas, datos, estado_final}
  end

  # Stream.iterate genera un Stream infinito de tuplas {paso, anterior, actual}.
  # Es infinito pero perezoso: solo se calcula lo que se consume.
  # take_while lo consume mientras el estado cambie, y se detiene en el primer
  # par de estados consecutivos iguales. Ese último elemento no queda en la lista,
  # así que la lista tiene solo los pasos distintos. El índice de estabilización
  # es el paso del último estado de la lista: el siguiente sería idéntico.
  defp calcular_pasos(datos) do
    estado_inicial = %{datos.inicio => 0}

    Stream.iterate({0, nil, estado_inicial}, fn {paso, _anterior, actual} ->
      {paso + 1, actual, relajar(actual, datos)}
    end)
    |> Stream.take_while(fn {_paso, anterior, actual} -> anterior != actual end)
    |> Enum.to_list()
  end

  # Calcula un estado nuevo solo a partir del estado anterior.
  # Recibe %{{fila, columna} => costo} y retorna un mapa del mismo tipo.
  defp relajar(estado, datos) do
    datos.mapa_edificio
    |> Enum.map(fn {posicion, simbolo} -> {posicion, datos.tabla_terrenos[simbolo]} end)
    |> Enum.filter(fn {_posicion, terreno} -> terreno.transitable end)
    |> Enum.map(fn {posicion, terreno} ->
      {posicion, mejor_costo(@direcciones, posicion, terreno.costo, estado, datos.presupuesto, estado[posicion])}
    end)
    |> Enum.filter(fn {_posicion, costo} -> costo != nil end)
    |> Enum.into(%{})
  end

  # Busca el menor costo de una posición revisando sus 4 vecinos.
  # mejor empieza con el costo ya conocido (o nil si no tiene ninguno).
  # Caso base: no quedan direcciones, retorna el mejor.
  # Caso recursivo: compara con lo que costaría llegar desde el vecino.
  defp mejor_costo([], _posicion, _entrada, _estado, _presupuesto, mejor), do: mejor

  defp mejor_costo([{df, dc} | cola], {fila, columna}, entrada, estado, presupuesto, mejor) do
    candidato = costo_desde_vecino(estado[{fila + df, columna + dc}], entrada, presupuesto)
    mejor_costo(cola, {fila, columna}, entrada, estado, presupuesto, menor_conocido(mejor, candidato))
  end

  # Retorna el costo de llegar desde un vecino, o nil si el vecino no tiene
  # costo conocido o si el resultado supera el presupuesto.
  defp costo_desde_vecino(nil, _entrada, _presupuesto), do: nil

  defp costo_desde_vecino(costo_vecino, entrada, presupuesto)
       when costo_vecino + entrada > presupuesto,
       do: nil

  defp costo_desde_vecino(costo_vecino, entrada, _presupuesto), do: costo_vecino + entrada

  # Retorna el menor de dos costos, donde nil significa "sin costo conocido".
  defp menor_conocido(nil, candidato), do: candidato
  defp menor_conocido(mejor, nil), do: mejor
  defp menor_conocido(mejor, candidato) when mejor <= candidato, do: mejor
  defp menor_conocido(_mejor, candidato), do: candidato

  # Escribe los pasos uno por uno y al final el índice y el costo hasta la meta.
  defp escribir_expansion(pasos, indice, estado_final, ruta, datos) do
    Archivo.crear(ruta, "")

    Enum.each(pasos, fn {paso, _anterior, estado} ->
      Archivo.agregar(ruta, "Paso #{paso}:\n")
      Archivo.agregar_lineas(ruta, lineas_estado(estado))
    end)

    Archivo.agregar(ruta, "Índice de estabilización: #{indice}\n")
    Archivo.agregar(ruta, linea_costo_meta(estado_final[datos.meta], datos.presupuesto))
  end

  # Enum.sort ordena las tuplas {{fila, columna}, costo} por fila y luego por columna.
  defp lineas_estado(estado) do
    estado
    |> Enum.sort()
    |> Enum.map(fn {{fila, columna}, costo} -> "(#{fila},#{columna}) = #{costo}" end)
  end

  defp linea_costo_meta(nil, presupuesto), do: "La meta no es alcanzable con B = #{presupuesto}\n"
  defp linea_costo_meta(costo, _presupuesto), do: "Costo mínimo hasta la meta: #{costo}\n"

  # ======================================================================
  # BÚSQUEDA RECURSIVA DE TODOS LOS RECORRIDOS SIMPLES
  # ======================================================================

  defp enumerar_recorridos({:error, motivo}), do: {:error, motivo}

  defp enumerar_recorridos({:ok, rutas, datos, estado_final}) do
    recorridos = buscar_si_alcanzable(estado_final[datos.meta], datos, estado_final)
    {:ok, rutas, datos, recorridos}
  end

  # Si la meta no tiene costo en el estado final se omite la enumeración.
  defp buscar_si_alcanzable(nil, _datos, _estado_final), do: []

  defp buscar_si_alcanzable(_costo, datos, estado_final) do
    contexto = %{
      mapa_edificio: datos.mapa_edificio,
      tabla_terrenos: datos.tabla_terrenos,
      presupuesto: datos.presupuesto,
      estado_final: estado_final,
      meta: datos.meta
    }

    explorar(datos.inicio, [datos.inicio], 0, contexto, [])
  end

  # Explora desde una posición y retorna la lista de recorridos encontrados.
  # Caso base: la posición es la meta (posicion aparece dos veces en el patrón,
  # deben ser iguales). Se registra el recorrido y no se sigue explorando.
  defp explorar(posicion, camino, energia, %{meta: posicion}, encontrados) do
    encontrados ++ [Recorrido.crear(camino, energia)]
  end

  # Caso recursivo: intenta avanzar en cada una de las 4 direcciones.
  defp explorar(posicion, camino, energia, contexto, encontrados) do
    probar_direcciones(@direcciones, posicion, camino, energia, contexto, encontrados)
  end

  # Recorre las direcciones en orden fijo.
  # Caso base: no quedan direcciones, retorna lo encontrado.
  # Caso recursivo: intenta entrar a la casilla vecina y sigue con las demás.
  # Backtracking con inmutabilidad: como camino nunca se modifica, al volver de
  # una llamada recursiva esta función sigue teniendo su propia versión del
  # camino. Así "retroceder" ocurre solo, sin tener que borrar nada.
  defp probar_direcciones([], _posicion, _camino, _energia, _contexto, encontrados), do: encontrados

  defp probar_direcciones([{df, dc} | cola], {fila, columna}, camino, energia, contexto, encontrados) do
    nueva = {fila + df, columna + dc}
    terreno = contexto.tabla_terrenos[contexto.mapa_edificio[nueva]]
    nuevos = intentar_entrar(terreno, nueva, camino, energia, contexto, encontrados)
    probar_direcciones(cola, {fila, columna}, camino, energia, contexto, nuevos)
  end

  # Fuera del mapa no hay terreno.
  defp intentar_entrar(nil, _nueva, _camino, _energia, _contexto, encontrados), do: encontrados

  # Pattern matching: un terreno no transitable se rechaza sin más revisiones.
  defp intentar_entrar(%Terreno{transitable: false}, _nueva, _camino, _energia, _contexto, encontrados) do
    encontrados
  end

  # Guarda: se rechaza si la energía superaría el presupuesto.
  defp intentar_entrar(terreno, _nueva, _camino, energia, contexto, encontrados)
       when energia + terreno.costo > contexto.presupuesto do
    encontrados
  end

  # Se rechaza si ya se visitó o si la relajación dijo que es inalcanzable.
  # Si no, avanza con un camino nuevo y la energía actualizada.
  defp intentar_entrar(terreno, nueva, camino, energia, contexto, encontrados) do
    if visitada?(nueva, camino) or contexto.estado_final[nueva] == nil do
      encontrados
    else
      explorar(nueva, camino ++ [nueva], energia + terreno.costo, contexto, encontrados)
    end
  end

  # Indica si una posición ya está en el camino.
  # Caso base: camino vacío, no está. Si la cabeza es igual, sí está.
  # Caso recursivo: sigue buscando en la cola.
  defp visitada?(_posicion, []), do: false
  defp visitada?(posicion, [posicion | _cola]), do: true
  defp visitada?(posicion, [_cabeza | cola]), do: visitada?(posicion, cola)

  # ======================================================================
  # SALIDAS: CSV Y RESUMEN
  # ======================================================================

  defp escribir_recorridos({:error, motivo}), do: {:error, motivo}

  # Escribe primero el encabezado y después una fila por recorrido.
  defp escribir_recorridos({:ok, rutas, datos, recorridos}) do
    Archivo.crear(rutas.recorridos, "id;movimientos;energia;posiciones\n")

    lineas =
      recorridos
      |> Enum.with_index(1)
      |> Stream.map(&linea_csv/1)

    Archivo.agregar_lineas(rutas.recorridos, lineas)
    {:ok, rutas, datos, recorridos}
  end

  defp linea_csv({recorrido, id}) do
    "#{id};#{movimientos(recorrido)};#{recorrido.energia};#{posiciones_a_texto(recorrido.posiciones)}"
  end

  defp movimientos(recorrido), do: length(recorrido.posiciones) - 1

  # Convierte [{1, 1}, {1, 2}] en "(1,1)->(1,2)".
  defp posiciones_a_texto(posiciones) do
    posiciones
    |> Enum.map(fn {fila, columna} -> "(#{fila},#{columna})" end)
    |> Enum.join("->")
  end

  defp generar_resumen({:error, motivo}), do: {:error, motivo}

  # Escribe el resumen línea por línea y retorna el mensaje para la pantalla.
  defp generar_resumen({:ok, rutas, datos, recorridos}) do
    lineas =
      recorridos
      |> Enum.with_index(1)
      |> lineas_resumen(datos.presupuesto)

    Archivo.crear(rutas.resumen, "")
    Archivo.agregar_lineas(rutas.resumen, lineas)
    {:ok, rutas, datos, recorridos, generar_mensaje(lineas, rutas.salida)}
  end

  # Función pura: recibe los recorridos con id y retorna las líneas del resumen.
  defp lineas_resumen([], presupuesto) do
    ["Total de recorridos: 0", "No existe recorrido válido con B = #{presupuesto}"]
  end

  defp lineas_resumen(con_id, _presupuesto) do
    menos_movimientos = con_id |> Enum.min_by(&movimientos_con_id/1) |> movimientos_con_id()
    menor_energia = con_id |> Enum.min_by(&energia_con_id/1) |> energia_con_id()

    ["Total de recorridos: #{length(con_id)}", "Menor número de movimientos: #{menos_movimientos}"] ++
      lineas_destacados(Enum.filter(con_id, &(movimientos_con_id(&1) == menos_movimientos))) ++
      ["Menor energía: #{menor_energia}"] ++
      lineas_destacados(Enum.filter(con_id, &(energia_con_id(&1) == menor_energia)))
  end

  defp movimientos_con_id({recorrido, _id}), do: movimientos(recorrido)
  defp energia_con_id({recorrido, _id}), do: recorrido.energia

  # Conserva los empates: aquí llegan todos los recorridos que alcanzan el mínimo.
  defp lineas_destacados(destacados), do: Enum.flat_map(destacados, &lineas_recorrido/1)

  defp lineas_recorrido({recorrido, id}) do
    [
      "  Recorrido #{id}",
      "    Coordenadas: #{posiciones_a_texto(recorrido.posiciones)}",
      "    Movimientos: #{movimientos(recorrido)}",
      "    Direcciones: #{recorrido.posiciones |> calcular_direcciones() |> Enum.join(", ")}",
      "    Energía: #{recorrido.energia}"
    ]
  end

  # Convierte posiciones consecutivas en nombres de dirección.
  # Caso base: queda una sola posición, no hay más movimientos.
  # Caso recursivo: nombra el movimiento entre las dos primeras y sigue con el resto.
  defp calcular_direcciones([_ultima]), do: []

  defp calcular_direcciones([{f1, c1}, {f2, c2} | cola]) do
    [nombre_direccion({f2 - f1, c2 - c1}) | calcular_direcciones([{f2, c2} | cola])]
  end

  defp nombre_direccion({-1, 0}), do: "arriba"
  defp nombre_direccion({0, 1}), do: "derecha"
  defp nombre_direccion({1, 0}), do: "abajo"
  defp nombre_direccion({0, -1}), do: "izquierda"

  # Arma el texto que se muestra en pantalla.
  defp generar_mensaje(lineas, carpeta_salida) do
    Enum.join(lineas, "\n") <> "\nArchivos generados en #{carpeta_salida}\n"
  end

  # ======================================================================
  # SALIDA: DIBUJO SVG (ESCRITURA PROGRESIVA)
  # ======================================================================

  defp dibujar_svg({:error, motivo}), do: {:error, motivo}

  # Cada parte del SVG se escribe por separado. Nunca se arma el documento en
  # un solo string: primero se abre, luego van las casillas, la ruta, la leyenda
  # y por último el cierre.
  defp dibujar_svg({:ok, rutas, datos, recorridos, mensaje}) do
    ruta = rutas.svg
    colores = asignar_colores(datos.lista_terrenos)
    ancho = calcular_ancho(datos)
    alto = datos.cantidad_filas * @tamano + (length(datos.lista_terrenos) + 2) * @alto_leyenda

    Archivo.crear(ruta, abrir_svg(ancho, alto))
    Archivo.agregar_lineas(ruta, [fondo_svg(ancho, alto)])
    Archivo.agregar_lineas(ruta, lineas_casillas(datos, colores))
    Archivo.agregar_lineas(ruta, lineas_ruta(recorrido_optimo(recorridos)))
    Archivo.agregar_lineas(ruta, lineas_leyenda(datos, colores, recorrido_optimo(recorridos)))
    Archivo.agregar(ruta, "</svg>\n")
    {:ok, mensaje}
  end

  # El dibujo debe ser tan ancho como el mapa y como el texto más largo de la
  # leyenda, para que un nombre largo de terreno no quede cortado.
  defp calcular_ancho(datos) do
    ancho_leyenda =
      datos.lista_terrenos
      |> Enum.map(fn terreno -> @margen_texto + longitud(texto_terreno(terreno)) * @ancho_caracter end)
      |> Enum.max()

    datos.cantidad_columnas * @tamano
    |> mayor(ancho_leyenda)
    |> mayor(@ancho_minimo)
  end

  defp longitud(texto), do: length(String.graphemes(texto))

  defp mayor(a, b) when a >= b, do: a
  defp mayor(_a, b), do: b

  # Enum.min_by retorna el primero que alcanza el mínimo: así se resuelve el empate.
  defp recorrido_optimo([]), do: nil
  defp recorrido_optimo(recorridos), do: Enum.min_by(recorridos, & &1.energia)

  defp abrir_svg(ancho, alto) do
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"#{ancho}\" height=\"#{alto}\" viewBox=\"0 0 #{ancho} #{alto}\">\n"
  end

  defp fondo_svg(ancho, alto) do
    "<rect x=\"0\" y=\"0\" width=\"#{ancho}\" height=\"#{alto}\" fill=\"white\"/>"
  end

  # Retorna %{simbolo => color}, según el orden del terreno en terrenos.csv.
  defp asignar_colores(terrenos) do
    terrenos
    |> Enum.with_index()
    |> Enum.map(fn {terreno, indice} -> {terreno.simbolo, color_terreno(terreno, indice)} end)
    |> Enum.into(%{})
  end

  defp color_terreno(%Terreno{transitable: false}, _indice), do: @color_no_transitable

  # rem hace que la paleta vuelva a empezar si hay más terrenos que colores.
  defp color_terreno(_terreno, indice), do: Enum.at(@paleta, rem(indice, length(@paleta)))

  # Retorna un <rect> y un <text> por casilla, ordenados por fila y columna.
  defp lineas_casillas(datos, colores) do
    datos.mapa_edificio
    |> Enum.sort()
    |> Enum.flat_map(fn {posicion, simbolo} ->
      lineas_casilla(posicion, datos.tabla_terrenos[simbolo], colores[simbolo])
    end)
  end

  defp lineas_casilla({fila, columna}, terreno, color) do
    x = columna * @tamano
    y = fila * @tamano

    [
      "<rect x=\"#{x}\" y=\"#{y}\" width=\"#{@tamano}\" height=\"#{@tamano}\" fill=\"#{color}\" stroke=\"#adb5bd\"/>",
      "<text x=\"#{centro(columna)}\" y=\"#{centro(fila)}\" text-anchor=\"middle\" dominant-baseline=\"central\" font-family=\"monospace\" font-size=\"16\" fill=\"#{color_texto(terreno)}\">#{escapar_xml(terreno.simbolo)}</text>"
    ]
  end

  defp color_texto(%Terreno{transitable: false}), do: "white"
  defp color_texto(_terreno), do: "black"

  # Sin recorrido no se dibuja nada. Con recorrido: una línea por movimiento, un
  # círculo en el inicio y otro en la meta.
  defp lineas_ruta(nil), do: []

  defp lineas_ruta(recorrido) do
    [primera | _resto] = recorrido.posiciones
    ultima = Enum.at(recorrido.posiciones, -1)

    segmentos_ruta(recorrido.posiciones) ++
      [circulo(primera, @color_inicio), circulo(ultima, @color_ruta)]
  end

  # Retorna un <line> entre los centros de cada par de casillas consecutivas.
  # Caso base: queda una sola posición. Caso recursivo: dibuja un segmento y sigue.
  defp segmentos_ruta([_ultima]), do: []

  defp segmentos_ruta([a, b | cola]), do: [segmento(a, b) | segmentos_ruta([b | cola])]

  defp segmento({f1, c1}, {f2, c2}) do
    "<line x1=\"#{centro(c1)}\" y1=\"#{centro(f1)}\" x2=\"#{centro(c2)}\" y2=\"#{centro(f2)}\" stroke=\"#{@color_ruta}\" stroke-width=\"5\" stroke-linecap=\"round\"/>"
  end

  defp circulo({fila, columna}, color) do
    "<circle cx=\"#{centro(columna)}\" cy=\"#{centro(fila)}\" r=\"9\" fill=\"#{color}\" fill-opacity=\"0.8\" stroke=\"black\"/>"
  end

  # Convierte un número de fila o columna en el píxel del centro de la casilla.
  defp centro(indice), do: indice * @tamano + @mitad_tamano

  # Retorna una línea por terreno (color, nombre, costo) y la nota de la ruta.
  defp lineas_leyenda(datos, colores, recorrido) do
    inicio_y = datos.cantidad_filas * @tamano + @mitad_tamano

    terrenos =
      datos.lista_terrenos
      |> Enum.with_index()
      |> Enum.flat_map(fn {terreno, indice} ->
        lineas_leyenda_terreno(terreno, colores[terreno.simbolo], inicio_y + indice * @alto_leyenda)
      end)

    y_nota = inicio_y + length(datos.lista_terrenos) * @alto_leyenda + 12
    terrenos ++ [texto_leyenda(10, y_nota, nota_ruta(recorrido))]
  end

  defp lineas_leyenda_terreno(terreno, color, y) do
    [
      "<rect x=\"10\" y=\"#{y}\" width=\"16\" height=\"16\" fill=\"#{color}\" stroke=\"#adb5bd\"/>",
      texto_leyenda(@margen_texto, y + 13, texto_terreno(terreno))
    ]
  end

  defp texto_terreno(terreno), do: "#{terreno.nombre} (#{terreno.simbolo}): costo #{terreno.costo}"

  # Todo texto de la leyenda pasa por escapar_xml.
  defp texto_leyenda(x, y, texto) do
    "<text x=\"#{x}\" y=\"#{y}\" font-family=\"sans-serif\" font-size=\"14\" fill=\"black\">#{escapar_xml(texto)}</text>"
  end

  defp nota_ruta(nil), do: "«sin recorrido»"
  defp nota_ruta(recorrido), do: "Energía de la ruta dibujada: #{recorrido.energia}"

  # Escapa los caracteres especiales de XML. & va primero para no volver a
  # escapar los & que agregan los reemplazos siguientes.
  defp escapar_xml(texto) do
    texto
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end

  # ======================================================================
  # RESULTADO EN PANTALLA
  # ======================================================================

  defp mostrar_resultado({:ok, mensaje}), do: Util2.mostrar(mensaje, :mensaje)
  defp mostrar_resultado({:error, motivo}), do: Util2.mostrar(motivo, :error)
end

RobotRescate.main()
