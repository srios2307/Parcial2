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
