# FPGA Breakout Game

A classic Breakout game implementation on FPGA, developed as a group project for Fall 2024 FPGA Lab.

## Team Members

- Belle Angkanapiwat
- Eric Ji
- Xingyu (Brian) Zhou

## Project Description

This is an FPGA implementation of the classic Breakout game featuring a paddle, ball, and destructible bricks with special power-ups.

## Features

- Classic breakout gameplay mechanics
- Game status text display
- Special brick types:
  - Red bricks: Increase ball speed when destroyed
  - Cyan bricks: Decrease ball speed when destroyed
  - Random position block: Must be destroyed last
- Cheat mode: Hold both buttons to make paddle automatically track the ball

## Development Timeline

### December 6, 2024

- Fixed implementation timing violations
  - Divided `clkfx`  by 8 to `clkfx_slow`
  - Specified synthesis optimizations through `synth_settings.tcl`

### December 3, 2024

- Added special "final block" with random positioning
- Implemented cheat mode functionality

### December 2, 2024

- Added special brick types with speed modification effects
- Completed basic game implementation including:
  - Paddle movement
  - Ball physics
  - Brick destruction
  - Game text display
