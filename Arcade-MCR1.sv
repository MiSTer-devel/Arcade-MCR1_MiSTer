//============================================================================
//  Arcade: MCR1
//
//  Port to MiSTer
//  Copyright (C) 2019 Sorgelig
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM (USE_FB=1 in qsf)
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;

assign VGA_F1 = 0;
assign VGA_SCALER = 0;

assign AUDIO_MIX = 0;

assign LED_USER  = rom_download;
assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

assign FB_FORCE_BLANK = '0;

wire [1:0] ar = status[17:16];
assign VIDEO_ARX = (!ar) ? (status[2] ? 8'd21 : 8'd20) : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? (status[2] ? 8'd20 : 8'd21) : 12'd0;

`include "build_id.v" 
localparam CONF_STR = {
	"A.MCR1;;",
	"H0OGH,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"H0O2,Orientation,Vert,Horz;",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"D2OD,Deinterlacer Hi-Res,Off,On;",
	"-;",
	"DIP;",
	"-;",
	"P1,Pause options;",
	"P1OP,Pause when OSD is open,On,Off;",
	"P1OQ,Dim video after 10s,On,Off;",
	"-;",
	"R0,Reset;",
	"J1,Fire A,Fire B,Fire C,Fire D,Fire E,Fire F,Start 1P, Start 2P,Coin,Pause;",
	"jn,A,B,X,Y,,,Start,Select,R,Pause;",
	"V,v",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////

wire clk_sys,clk_80M;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys), // 40M
	.outclk_1(clk_80M)  // 80M
);

///////////////////////////////////////////////////

wire [31:0] status;
wire  [1:0] buttons;
wire        forced_scandoubler;
wire        direct_video;

wire [15:0] audio_l, audio_r;


wire [31:0] joy1, joy2;
wire [31:0] joy = joy1 | joy2;
wire  [8:0] sp1, sp2;

wire signed [8:0] mouse_x;
wire signed [8:0] mouse_y;
wire        mouse_strobe;
reg   [7:0] mouse_flags;

wire [21:0] gamma_bus;

hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),

	.buttons(buttons),
	.status(status),
	.status_menumask({|status[5:3],mod_kick,direct_video}),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),
	.direct_video(direct_video),

	.ioctl_download(ioctl_download),
	.ioctl_upload(ioctl_upload),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_din(ioctl_din),
	.ioctl_index(ioctl_index),
	.ioctl_wait(ioctl_wait),

	.joystick_0(joy1),
	.joystick_1(joy2),

	.spinner_0(sp1),
	.spinner_1(sp2)

);

reg mod_kick     = 0;
reg mod_solarfox = 0;
//reg mod_dpoker   = 0;

always @(posedge clk_sys) begin
	reg [7:0] mod = 0;
	if (ioctl_wr & (ioctl_index==1)) mod <= ioctl_dout;

	mod_kick     <= ( mod == 0 );
	mod_solarfox <= ( mod == 1 );
	//mod_dpoker   <= ( mod == 2 );
end

// load the DIPS
reg [7:0] sw[8];
always @(posedge clk_sys) if (ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3]) sw[ioctl_addr[2:0]] <= ioctl_dout;


wire service = sw[1][0];

wire m_start1  = joy[10];
wire m_start2  = joy[11];
wire m_coin1   = joy[12];

wire m_right1  = joy1[0];
wire m_left1   = joy1[1];
wire m_down1   = joy1[2];
wire m_up1     = joy1[3];
wire m_fire1a  = joy1[4];
wire m_fire1b  = joy1[5];
//wire m_fire1c  = joy1[6];
//wire m_fire1d  = joy1[7];
wire m_spccw1  = joy1[30];
wire m_spcw1   = joy1[31];

wire m_right2  = joy2[0];
wire m_left2   = joy2[1];
wire m_down2   = joy2[2];
wire m_up2     = joy2[3];
wire m_fire2a  = joy2[4];
wire m_fire2b  =  joy2[5];
//wire m_fire2c  =  joy2[6];
//wire m_fire2d  =  joy2[7];
wire m_spccw2  = joy2[30];
wire m_spcw2   = joy2[31];
wire m_pause   = joy2[13] | joy2[13];

wire m_right   = m_right1 | m_right2;
wire m_left    = m_left1  | m_left2; 
wire m_down    = m_down1  | m_down2; 
wire m_up      = m_up1    | m_up2;   
wire m_fire_a  = m_fire1a | m_fire2a;
wire m_fire_b  = m_fire1b | m_fire2b;
//wire m_fire_c  = m_fire1c | m_fire2c;
//wire m_fire_d  = m_fire1d | m_fire2d;
wire m_spccw   = m_spccw1 | m_spccw2;
wire m_spcw    = m_spcw1  | m_spcw2;

// PAUSE SYSTEM
wire				pause_cpu;
wire [11:0]		rgb_out;
pause #(4,4,4,40) pause (
	.*,
	.user_button(m_pause),
	.pause_request(),
	.options(~status[26:25])
);

reg [8:0] sp;
always @(posedge clk_sys) begin
	reg [8:0] old_sp1, old_sp2;
	reg       sp_sel = 0;

	old_sp1 <= sp1;
	old_sp2 <= sp2;
	
	if(old_sp1 != sp1) sp_sel <= 0;
	if(old_sp2 != sp2) sp_sel <= 1;

	sp <= sp_sel ? sp2 : sp1;
end


reg  [7:0] input_0;
reg  [7:0] input_1;
reg  [7:0] input_2;
reg  [7:0] input_3;
reg  [7:0] input_4;

// Game specific sound board/DIP/input settings
always @(*) begin

	input_0 = 8'hff;
	input_1 = 8'hff;
	input_2 = 8'hff;
	input_3 = sw[0];
	input_4 = 8'hff;

	if (mod_kick) begin
		input_0 = ~{ service, 2'b00, m_fire_a, m_start2, m_start1, 1'b0, m_coin1 };
		input_1 = ~{ 4'b0000, spin_angle };
	end
	else if (mod_solarfox) begin
		input_0 = ~{ service, 2'b00, m_fire_a, m_fire_b, m_fire_b, 1'b0, m_coin1 };
		input_1 = ~{ m_up, m_down, m_left, m_right, m_up, m_down, m_left, m_right };
		input_2 = ~{ 7'b0000000, m_fire_a };
	end /*
	else if (mod_dpoker) begin
		input_0 = ~{ 1'b0, m_coin2, m_down1, m_up1, 3'b0, m_coin1 };//1' & not COIN2 & not GAMBLE_OUT & not GAMBLE_IN & "111" & not COIN1;
		input_1 = ~{ m_left1, m_right1, m_start1, m_fire1e, m_fire1d, m_fire1c,m_fire1b,m_fire1a }; //not STAND & not CANCEL & not DEAL & not HOLD5 & not HOLD4 & not HOLD3 & not HOLD2 & not HOLD1;
		input_2 = 8'hFF;
	end */
end

wire rom_download = ioctl_download && !ioctl_index;
wire [24:0] dl_addr = ioctl_addr[16:0];

wire [14:0] rom_addr;
wire  [7:0] rom_do;
wire [13:0] snd_addr;
wire  [7:0] snd_do;

wire        ioctl_download;
wire        ioctl_upload;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_din;
wire  [7:0] ioctl_index;
wire        ioctl_wait;

dpram #(8,16) rom
(
	.clk_a(clk_sys),
	.we_a(ioctl_wr && rom_download && !ioctl_addr[24:16]),
	.addr_a(rom_download ? ioctl_addr[15:0] : {1'b0,rom_addr}),
	.d_a(ioctl_dout),
	.q_a(rom_do),

	.clk_b(clk_sys),
	.addr_b({2'b10,snd_addr}),
	.q_b(snd_do)
); 

// reset signal generation
reg reset = 1;
reg rom_loaded = 0;
always @(posedge clk_sys) begin
	reg ioctl_downlD;
	reg [15:0] reset_count;
	ioctl_downlD <= rom_download;

	// generate a second reset signal - needed for some reason
	if (status[0] | buttons[1] | ~rom_loaded) reset_count <= 16'hffff;
	else if (reset_count != 0) reset_count <= reset_count - 1'd1;

	if (ioctl_downlD & ~rom_download) rom_loaded <= 1;
	reset <= status[0] | buttons[1] | rom_download | ~rom_loaded | (reset_count == 16'h0001);
end

mcr1 mcr1
(
	.clock_40(clk_sys),
	.reset(reset),
	.video_r(r),
	.video_g(g),
	.video_b(b),
	.video_vblank(vblank),
	.video_hblank(hblank),
	.video_hs(hs),
	.video_vs(vs),
	.video_csync(cs),
	.tv15Khz_mode(~hires),
	.separate_audio(1'b0),
	.audio_out_l(audio_l),
	.audio_out_r(audio_r),

	.input_0(input_0),
	.input_1(input_1),
	.input_2(input_2),
	.input_3(input_3),
	.input_4(input_4),

	.cpu_rom_addr(rom_addr),
	.cpu_rom_do(rom_do),
	.snd_rom_addr(snd_addr),
	.snd_rom_do(snd_do),

	.pause(pause_cpu),

	.dl_addr(dl_addr),
	.dl_wr(ioctl_wr & rom_download),
	.dl_data(ioctl_dout),
	.dl_nvram_wr(ioctl_wr & (ioctl_index=='d4)), 
	.dl_din(ioctl_din),
	.dl_nvram(ioctl_index=='d4)
);

wire hs, vs, cs;
wire hblank, vblank;
wire HSync, VSync;
wire [3:0] r,g,b;

wire no_rotate = status[2] | direct_video;
wire rotate_ccw = 0;
screen_rotate screen_rotate (.*);

wire hires = status[13] && !status[5:3];

reg  ce_pix;
always @(posedge clk_80M) begin
	reg [2:0] div;

	div <= div + 1'd1;
	ce_pix <= hires ? !div[1:0] : !div;
end

arcade_video #(512,12) arcade_video
(
	.*,
	.ce_pix(ce_pix),
	.clk_video(clk_80M),
	.RGB_in(rgb_out),
	.HBlank(hblank),
	.VBlank(vblank),
	.HSync(hs),
	.VSync(vs),

	.fx(status[5:3])
);

assign AUDIO_L = { audio_l };
assign AUDIO_R = { audio_r };
assign AUDIO_S = 0;

wire [3:0] spin_angle;
spinner #(4,8,2) spinner
(
	.clk(clk_sys),
	.reset(reset),
	.fast(m_fire_b),
	.minus(m_left | m_spccw),
	.plus(m_right | m_spcw),
	.strobe(vs),
	.spin_in(sp),
	.spin_out(spin_angle)
);

endmodule
