library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

Library UNISIM;
use UNISIM.vcomponents.all;

entity root is
    port ( 
		-- clock
	 	clk_in : in std_logic; 

		led1 : out std_logic;
		led2 : out std_logic;
		led3 : out std_logic;

		z80_rst : in std_logic;
		  
		VGA_HSYNC_OUT : out  STD_LOGIC;
		VGA_VSYNC_OUT : out  STD_LOGIC;
		VGA_R_OUT : out  STD_LOGIC;
		VGA_G_OUT : out  STD_LOGIC;
		VGA_B_OUT : out  STD_LOGIC;
		
		PLAYER_IN : in STD_LOGIC;
		
		PS2_CLK : in STD_LOGIC;
		PS2_DATA : in STD_LOGIC
	);
end root;

--WARNING:Xst:1426 - The value init of the FF/Latch remap_rom hinder the constant cleaning in the block root.
--   You should achieve better results by setting this init to 0.
architecture rtl of root is

	COMPONENT clockgen
	PORT(
		CLKIN_IN : IN std_logic;          
		CLKFX_OUT : OUT std_logic;
		CLKIN_IBUFG_OUT : OUT std_logic;
		CLK0_OUT : OUT std_logic
		);
	END COMPONENT;
	
COMPONENT cobra_rom2
  PORT (
    clka : IN STD_LOGIC;
    addra : IN STD_LOGIC_VECTOR(10 DOWNTO 0);
    douta : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
  );
END COMPONENT;

component T80a is
	generic(
		Mode : integer := 0	-- 0 => Z80, 1 => Fast Z80, 2 => 8080, 3 => GB
	);
	port(
		RESET_n		: in std_logic;
		CLK_n		: in std_logic;
		WAIT_n		: in std_logic;
		INT_n		: in std_logic;
		NMI_n		: in std_logic;
		BUSRQ_n		: in std_logic;
		M1_n		: out std_logic;
		MREQ_n		: out std_logic;
		IORQ_n		: out std_logic;
		RD_n		: out std_logic;
		WR_n		: out std_logic;
		RFSH_n		: out std_logic;
		HALT_n		: out std_logic;
		BUSAK_n		: out std_logic;
		A			: out std_logic_vector(15 downto 0);
		D			: inout std_logic_vector(7 downto 0)
	);
end component;

component RAM_16KB is
	port (
		clka	: IN std_logic;
		wea: IN std_logic_VECTOR(0 downto 0);
		addra	: IN std_logic_VECTOR(13 downto 0);
		dina	: IN std_logic_VECTOR(7 downto 0);
		douta	: OUT std_logic_VECTOR(7 downto 0)
	);
end component;

component video_generator is
    Port ( CLK_IN : in STD_LOGIC;
			  HSYNC_OUT : out  STD_LOGIC;
           VSYNC_OUT : out  STD_LOGIC;
           RGB_OUT : out  STD_LOGIC_VECTOR (2 downto 0);
			  VIDEORAM_ADDR : OUT std_logic_VECTOR(9 downto 0);
	        VIDEORAM_DATA : IN std_logic_VECTOR(7 downto 0)
			);
end component;

component videoram
	port (
	clka: IN std_logic;
	wea: IN std_logic_VECTOR(0 downto 0);
	addra: IN std_logic_VECTOR(9 downto 0);
	dina: IN std_logic_VECTOR(7 downto 0);
	douta: OUT std_logic_VECTOR(7 downto 0);
	clkb: IN std_logic;
	web: IN std_logic_VECTOR(0 downto 0);
	addrb: IN std_logic_VECTOR(9 downto 0);
	dinb: IN std_logic_VECTOR(7 downto 0);
	doutb: OUT std_logic_VECTOR(7 downto 0));
end component;

component cobra_kbd
	Port (
		clk : in std_logic;
		key_code : in std_logic_vector(7 downto 0);
		key_set : in std_logic;
		key_clr : in std_logic;
		kbd_vector : out std_logic_vector(39 downto 0)
	);
end component;

component ps2_keyboard is
	Port(
		CLK : in std_logic;
		
		PS2_CLK : in std_logic;
		PS2_DATA : in std_logic;
		
		KEY_SCANCODE : out std_logic_vector(7 downto 0);
		KEY_MAKE : out std_logic;
		KEY_BREAK : out std_logic
	);
end component ps2_keyboard;

component multi74123 is
    Port ( inh_pos : in  STD_LOGIC;
           q_neg : out  STD_LOGIC;
           clk : in  STD_LOGIC);
