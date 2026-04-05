# Frog Race — Juego 1v1 multijugador

## Concepto
Juego 1v1 estilo Frogger clásico con mecánicas competitivas. Dos jugadores
compiten para llevar 3 ranas cada uno al lado opuesto de la carretera.
El primero en llevar 3 ranas gana la partida.

## Plataformas objetivo
- Android, iOS, Web (navegador)

## Stack técnico
- Motor: Godot 4.6.2 (renderer Compatibility)
- Lenguaje: GDScript
- Multijugador: servidor Node.js + WebSocket puro (librería ws)
- Servidor autoritativo a 20 ticks/s
- MCP conectado: godot-mcp operando el editor en tiempo real

## Estilo visual
- 3D con cámara isométrica estilo Crossy Road
- Personajes: modelos Kenney cube-pets (assets/pets/, 24 animales)
- Vehículos: modelos Kenney car-kit (assets/vehicles/, 10 variantes)
- Troncos: cubos marrones con shader de aristas negras
- Tiles del suelo: cubos con cara superior clara y laterales oscuros
- Colores: hierba #A7DB61/#5A9A32 (alt #A2D159) — carretera #6B6B6B/#4A4A4A — agua #74DBFF/#0F7AAD
- Troncos: #C4793A
- Diferencia de altura entre zonas: hierba 0.1, carretera 0.0, agua -0.1

## Mapa
Grid 3D con estructura de filas (17 filas, 0-16):
- Filas 0-2: hierba (llegada J1)
- Filas 3-5: carretera con coches
- Fila 6: hierba central
- Filas 7-9: agua con troncos
- Fila 10: hierba central
- Filas 11-13: carretera con coches
- Filas 14-16: hierba (salida J1 / llegada J2)
- Hierba extra: 20 filas arriba (-20 a -1) y 20 abajo (17 a 36)

## Flujo del juego (una sola escena main.tscn)

### Estados (GameState enum):
1. **MENU** — Carrusel 3D de pets en el mundo real + UI overlay. Personaje en fila 0, hierba infinita. Flechas/WASD cambian pet. PLAY/Enter para empezar.
2. **SEARCHING** — Personaje salta hacia -Z cada 0.4s por hierba infinita (ensure_grass_around). "Connecting..."/"Waiting for opponent..." visible.
3. **COUNTDOWN** — Match encontrado. Mapa real generado. Personaje camina hasta su posición de inicio. 3-2-1-GO! con transición de cámara.
4. **PLAYING** — Juego normal.
5. **GAME_OVER** — Cualquier tecla vuelve al menú.

### Transición SEARCHING → COUNTDOWN:
- Match llega via pending_match (se difiere hasta que termine el salto actual)
- Se genera el mapa real (coexiste con hierba infinita)
- Personaje se teleporta a fila START_ROW_P1+3 (hierba extra del mapa)
- Cámara se guarda posición antes del teleport y se restaura después
- Personaje camina hacia su posición de inicio
- Al llegar: 3-2-1 con transición de cámara al midpoint

## Estado actual — TODO FUNCIONAL
- Transición menú → búsqueda → match → countdown → juego fluida
- Obstáculos solo se renderizan en filas válidas (VALID_ROWS filter)
- Ticks del servidor solo se procesan en COUNTDOWN (step >= 0) y PLAYING
- Cámara transiciona suavemente al encontrar match (transition_to_both)
- Ambos jugadores dan 5 saltos exactos antes de llegar a su posición
- P2 funciona correctamente con cámara rotada

## Gameplay
- J1 empieza abajo (fila 15), llega arriba (filas 0-2)
- J2 empieza arriba (fila 1), llega abajo (filas 14-16)
- J2 ve el mapa rotado 180° (camera.flip_for_player2())
- Controles de J2 invertidos automáticamente
- 3 ranas para ganar
- Animación de salto con squeeze (Tween, 0.15s, arco parabólico)
- Personaje gira hacia la dirección de movimiento (suave durante squeeze)

## Controles
- PC: Flechas / WASD
- Móvil: pendiente (tap/swipe)
- ESC: cancelar búsqueda

## Obstáculos
- Servidor autoritativo genera y mueve obstáculos a 20 ticks/s
- Cliente recibe posiciones via tick y las interpola con lerp
- Anti-overlap: velocidad limitada para que nunca se alcancen
- Máximo 4 por fila, gap mínimo 2.5
- Modo offline: generación local con RNG

## Arquitectura multijugador
- Servidor: server/index.js (Node.js + ws, puerto 3000)
- Game loop a 20 ticks/s con setInterval
- Matchmaking automático (primero espera, segundo se empareja)
- Servidor envía: match_found (con opponent pet), tick (obstáculos), score_update, game_over
- Cliente envía: find_match (con pet), player_move, player_died, player_scored
- Intercambio de pets seleccionados entre jugadores

## Cámara (camera.gd)
- Dos modos: follow_single (menú/búsqueda) y follow_both (partida)
- transition_to_both(duration): tween de size + transition_progress
- _process_transition: interpola entre jugador y midpoint según progress
- flip_for_player2(): rotación instantánea PI en Y

## Estructura de archivos
- main.tscn: escena única (Node3D con Camera, Sun, Map, Obstacles, Players, WorldEnvironment)
- scripts/game.gd: lógica principal, estados, carrusel, input, red, victoria
- scripts/map.gd: genera tiles, hierba infinita, mapa real
- scripts/obstacle_manager.gd: renderiza obstáculos del servidor con interpolación
- scripts/camera.gd: cámara dinámica con transición
- scripts/network.gd: cliente WebSocket
- scripts/world_env.gd: iluminación ambiental
- shaders/voxel_outline.gdshader: aristas negras en cubos
- server/index.js: servidor WebSocket autoritativo
- assets/vehicles/: modelos GLB Kenney car-kit
- assets/pets/: modelos GLB Kenney cube-pets

## IMPORTANTE: Godot no recarga scripts editados externamente
- Hay que reiniciar Godot cada vez que se editan scripts desde fuera del editor
- O usar detach_script + attach_script via MCP para forzar recarga

## Convenciones
- Todo en inglés en el código
- Comentarios en español
- Movimiento siempre por casillas del grid
- Resolución móvil: 390x844 (iPhone), stretch mode canvas_items
