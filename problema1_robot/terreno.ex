defmodule Terreno do
  @moduledoc """
  Estructura con un tipo de terreno leído de terrenos.csv.
  - autor: Grupo Parcial 2, Programación III G2D
  - fecha: 2026-11-02
  - licencia: GNU GPL v3
  """

  defstruct simbolo: "", nombre: "", transitable: false, costo: 0

  @doc """
  Crea un terreno.

  ## Parámetros
    - simbolo: símbolo que lo representa en edificio.txt
    - nombre: nombre del terreno
    - transitable: true si el robot puede entrar
    - costo: energía que consume entrar a una casilla de este terreno

  ## Ejemplo
      Terreno.crear("L", "lodo", true, 3)
  """
  def crear(simbolo, nombre, transitable, costo) do
    %Terreno{simbolo: simbolo, nombre: nombre, transitable: transitable, costo: costo}
  end
end
