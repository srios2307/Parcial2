defmodule Archivo do
  @moduledoc """
  Módulo compartido por los dos problemas: es el único lugar del proyecto
  que lee o escribe archivos (idea de la Guía 11).
  - autor: Grupo Parcial 2, Programación III G2D
  - fecha: 2026-11-02
  - licencia: GNU GPL v3
  """

  @doc """
  Indica si existe un archivo.

  ## Parámetro
    - ruta: ruta del archivo

  ## Retorna
    - true si existe, false si no
  """
  def existe?(ruta), do: File.exists?(ruta)

  @doc """
  Retorna un Stream perezoso con las líneas útiles de un archivo.
  Una línea útil no está vacía y no empieza por `#`.

  ## Parámetro
    - ruta: ruta del archivo de entrada

  ## Retorna
    - Stream de tuplas `{texto_limpio, numero_linea}`, con la línea física desde 1
  """
  def leer_lineas_utiles(ruta) do
    # Stream.with_index(1) es la versión perezosa de Enum.with_index: le pega a
    # cada línea su número ANTES de quitar comentarios, así el número que queda
    # es la línea física del archivo aunque se ignoren otras líneas.
    # String.trim también elimina el \r de los archivos de Windows.
    ruta
    |> File.stream!()
    |> Stream.with_index(1)
    |> Stream.map(fn {linea, numero} -> {String.trim(linea), numero} end)
    |> Stream.reject(fn {texto, _numero} -> linea_ignorable?(texto) end)
  end

  # Recibe un texto ya limpio y retorna true si es una línea vacía o un comentario.
  defp linea_ignorable?(""), do: true
  defp linea_ignorable?(texto), do: String.starts_with?(texto, "#")

  @doc """
  Crea la carpeta indicada, con sus carpetas padre, si todavía no existe.
  """
  def crear_carpeta(ruta), do: File.mkdir_p!(ruta)

  @doc """
  Crea el archivo o lo reemplaza si ya existe, dejando en él solo el texto dado.
  """
  def crear(ruta, texto), do: File.write(ruta, texto)

  @doc """
  Agrega un texto al final de un archivo que ya existe.
  """
  def agregar(ruta, texto), do: File.write(ruta, texto, [:append])

  @doc """
  Agrega varias líneas al final de un archivo, una por una.
  No une las líneas en un solo string: cada una viaja por el Stream y se
  escribe por separado (escritura progresiva).

  ## Parámetros
    - ruta: ruta del archivo de salida
    - lineas: colección de textos, sin salto de línea al final
  """
  def agregar_lineas(ruta, lineas) do
    lineas
    |> Stream.map(&(&1 <> "\n"))
    |> Enum.into(File.stream!(ruta, [:append]))

    :ok
  end
end
