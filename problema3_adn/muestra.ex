defmodule Muestra do
  @moduledoc """
  Estructura con una muestra de ADN leída de muestras.txt.
  - autor: Grupo Parcial 2, Programación III G2D
  - fecha: 2026-11-02
  - licencia: GNU GPL v3
  """

  defstruct id: "", secuencia: "", linea: 0

  @doc """
  Crea una muestra.

  ## Parámetros
    - id: identificador que aparece después de `>`
    - secuencia: bases de la muestra, ya unidas y en mayúsculas
    - linea: línea física del encabezado

  ## Ejemplo
      Muestra.crear("muestra_1", "ACGT", 1)
  """
  def crear(id, secuencia, linea) do
    %Muestra{id: id, secuencia: secuencia, linea: linea}
  end
end
