defmodule Coincidencia do
  @moduledoc """
  Estructura con una coincidencia de un motivo dentro de una muestra.
  - autor: Grupo Parcial 2, Programación III G2D
  - fecha: 2026-11-02
  - licencia: GNU GPL v3
  """

  defstruct muestra: "", motivo: "", orientacion: "+", inicio: 0, fin: 0, diferencias: 0

  @doc """
  Crea una coincidencia.

  ## Parámetros
    - muestra: id de la muestra
    - motivo: motivo original, tal como quedó en motivos.txt después de normalizar
    - orientacion: "+" para directa, "-" para reversa complementaria
    - inicio: posición inicial, desde 0
    - fin: posición final, inclusiva
    - diferencias: 0 o 1 sustituciones

  ## Ejemplo
      Coincidencia.crear("muestra_1", "ACG", "+", 0, 2, 0)
  """
  def crear(muestra, motivo, orientacion, inicio, fin, diferencias) do
    %Coincidencia{
      muestra: muestra,
      motivo: motivo,
      orientacion: orientacion,
      inicio: inicio,
      fin: fin,
      diferencias: diferencias
    }
  end

  @doc """
  Convierte una coincidencia en una línea del CSV de salida.

  ## Ejemplo
      Coincidencia.a_linea_csv(Coincidencia.crear("m", "ACG", "+", 0, 2, 0))
      # "m;ACG;+;0;2;0"
  """
  def a_linea_csv(c) do
    "#{c.muestra};#{c.motivo};#{c.orientacion};#{c.inicio};#{c.fin};#{c.diferencias}"
  end
end
