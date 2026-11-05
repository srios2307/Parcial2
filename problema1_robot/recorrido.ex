defmodule Recorrido do
  @moduledoc """
  Estructura con un recorrido simple que llega desde S hasta M.
  El número de movimientos no se guarda: se calcula como `length(posiciones) - 1`.
  - autor: Santiago Rios, Yulian Diaz, Santiago Godoy
  - fecha: 2026-11-02
  - licencia: GNU GPL v3
  """

  defstruct posiciones: [], energia: 0

  @doc """
  Crea un recorrido.

  ## Parámetros
    - posiciones: lista de coordenadas `{fila, columna}` en orden de visita
    - energia: energía total consumida

  ## Ejemplo
      Recorrido.crear([{1, 1}, {1, 2}], 1)
  """
  def crear(posiciones, energia) do
    %Recorrido{posiciones: posiciones, energia: energia}
  end
end