end component;


signal z80_clk : std_logic;
signal z80_wait : std_logic := '1';
signal z80_int : std_logic := '1';
signal z80_nmi : std_logic := '1';
signal z80_busreq : std_logic := '1';
signal z80_m1 : std_logic;
signal z80_mreq : std_logic;
signal z80_iorq : std_logic;
signal z80_rd : std_logic;
signal z80_wr : std_logic;
signal z80_rfsh : std_logic;
signal z80_halt : std_logic;
signal z80_busack : std_logic;
signal z80_a : std_logic_vector(15 downto 0);
signal z80_d : std_logic_vector(7 downto 0) := (others => '0');

signal rom_ce : std_logic;
signal rom_data : std_logic_vector(7 downto 0);

signal sram_data_read : std_logic_vector(7 downto 0);
signal sram_data_write : std_logic_vector(7 downto 0);
signal sram_we : std_logic_vector(0 downto 0);
signal sram_a : std_logic_vector(13 downto 0);
		
signal clkcnt : std_logic_vector(25 downto 0) := (others => '0');

signal port_write_val : std_logic_vector(7 downto 0);

signal no_rom_remap : std_logic := '0';

signal vga_rgb: std_logic_vector(2 downto 0);
signal videoram_gen_addr : std_logic_vector(9 downto 0);
signal videoram_gen_data : std_logic_vector(7 downto 0);
signal video_addr : std_logic_VECTOR(9 downto 0);
signal video_data_in : std_logic_VECTOR(7 downto 0);
signal video_data_out : std_logic_VECTOR(7 downto 0);
signal video_we : std_logic_vector(0 downto 0);

signal kbd_vector : std_logic_vector(39 downto 0);

signal key_scancode : std_logic_vector(7 downto 0);
signal key_make : std_logic;
signal key_break : std_logic;

signal clk : std_logic;
signal clk26mhz : std_logic;

signal inh_in_123 : std_logic;
signal pulse_out_123 : std_logic;

begin

cpu : T80a
	generic map(
		Mode => 0 )
	port map(
		RESET_n => not z80_rst,
		CLK_n	=> z80_clk,
		WAIT_n => z80_wait,
		INT_n	=> z80_int,
		NMI_n	=> z80_nmi,
		BUSRQ_n => z80_busreq,
		M1_n => z80_m1,
		MREQ_n => z80_mreq,
		IORQ_n => z80_iorq,
		RD_n => z80_rd,
		WR_n => z80_wr,
		RFSH_n => z80_rfsh,
		HALT_n => z80_halt,
		BUSAK_n => z80_busack,
		A => z80_a,
		D => z80_d );

rom : cobra_rom2
  PORT MAP (
    clka => clk,
    addra => z80_a(10 downto 0),
    douta => rom_data
  );
  
inst_ram : RAM_16KB
	port map (
		clka  => z80_clk,
		wea   => sram_we,
		addra => sram_a,
		dina  => sram_data_write, --ram input
		douta => sram_data_read  --ram output
	);

inst_cobra_kbd : cobra_kbd
	port map (
		clk => clk,
		key_code => key_scancode,
		key_set => key_make,
		key_clr => key_break,
		kbd_vector => kbd_vector
	);
	

