# Alien-Boom 👾

A space shooter game implemented in VHDL and designed to run on an FPGA board. The game renders to a VGA monitor at 640×480 resolution and uses the board's 7-segment displays to track the player's score and remaining lives.

---

## Gameplay

Five alien sprites bounce around the screen at all times, moving in different directions. The player controls a ship that can move freely across the screen and fires projectiles upward to destroy the aliens. The goal is to shoot all 5 aliens before any of them collide with the player's ship.

- **Win condition:** Destroy all 5 aliens (score reaches 5) — a **"YOU WIN!"** message appears on screen.
- **Lose condition:** Lose all 3 lives from alien collisions — a **"GAME OVER!"** message appears on screen.

---

## Controls

The game uses 5 push buttons on the FPGA board:

| Button | Action |
|--------|--------|
| `btn[0]` | Move ship **up** |
| `btn[1]` | Move ship **down** |
| `btn[2]` | Move ship **right** |
| `btn[3]` | Move ship **left** |
| `btn[4]` | **Fire** projectile |

A reset button restarts the game with 3 lives and score set to 0.

---

## Hardware Requirements

- FPGA board with a **100 MHz** system clock
- **VGA connector** for display output (640×480 @ 60 Hz)
- **7-segment display** (at least 4 digits with active-low anodes)
- **5 push buttons** for player input

The design was developed targeting a board in the Xilinx/AMD ecosystem (e.g., Basys3 or Nexys series), but the RTL is board-agnostic.

---

## Project Structure

```
Alien-Boom/
├── VGA disp/
│   ├── pong_top_st.vhd   # Top-level module — wires all subsystems together
│   ├── ast_graph.vhd     # Core game logic, sprites, collision, and rendering
│   └── vga_sync.vhd      # VGA sync signal generator (640×480 @ 60 Hz)
└── 7-seg-disp/
    ├── ast_7seg.vhd       # Score counter and 7-segment display multiplexer
    ├── ast_hex.vhd        # Hex-to-7-segment decoder (0–F)
    └── ast_genpuls.vhd    # Generic configurable pulse generator
```

---

## Module Overview

### `pong_top_st` — Top Level (`pong_top_st.vhd`)

The top-level entity that instantiates and connects all subsystems. It handles the lives counter (starts at 3, decrements on alien collision), drives the VGA outputs, and pipes the RGB pixel data through a register to prevent glitches.

**Ports:**

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | in | 1 | 100 MHz system clock |
| `reset` | in | 1 | Active-high synchronous reset |
| `btn` | in | 5 | Player input buttons |
| `hsync`, `vsync` | out | 1 | VGA sync signals |
| `rgb_top` | out | 6 | 6-bit RGB color output (2 bits per channel) |
| `segs` | out | 7 | 7-segment segment data |
| `AN` | out | 8 | 7-segment digit enables (active-low) |

---

### `vga_sync` — VGA Timing Generator (`vga_sync.vhd`)

Generates standard 640×480 @ 60 Hz VGA timing signals from a 100 MHz input clock. The 100 MHz clock is divided by 4 to produce a 25 MHz pixel clock. Horizontal and vertical sync pulses are pipelined through two registers to prevent output glitches. Also outputs a composite sync signal for compatibility with monitors that require it.

**Timing parameters:**

| Parameter | Value |
|-----------|-------|
| Display area | 640 × 480 pixels |
| Pixel clock | 25 MHz (÷4 from 100 MHz) |
| Refresh rate | 60 Hz |
| H. front/back porch | 16 / 48 pixels |
| H. retrace | 96 pixels |
| V. front/back porch | 11 / 31 lines |
| V. retrace | 2 lines |

---

### `pong_graph_st` — Game Engine (`ast_graph.vhd`)

The largest and most complex module. It handles all game logic, sprite rendering, and collision detection, pixel by pixel at 60 Hz.

**Sprites:** All sprites are defined as binary ROM bitmaps hardcoded directly in the VHDL:

- **Alien sprites (5×):** 32×32 pixel bitmap representing an alien character. Each alien is rendered in a distinct color (red, blue, light blue, yellow, purple).
- **Player ship:** 32×32 pixel bitmap of a spaceship, rendered in orange-red.
- **Projectile:** 8×8 circular bullet bitmap, rendered in yellow-orange.

**Game logic highlights:**

