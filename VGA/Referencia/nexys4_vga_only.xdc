## ======================================================================
## Nexys4 rev B — XDC mínimo para el demo VGA 640x480@60
## Mapea a puertos del top: top_vga_nexys4.sv
## clk_100mhz, btn_reset_n, vga_r/g/b[3:0], vga_hs, vga_vs
## ======================================================================

## -------------------------
## Reloj de 100 MHz del board
## Bank = 35, Pin = E3, Sch = CLK100MHZ
## -------------------------
set_property PACKAGE_PIN E3               [get_ports clk_100mhz]
set_property IOSTANDARD LVCMOS33         [get_ports clk_100mhz]
create_clock -name sys_clk_pin -period 10.000 -waveform {0 5} [get_ports clk_100mhz]

## -------------------------
## Botón de reset (activo en 0)
## Sugerencia: usa BTNC (Sch = BTNC) para reset; Pin E16 en tu XDC
## -------------------------
set_property PACKAGE_PIN E16              [get_ports btn_reset_n]
set_property IOSTANDARD LVCMOS33         [get_ports btn_reset_n]
set_property PULLUP true                 [get_ports btn_reset_n]

## -------------------------
## Conector VGA (RGB 4-4-4 + HS/VS)
## NOTA: HS/VS son activos en 0 (polaridad negativa) -> se maneja en RTL
## Pines tomados de tu XDC (sección “VGA Connector”)
## -------------------------

## RED (R[3:0])
## Bank = 35, Sch = VGA_R0..R3
set_property PACKAGE_PIN A3               [get_ports {vga_r[0]}]
set_property PACKAGE_PIN B4               [get_ports {vga_r[1]}]
set_property PACKAGE_PIN C5               [get_ports {vga_r[2]}]
set_property PACKAGE_PIN A4               [get_ports {vga_r[3]}]

## GREEN (G[3:0])
## Bank = 35, Sch = VGA_G0..G3
set_property PACKAGE_PIN C6               [get_ports {vga_g[0]}]
set_property PACKAGE_PIN A5               [get_ports {vga_g[1]}]
set_property PACKAGE_PIN B6               [get_ports {vga_g[2]}]
set_property PACKAGE_PIN A6               [get_ports {vga_g[3]}]

## BLUE (B[3:0])
## Bank = 35, Sch = VGA_B0..B3
set_property PACKAGE_PIN B7               [get_ports {vga_b[0]}]
set_property PACKAGE_PIN C7               [get_ports {vga_b[1]}]
set_property PACKAGE_PIN D7               [get_ports {vga_b[2]}]
set_property PACKAGE_PIN D8               [get_ports {vga_b[3]}]

## HSYNC / VSYNC (activos en 0)
## HS: Bank = 15, Pin = B11, Sch = VGA_HS
## VS: Bank = 15, Pin = B12, Sch = VGA_VS
set_property PACKAGE_PIN B11              [get_ports vga_hs]
set_property IOSTANDARD LVCMOS33         [get_ports vga_hs]
set_property PACKAGE_PIN B12              [get_ports vga_vs]
set_property IOSTANDARD LVCMOS33         [get_ports vga_vs]

## IOSTANDARD RGB (aplica a todos los bits)
set_property IOSTANDARD LVCMOS33         [get_ports {vga_r[*]}]
set_property IOSTANDARD LVCMOS33         [get_ports {vga_g[*]}]
set_property IOSTANDARD LVCMOS33         [get_ports {vga_b[*]}]

## ======================================================================
## TODO (opcional): Si vas a usar switches/LEDs/7-seg, descomenta y
## renombra a los puertos reales de tu top. Por ahora lo dejamos fuera.
## ======================================================================

# ## Switches (ejemplo, si los usas)
# set_property PACKAGE_PIN U9  [get_ports {sw[0]}]  ; set_property IOSTANDARD LVCMOS33 [get_ports {sw[0]}]
# set_property PACKAGE_PIN U8  [get_ports {sw[1]}]  ; set_property IOSTANDARD LVCMOS33 [get_ports {sw[1]}]
# ...

# ## LEDs (ejemplo)
# set_property PACKAGE_PIN T8  [get_ports {led[0]}] ; set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]
# set_property PACKAGE_PIN V9  [get_ports {led[1]}] ; set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]
# ...

# ## 7-segment (ejemplo)
# set_property PACKAGE_PIN L3  [get_ports {seg[0]}] ; set_property IOSTANDARD LVCMOS33 [get_ports {seg[0]}]
# set_property PACKAGE_PIN N6  [get_ports {an[0]}]  ; set_property IOSTANDARD LVCMOS33 [get_ports {an[0]}]
# ...

## ======================================================================
## Fin del XDC mínimo para VGA
## ======================================================================
