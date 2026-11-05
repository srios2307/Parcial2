defmodule BusquedaAdn do
  @moduledoc """
  Problema 3: búsqueda de motivos de ADN con hasta un error.
  Busca cada motivo en cada muestra, en orientación directa (+) y en reversa
  complementaria (-), permitiendo 0 o 1 sustituciones.
  - autor: Grupo Parcial 2, Programación III G2D
  - fecha: 2026-11-02
  - licencia: GNU GPL v3
  """

  @archivo_muestras "muestras.txt"
  @archivo_motivos "motivos.txt"
  @archivo_validacion "validacion_adn.txt"
  @archivo_coincidencias "coincidencias_adn.csv"
  @archivo_resumen "resumen_adn.txt"

  @marca_encabezado ">"
  @maximo_diferencias 1

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
    |> preparar_datos()
    |> buscar_coincidencias()
    |> escribir_coincidencias()
    |> generar_resumen()
    |> mostrar_resultado()
  end

  
  # RUTAS Y VERIFICACIÓN DE ARCHIVOS
  

  # Recibe el nombre del caso y retorna un mapa con todas las rutas de entrada y salida.
  defp preparar_rutas(caso) do
    datos = __DIR__ |> Path.join("datos") |> Path.join(caso)
    salida = __DIR__ |> Path.join("salidas") |> Path.join(caso)

    %{
      muestras: Path.join(datos, @archivo_muestras),
      motivos: Path.join(datos, @archivo_motivos),
      salida: salida,
      validacion: Path.join(salida, @archivo_validacion),
      coincidencias: Path.join(salida, @archivo_coincidencias),
      resumen: Path.join(salida, @archivo_resumen)
    }
  end

  # Retorna {:ok, rutas} si existen las 2 entradas, o {:error, aviso} con las que faltan.
  defp verificar_archivos(rutas) do
    [rutas.muestras, rutas.motivos]
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

 
  # LECTURA PEREZOSA

  # Si un paso anterior falló, el error pasa de largo. Todos los pasos del
  # pipeline tienen esta primera cláusula, una cláusula por forma de resultado.
  defp leer_entradas({:error, motivo}), do: {:error, motivo}

  # Lee los 2 archivos. Retorna {:ok, rutas, lineas_muestras, lineas_motivos}.
  defp leer_entradas({:ok, rutas}) do
    {:ok, rutas, leer_muestras(rutas.muestras), leer_motivos(rutas.motivos)}
  end

  # Retorna una lista de {:encabezado, id, linea} o {:secuencia, texto, linea}.
  defp leer_muestras(ruta) do
    ruta
    |> Archivo.leer_lineas_utiles()
    |> Stream.map(&clasificar_linea/1)
    |> Enum.to_list()
  end

  # Retorna una lista de {motivo_en_mayusculas, linea}.
  defp leer_motivos(ruta) do
    ruta
    |> Archivo.leer_lineas_utiles()
    |> Stream.map(fn {texto, linea} -> {String.upcase(texto), linea} end)
    |> Enum.to_list()
  end

  # Las líneas que empiezan por > son encabezados, no comentarios.
  defp clasificar_linea({texto, linea}) do
    texto
    |> String.starts_with?(@marca_encabezado)
    |> clasificar_por_inicio(texto, linea)
  end

  # Separa el primer carácter (el >) del resto: el resto es el id de la muestra.
  defp clasificar_por_inicio(true, texto, linea) do
    [_marca | resto] = String.graphemes(texto)

    id =
      resto
      |> Enum.join()
      |> String.trim()

    {:encabezado, id, linea}
  end

  defp clasificar_por_inicio(false, texto, linea), do: {:secuencia, String.upcase(texto), linea}

  
  # VALIDACIÓN RECURSIVA (regla 7: aquí no se llama ninguna función de los
  # módulos de colecciones ni de flujos; todo es recursión propia)


  defp validar_entradas({:error, motivo}), do: {:error, motivo}

  # Valida, escribe el archivo de validación y decide si se puede continuar.
  defp validar_entradas({:ok, rutas, lineas_muestras, lineas_motivos}) do
    Archivo.crear_carpeta(rutas.salida)

    []
    |> validar_muestras(lineas_muestras)
    |> validar_motivos(lineas_motivos)
    |> escribir_validacion(rutas.validacion)
    |> decidir_continuar(rutas, lineas_muestras, lineas_motivos)
  end

  # --- Muestras ---

  # actual vale nil mientras no haya aparecido ningún encabezado.
  defp validar_muestras(errores, lineas), do: recorrer_lineas(lineas, nil, [], errores)

  # Patrón [cabeza | cola]: cabeza es el primer elemento de la lista y cola es
  # la lista con el resto. Así se recorre una lista sin usar funciones externas.
  # actual es {id, linea, bases} de la muestra abierta; vistos, los ids anteriores.
  # Caso base: no quedan líneas, se revisa que la última muestra tenga bases.
  defp recorrer_lineas([], actual, _vistos, errores), do: revisar_bases(errores, actual)

  # Caso recursivo (encabezado): cierra la muestra anterior, revisa el id y abre otra.
  defp recorrer_lineas([{:encabezado, id, linea} | cola], actual, vistos, errores) do
    nuevos =
      errores
      |> revisar_bases(actual)
      |> revisar_id_vacio(id, linea)
      |> revisar_id_repetido(id, linea, vistos)

    recorrer_lineas(cola, {id, linea, 0}, vistos ++ [{id, linea}], nuevos)
  end

  # Caso recursivo (secuencia antes del primer encabezado): error de ubicación.
  defp recorrer_lineas([{:secuencia, texto, linea} | cola], nil, vistos, errores) do
    error = "muestras.txt, línea #{linea}: hay datos de secuencia antes del primer encabezado"
    nuevos = revisar_caracteres(String.graphemes(texto), 0, "muestras.txt, línea #{linea}, sin muestra", errores ++ [error])
    recorrer_lineas(cola, nil, vistos, nuevos)
  end

  # Caso recursivo (secuencia de una muestra): revisa sus bases y las cuenta.
  defp recorrer_lineas([{:secuencia, texto, linea} | cola], {id, linea_id, bases}, vistos, errores) do
    caracteres = String.graphemes(texto)
    nuevos = revisar_caracteres(caracteres, 0, "muestras.txt, línea #{linea}, muestra #{id}", errores)
    recorrer_lineas(cola, {id, linea_id, bases + length(caracteres)}, vistos, nuevos)
  end

  # Solo es error si hay una muestra abierta y no tiene bases.
  defp revisar_bases(errores, {id, linea, 0}) do
    errores ++ ["muestras.txt, línea #{linea}: la muestra #{id} no tiene ninguna base"]
  end

  defp revisar_bases(errores, _actual), do: errores

  defp revisar_id_vacio(errores, "", linea) do
    errores ++ ["muestras.txt, línea #{linea}: el encabezado no tiene identificador"]
  end

  defp revisar_id_vacio(errores, _id, _linea), do: errores

  # Un id vacío ya se reportó arriba, no se reporta también como repetido.
  defp revisar_id_repetido(errores, "", _linea, _vistos), do: errores

  defp revisar_id_repetido(errores, id, linea, vistos) do
    reportar_repetido(buscar_linea(id, vistos), id, linea, errores)
  end

  defp reportar_repetido(nil, _id, _linea, errores), do: errores

  defp reportar_repetido(linea_anterior, id, linea, errores) do
    errores ++ ["muestras.txt, línea #{linea}: el id #{id} ya se usó en la línea #{linea_anterior}"]
  end

  # Busca un id en la lista de {id, linea}. Retorna la línea o nil.
  # Caso base: lista vacía, no está. Si el primero tiene el mismo id (el nombre
  # id aparece dos veces en el patrón, deben ser iguales), lo encontró.
  # Caso recursivo: busca en la cola.
  defp buscar_linea(_id, []), do: nil
  defp buscar_linea(id, [{id, linea} | _cola]), do: linea
  defp buscar_linea(id, [_cabeza | cola]), do: buscar_linea(id, cola)

  # --- Motivos ---

  # Caso base: no quedan motivos. Caso recursivo: revisa la cabeza y sigue con la cola.
  defp validar_motivos(errores, []), do: errores

  defp validar_motivos(errores, [{motivo, linea} | cola]) do
    errores
    |> revisar_motivo(motivo, linea)
    |> validar_motivos(cola)
  end

  defp revisar_motivo(errores, motivo, linea) do
    revisar_caracteres(String.graphemes(motivo), 0, "motivos.txt, línea #{linea}, motivo #{motivo}", errores)
  end

  # --- Caracteres (sirve para secuencias y para motivos) ---

  # Revisa carácter por carácter con un contador de posición.
  # Caso base: no quedan caracteres. Caso recursivo: revisa la cabeza y sigue.
  defp revisar_caracteres([], _posicion, _ubicacion, errores), do: errores

  defp revisar_caracteres([caracter | cola], posicion, ubicacion, errores) do
    nuevos = reportar_caracter(base_valida?(caracter), caracter, posicion, ubicacion, errores)
    revisar_caracteres(cola, posicion + 1, ubicacion, nuevos)
  end

  defp reportar_caracter(true, _caracter, _posicion, _ubicacion, errores), do: errores

  defp reportar_caracter(false, caracter, posicion, ubicacion, errores) do
    errores ++ ["#{ubicacion}, posición #{posicion}: carácter inválido #{caracter}"]
  end

  defp base_valida?("A"), do: true
  defp base_valida?("C"), do: true
  defp base_valida?("G"), do: true
  defp base_valida?("T"), do: true
  defp base_valida?(_), do: false


  # FIN DE LA VALIDACIÓN RECURSIVA
  

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

  # Sin errores se continúa; con errores no se realiza la búsqueda.
  defp decidir_continuar([], rutas, lineas_muestras, lineas_motivos) do
    {:ok, rutas, lineas_muestras, lineas_motivos}
  end

  defp decidir_continuar(errores, rutas, _lineas_muestras, _lineas_motivos) do
    {:error, "Se encontraron #{length(errores)} errores de validación. Detalles en #{rutas.validacion}"}
  end

 
  # PREPARACIÓN DE LOS DATOS

  defp preparar_datos({:error, motivo}), do: {:error, motivo}

  # Retorna {:ok, rutas, muestras, motivos_unicos, descartados}.
  defp preparar_datos({:ok, rutas, lineas_muestras, lineas_motivos}) do
    muestras = agrupar_muestras(lineas_muestras, nil, [])
    {unicos, descartados} = quitar_duplicados(lineas_motivos, [], [])
    {:ok, rutas, muestras, unicos, descartados}
  end

  # Une las líneas de secuencia de cada muestra. Retorna una lista de %Muestra{}.
  # Caso base: no quedan líneas, se guarda la última muestra si hay una abierta.
  defp agrupar_muestras([], nil, acumulado), do: acumulado
  defp agrupar_muestras([], actual, acumulado), do: acumulado ++ [actual]

  # Caso recursivo (primer encabezado): abre la primera muestra.
  defp agrupar_muestras([{:encabezado, id, linea} | cola], nil, acumulado) do
    agrupar_muestras(cola, Muestra.crear(id, "", linea), acumulado)
  end

  # Caso recursivo (otro encabezado): guarda la muestra abierta y abre otra.
  defp agrupar_muestras([{:encabezado, id, linea} | cola], actual, acumulado) do
    agrupar_muestras(cola, Muestra.crear(id, "", linea), acumulado ++ [actual])
  end

  # Caso recursivo (secuencia): concatena el texto a la muestra abierta.
  defp agrupar_muestras([{:secuencia, texto, _linea} | cola], actual, acumulado) do
    agrupar_muestras(cola, Muestra.crear(actual.id, actual.secuencia <> texto, actual.linea), acumulado)
  end

  # Quita los motivos repetidos conservando la primera aparición.
  # Retorna {motivos_unicos, descartados}, donde descartados guarda {motivo, linea}.
  # Caso base: no quedan motivos. Caso recursivo: clasifica la cabeza y sigue.
  defp quitar_duplicados([], unicos, descartados), do: {unicos, descartados}

  defp quitar_duplicados([{motivo, linea} | cola], unicos, descartados) do
    if motivo_visto?(motivo, unicos) do
      quitar_duplicados(cola, unicos, descartados ++ [{motivo, linea}])
    else
      quitar_duplicados(cola, unicos ++ [motivo], descartados)
    end
  end

  # Caso base: lista vacía, no se ha visto. Si la cabeza es igual, sí se ha visto.
  # Caso recursivo: sigue buscando en la cola.
  defp motivo_visto?(_motivo, []), do: false
  defp motivo_visto?(motivo, [motivo | _cola]), do: true
  defp motivo_visto?(motivo, [_cabeza | cola]), do: motivo_visto?(motivo, cola)

 
  # BÚSQUEDA DE COINCIDENCIAS
  

  defp buscar_coincidencias({:error, motivo}), do: {:error, motivo}

  # Busca todos los motivos en todas las muestras.
  defp buscar_coincidencias({:ok, rutas, muestras, motivos, descartados}) do
    coincidencias =
      muestras
      |> Enum.flat_map(fn muestra -> buscar_en_muestra(muestra, motivos) end)

    {:ok, rutas, muestras, motivos, descartados, coincidencias}
  end

  defp buscar_en_muestra(muestra, motivos) do
    Enum.flat_map(motivos, fn motivo -> buscar_motivo(muestra, motivo) end)
  end

  # Busca un motivo en sus dos orientaciones.
  # Orientación -: se busca la reversa complementaria del motivo sobre la
  # secuencia directa. Así las posiciones - quedan en las mismas coordenadas que
  # las +, y un motivo palindrómico produce una coincidencia de cada orientación.
  defp buscar_motivo(muestra, motivo) do
    bases = String.graphemes(muestra.secuencia)
    bases_motivo = String.graphemes(motivo)
    longitud = length(bases_motivo)
    reversa = reversa_complementaria(bases_motivo, [])

    directa = %{muestra: muestra.id, motivo: motivo, orientacion: "+", patron: bases_motivo}
    inversa = %{muestra: muestra.id, motivo: motivo, orientacion: "-", patron: reversa}

    buscar_en_secuencia(bases, directa, longitud, 0, []) ++
      buscar_en_secuencia(bases, inversa, longitud, 0, [])
  end

  defp complemento("A"), do: "T"
  defp complemento("T"), do: "A"
  defp complemento("C"), do: "G"
  defp complemento("G"), do: "C"

  # Recorre las bases y antepone el complemento de cada una al acumulado. Como
  # cada base nueva queda adelante, la lista termina invertida y complementada
  # en una sola pasada.
  # Ejemplo con ACG: A -> [T], C -> [G, T], G -> [C, G, T], o sea CGT.
  # Caso base: no quedan bases. Caso recursivo: agrega la cabeza y sigue con la cola.
  defp reversa_complementaria([], acumulado), do: acumulado

  defp reversa_complementaria([cabeza | cola], acumulado) do
    reversa_complementaria(cola, [complemento(cabeza) | acumulado])
  end

  # Recorre la secuencia ventana por ventana. busqueda lleva la muestra, el
  # motivo, la orientación y el patrón que se compara.
  # Caso base: quedan menos bases que la longitud del motivo. También cubre el
  # motivo más largo que la muestra, que se descarta sin comparar ninguna ventana.
  defp buscar_en_secuencia(bases, _busqueda, longitud, _posicion, encontradas)
       when length(bases) < longitud do
    encontradas
  end

  # Caso recursivo: compara en esta posición y avanza una base con la cola.
  # bases sirve de ventana porque el motivo termina primero que ella.
  defp buscar_en_secuencia([_cabeza | cola] = bases, busqueda, longitud, posicion, encontradas) do
    diferencias = contar_diferencias(busqueda.patron, bases, 0)
    nuevas = registrar(diferencias, busqueda, longitud, posicion, encontradas)
    buscar_en_secuencia(cola, busqueda, longitud, posicion + 1, nuevas)
  end

  # Cuenta las bases distintas entre el motivo y la ventana.
  # Corte: con más de 1 diferencia ya no sirve la ventana, no sigue comparando.
  defp contar_diferencias(_motivo, _ventana, diferencias) when diferencias > @maximo_diferencias do
    diferencias
  end

  # Caso base: se acabó el motivo.
  defp contar_diferencias([], _ventana, diferencias), do: diferencias

  # Caso recursivo: compara las cabezas y sigue con el resto. Solo hay
  # sustituciones: las dos listas avanzan siempre al mismo tiempo.
  defp contar_diferencias([a | resto1], [b | resto2], diferencias) when a == b do
    contar_diferencias(resto1, resto2, diferencias)
  end

  defp contar_diferencias([_a | resto1], [_b | resto2], diferencias) do
    contar_diferencias(resto1, resto2, diferencias + 1)
  end

  # Agrega una coincidencia si la ventana tiene 0 o 1 diferencias.
  defp registrar(diferencias, busqueda, longitud, posicion, encontradas)
       when diferencias <= @maximo_diferencias do
    encontradas ++
      [
        Coincidencia.crear(
          busqueda.muestra,
          busqueda.motivo,
          busqueda.orientacion,
          posicion,
          posicion + longitud - 1,
          diferencias
        )
      ]
  end

  defp registrar(_diferencias, _busqueda, _longitud, _posicion, encontradas), do: encontradas

  
  # SALIDAS: CSV Y RESUMEN
  

  defp escribir_coincidencias({:error, motivo}), do: {:error, motivo}

  # Ordena las coincidencias y escribe el encabezado y una fila por coincidencia.
  defp escribir_coincidencias({:ok, rutas, muestras, motivos, descartados, coincidencias}) do
    ordenadas = Enum.sort_by(coincidencias, &clave_orden/1)

    Archivo.crear(rutas.coincidencias, "muestra;motivo;orientacion;inicio;fin;diferencias\n")
    Archivo.agregar_lineas(rutas.coincidencias, Stream.map(ordenadas, &Coincidencia.a_linea_csv/1))

    {:ok, rutas, muestras, motivos, descartados, ordenadas}
  end

  # Muestra, motivo, inicio ascendente y + antes de -.
  defp clave_orden(c), do: {c.muestra, c.motivo, c.inicio, orden_orientacion(c.orientacion)}

  defp orden_orientacion("+"), do: 0
  defp orden_orientacion("-"), do: 1

  defp generar_resumen({:error, motivo}), do: {:error, motivo}

  # Escribe el resumen línea por línea y retorna el mensaje para la pantalla.
  defp generar_resumen({:ok, rutas, muestras, motivos, descartados, coincidencias}) do
    lineas = lineas_resumen(muestras, motivos, descartados, coincidencias)

    Archivo.crear(rutas.resumen, "")
    Archivo.agregar_lineas(rutas.resumen, lineas)
    {:ok, generar_mensaje(lineas, rutas.salida)}
  end

  # Función pura: une las secciones del resumen en una lista de líneas.
  defp lineas_resumen(muestras, motivos, descartados, coincidencias) do
    ["Coincidencias por motivo y muestra:"] ++
      lineas_conteo(muestras, motivos, coincidencias) ++
      ["Total de coincidencias: #{length(coincidencias)}", "Motivos que no aparecieron:"] ++
      lineas_lista(motivos_ausentes(motivos, coincidencias)) ++
      ["Motivos duplicados descartados:"] ++
      lineas_lista(textos_descartados(descartados)) ++
      ["Motivos más largos que alguna muestra:"] ++
      lineas_lista(motivos_largos(motivos, muestras))
  end

  # Cuenta por {muestra, motivo}. Map.get con 0 incluye las combinaciones sin coincidencias.
  defp lineas_conteo(muestras, motivos, coincidencias) do
    conteo = Enum.frequencies_by(coincidencias, fn c -> {c.muestra, c.motivo} end)

    muestras
    |> Enum.sort_by(& &1.id)
    |> Enum.flat_map(fn muestra ->
      motivos
      |> Enum.sort()
      |> Enum.map(fn motivo ->
        "  #{muestra.id} | #{motivo}: #{Map.get(conteo, {muestra.id, motivo}, 0)}"
      end)
    end)
  end

  defp motivos_ausentes(motivos, coincidencias) do
    conteo = Enum.frequencies_by(coincidencias, & &1.motivo)
    Enum.filter(motivos, fn motivo -> Map.get(conteo, motivo, 0) == 0 end)
  end

  defp textos_descartados(descartados) do
    Enum.map(descartados, fn {motivo, linea} -> "#{motivo} (línea #{linea})" end)
  end

  defp motivos_largos(motivos, muestras) do
    Enum.flat_map(motivos, fn motivo ->
      muestras
      |> Enum.filter(fn muestra -> longitud(motivo) > longitud(muestra.secuencia) end)
      |> Enum.map(fn muestra ->
        "#{motivo} (longitud #{longitud(motivo)}) en #{muestra.id} (longitud #{longitud(muestra.secuencia)})"
      end)
    end)
  end

  defp longitud(texto), do: length(String.graphemes(texto))

  # Una lista vacía se muestra como "ninguno" para que la sección no quede en blanco.
  defp lineas_lista([]), do: ["  ninguno"]
  defp lineas_lista(textos), do: Enum.map(textos, fn texto -> "  #{texto}" end)

  # Arma el texto que se muestra en pantalla.
  defp generar_mensaje(lineas, carpeta_salida) do
    Enum.join(lineas, "\n") <> "\nArchivos generados en #{carpeta_salida}\n"
  end

  
  # RESULTADO EN PANTALLA
 

  defp mostrar_resultado({:ok, mensaje}), do: Util2.mostrar(mensaje, :mensaje)
  defp mostrar_resultado({:error, motivo}), do: Util2.mostrar(motivo, :error)
end

BusquedaAdn.main()