- Each of the 5 aliens has independent position registers and velocity registers, initialized at different X/Y positions with different starting directions.
- Ball positions and velocities are updated once per frame (at the 60 Hz refresh tick, detected at pixel coordinate (0, 481)).
- Aliens bounce off all four screen edges. When hit by the player's projectile, they are marked inactive (`ball_active` flag) and disappear.
- The player's projectile launches from the center-top of the ship when `btn[4]` is pressed, travels straight up at 2 pixels/frame, and resets when it reaches the top of the screen.
- A **score update pulse** is generated on the rising edge of any alien-hit event, sent to the 7-segment counter.
- A **lives decrement pulse** is generated on the rising edge of an alien-ship collision event, sent to the top-level lives counter.
- All motion and collision logic freezes when `game_over = '1'` or the win condition is met.
- A **starfield background** is rendered by drawing white pixels at positions where both `pixel_x[5:0] = 0` and `pixel_y[4:0] = 0`, creating a sparse grid of stars.
- **"YOU WIN!"** and **"GAME OVER!"** messages are stored as 96×12 pixel bitmaps and overlaid at the center of the screen when triggered.

**Rendering priority (highest to lowest):**
1. Text overlay (win/game over message)
2. Player ship
3. Alien sprites (in order: 0 → 4)
4. Player projectile
5. Starfield / black background

---

### `counter_7seg` — Score & Lives Display (`ast_7seg.vhd`)

Manages the score counter and drives up to 4 digits on the 7-segment display using time-division multiplexing.

- **Digit 0 (AN[0]):** Displays the current number of lives (passed in from the top level).
- **Digit 1 (AN[1]):** Blank (unused).
- **Digit 2 (AN[2]):** Lower nibble of the score (ones digit).
- **Digit 3 (AN[3]):** Upper nibble of the score (tens digit).

The digit refresh counter cycles through all 4 digits at a rate derived from a 100,000-cycle counter (1 ms per digit → ~1 kHz refresh rate), fast enough to appear steady to the eye. The segment outputs are inverted before being sent out to match active-low display hardware.

---

### `hex2sevenseg` — Hex Decoder (`ast_hex.vhd`)

A simple combinational lookup table that maps a 4-bit hexadecimal input (0–F) to the corresponding 7-segment encoding. Segment order is `abcdefg` with segment `a` as the MSB. Used as a sub-component of `counter_7seg`.

---

### `my_genpulse` — Pulse Generator (`ast_genpuls.vhd`)

A generic, reusable counter-based pulse generator. The pulse period is set via the `COUNT` generic parameter, which defaults to 50,000,000 cycles — producing a 0.5-second pulse on a 100 MHz clock. It includes an enable input (`E`) and outputs both the current count value (`Q`) and a terminal-count pulse (`z`).

---

## Signal Flow

```
clk, reset, btn
      │
      ▼
 pong_top_st
 ┌────────────────────────────────────────────┐
 │                                            │
 │  vga_sync ──► pixel_x, pixel_y, video_on  │
 │      │                                     │
 │      └──────────────────────────────────►  │
 │  pong_graph_st ◄── pixel coords            │
 │      │         ◄── btn                     │
 │      │         ──► graph_rgb               │
 │      │         ──► score_update            │
 │      │         ──► lives_decrement         │
 │      │                                     │
 │  counter_7seg ◄── score_update             │
 │      │        ◄── lives_value              │
 │      │        ──► segs, AN                 │
 │      │        ──► score_value (feedback)   │
 └────────────────────────────────────────────┘
      │
      ▼
 hsync, vsync, rgb_top, segs, AN
```

---

## Building & Synthesizing

1. Add all `.vhd` files to your FPGA project (Vivado, Quartus, etc.).
2. Set `pong_top_st` as the top-level entity.
3. Create a constraints file (`.xdc` or `.qsf`) to map ports to your board's physical pins for the VGA connector, buttons, 7-segment display, and clock.
4. Run synthesis, implementation, and generate the bitstream.
5. Program the FPGA and connect a VGA monitor.

> **Clock note:** The design expects a **100 MHz** input clock. If your board uses a different frequency, adjust the clock divider in `vga_sync.vhd` and the refresh counter constant in `ast_7seg.vhd` accordingly.
>
## Demo

### Board setup
Basys3 FPGA board running Alien-Boom, with the 7-segment display showing score/lives.

![Basys3 board showing score and lives](images/board-score-lives.jpg)

### Gameplay screen
Aliens rendered on the VGA display while the player ship is positioned at the bottom-left.

![Gameplay with aliens on screen](images/gameplay-aliens.jpg)

### Win screen
The game displays a victory message after all 5 aliens are destroyed.

![YOU WIN screen](images/you-win.jpg)
![Basys3 board during another game state](images/board-alt-state.jpg)