inst_ps2_keyboard : ps2_keyboard
	Port map (
		CLK => clk,
		PS2_CLK => PS2_CLK,
		PS2_DATA => PS2_DATA,
		
		KEY_SCANCODE => key_scancode,
		KEY_MAKE => key_make,
		KEY_BREAK => key_break
	);
	
	sram_a <= z80_a(13 downto 0);

	rom_ce <= '0' when (z80_mreq = '0') and (z80_a(15 downto 12) = X"C") else
				 '0' when (z80_mreq = '0') and (z80_a(15 downto 12) = X"0") and (no_rom_remap = '0') else
			    '1';

	sram_we(0) <= '1' when (z80_wr='0') and (z80_a(15 downto 12) <= X"B") and (z80_mreq='0')
			else '0';

	video_we(0) <= '1' when (z80_wr='0') and (z80_a(15 downto 12) = X"F") and (z80_mreq='0')
			else '0';
			
	process(clk, z80_rst)
	begin
		if (z80_rst = '1') then
			no_rom_remap <= '0';
		elsif rising_edge(clk) then
			if z80_rd = '0' then
				if z80_mreq = '0' then
					if (z80_a(15 downto 12) = X"C") then
						z80_d <= rom_data;			
					elsif (z80_a(15 downto 12) = X"0") and (no_rom_remap = '0') then
						z80_d <= rom_data;			
					elsif (z80_a(15 downto 12) = X"F") then
						z80_d <= video_data_out;			
					else
						z80_d <= sram_data_read;
					end if;										
				else -- port read
					   if (z80_a(15 downto 8) = X"FE") then
						z80_d <= inh_in_123&pulse_out_123&'1' & kbd_vector(4 downto 0);
					elsif (z80_a(15 downto 8) = X"FD") then
						z80_d <= inh_in_123&pulse_out_123&'1' & kbd_vector(9 downto 5);
					elsif (z80_a(15 downto 8) = X"FB") then
						z80_d <= inh_in_123&pulse_out_123&'1' & kbd_vector(14 downto 10);
					elsif (z80_a(15 downto 8) = X"F7") then
						z80_d <= inh_in_123&pulse_out_123&'1' & kbd_vector(19 downto 15);
					elsif (z80_a(15 downto 8) = X"EF") then
						z80_d <= inh_in_123&pulse_out_123&'1' & kbd_vector(24 downto 20);
					elsif (z80_a(15 downto 8) = X"DF") then
						z80_d <= inh_in_123&pulse_out_123&'1' & kbd_vector(29 downto 25);
					elsif (z80_a(15 downto 8) = X"BF") then
						z80_d <= inh_in_123&pulse_out_123&'1' & kbd_vector(34 downto 30);
					elsif (z80_a(15 downto 8) = X"7F") then
						z80_d <= inh_in_123&pulse_out_123&'1' & kbd_vector(39 downto 35);
					else 
						z80_d <= inh_in_123&pulse_out_123&'1' & (kbd_vector(4 downto 0) and kbd_vector(9 downto 5) and kbd_vector(14 downto 10) and kbd_vector(19 downto 15) and 
												kbd_vector(24 downto 20) and kbd_vector(29 downto 25) and kbd_vector(34 downto 30) and kbd_vector(39 downto 35));
					end if;
				end if;
			elsif z80_wr = '0' then
				if z80_mreq = '0' then
					if (z80_a(15 downto 12) <= X"B") then --z80_a(15) = '0' then
						sram_data_write <= z80_d;
					else --if (z80_a(15 downto 12) = X"F")
						video_data_in <= z80_d;
					end if;										
				else --port write
					port_write_val <= z80_d;
					if (z80_a(7 downto 0) = X"1F") then 
						no_rom_remap <= '1';
					end if;
				end if;
			else 				
				z80_d <= "ZZZZZZZZ";
			end if;	
		end if;
		
	end process;


VGA_R_OUT <= vga_rgb(2);
VGA_G_OUT <= vga_rgb(1);
VGA_B_OUT <= vga_rgb(0);

video_addr <= z80_a(9 downto 0);

led2 <= key_make;

inst_video_generator : video_generator
	port map (
		CLK_IN => clk,
		HSYNC_OUT => VGA_HSYNC_OUT,
		VSYNC_OUT => VGA_VSYNC_OUT,
		RGB_OUT => vga_rgb,
		VIDEORAM_ADDR => videoram_gen_addr,
		VIDEORAM_DATA => videoram_gen_data
	);

inst_videoram : videoram
	port map (
		clka => clk,
		wea => video_we,
		addra => video_addr,
		dina => video_data_in,
		douta => video_data_out, 
		clkb => clk,
		web => (others=>'0'),
		addrb  => videoram_gen_addr,
		dinb  => (others=>'0'),
		doutb => videoram_gen_data
   );


-- CLOCK
	Inst_clockgen: clockgen PORT MAP(
		CLKIN_IN => clk_in,
		CLKFX_OUT => clk26mhz,
		CLKIN_IBUFG_OUT => clk,
		CLK0_OUT => open
	);	

	process (clk26mhz) is
	begin
		if rising_edge(clk26mhz) then
			clkcnt <= clkcnt + 1;
		end if;
	end process;

	z80_clk <= clkcnt(2); --z80 clock is 3.25MHz
	led1 <= z80_clk; 


-- PLAYER INPUT
	inh_in_123 <= PLAYER_IN;
	led3 <= not pulse_out_123;

	inst_multi74123 : multi74123
		port map (
			inh_pos => inh_in_123,
			q_neg => pulse_out_123,
			clk => clk
		);
		
end rtl;
