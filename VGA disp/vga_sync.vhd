library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_sync is
    port(
        clk, reset: in std_logic;
        hsync, vsync: out std_logic;
        video_on: out std_logic;
        p_tick: out std_logic;
        pixel_x, pixel_y: out std_logic_vector(9 downto 0);
        comp_sync: out std_logic
    );
end vga_sync;

architecture arch of vga_sync is
    -- VGA 640-by-480 sync parameters
    constant HD: integer := 640;  -- horizontal display area
    constant HF: integer := 16;   -- h. front porch
    constant HB: integer := 48;   -- h. back porch
    constant HR: integer := 96;   -- h. retrace
    constant VD: integer := 480;  -- vertical display area
    constant VF: integer := 11;   -- v. front porch
    constant VB: integer := 31;   -- v. back porch
    constant VR: integer := 2;    -- v. retrace
    
    -- clock divider
	signal clk_div_reg, clk_div_next: unsigned(1 downto 0);    
    -- sync counters
    signal v_count_reg, v_count_next: unsigned(9 downto 0);
    signal h_count_reg, h_count_next: unsigned(9 downto 0);
    
    -- output buffer
    signal v_sync_reg, h_sync_reg: std_logic;
    signal v_sync_next, h_sync_next: std_logic;
    signal h_sync_delay1_reg, h_sync_delay2_reg: std_logic;
	signal h_sync_delay1_next, h_sync_delay2_next: std_logic;
	signal v_sync_delay1_reg, v_sync_delay2_reg: std_logic;
	signal v_sync_delay1_next, v_sync_delay2_next: std_logic;
    
    -- status signal
    signal h_end, v_end, pixel_tick: std_logic;

begin
    -- registers
    process(clk, reset)
    begin
        if reset = '1' then
            clk_div_reg <= "00";
            v_count_reg <= (others => '0');
            h_count_reg <= (others => '0');
            v_sync_reg <= '0';
            h_sync_reg <= '0';
            v_sync_delay1_reg <= '0';
			h_sync_delay1_reg <= '0';
			v_sync_delay2_reg <= '0';
			h_sync_delay2_reg <= '0';
        elsif (clk'event and clk = '1') then
            clk_div_reg <= clk_div_next;
            v_count_reg <= v_count_next;
            h_count_reg <= h_count_next;
            v_sync_reg <= v_sync_next;
            h_sync_reg <= h_sync_next;
            v_sync_delay1_reg <= v_sync_delay1_next;
			h_sync_delay1_reg <= h_sync_delay1_next;
			v_sync_delay2_reg <= v_sync_delay2_next;
			h_sync_delay2_reg <= h_sync_delay2_next;
        end if;
    end process;
  
  -- Pipeline registers
	v_sync_delay1_next <= v_sync_reg;
	h_sync_delay1_next <= h_sync_reg;
	v_sync_delay2_next <= v_sync_delay1_reg;
	h_sync_delay2_next <= h_sync_delay1_reg;
  
-- Generate a 25 MHz enable tick from 100 MHz clock
	clk_div_next <= clk_div_reg + 1;
	pixel_tick <= '1' when clk_div_reg = to_unsigned(3,2) else '0';
    
    -- end of horizontal counter (799)
    h_end <= '1' when h_count_reg = (HD + HF + HB + HR - 1) else '0';
    
    -- end of vertical counter (524)
    v_end <= '1' when v_count_reg = (VD + VF + VB + VR - 1) else '0';
    
    -- horizontal counter
    process(h_count_reg, h_end, pixel_tick)
    begin
        if pixel_tick = '1' then
            if h_end = '1' then
                h_count_next <= (others => '0');
            else
                h_count_next <= h_count_reg + 1;
            end if;
        else
            h_count_next <= h_count_reg;
        end if;
    end process;
    
    -- vertical counter
    process(v_count_reg, h_end, v_end, pixel_tick)
    begin
        if pixel_tick = '1' and h_end = '1' then
            if v_end = '1' then
                v_count_next <= (others => '0');
            else
                v_count_next <= v_count_reg + 1;
            end if;
        else
            v_count_next <= v_count_reg;
        end if;
    end process;
    
-- horz and vert sync, buffered to avoid glitch
	h_sync_next <= '0' when (h_count_reg >= (HD+HF)) and (h_count_reg <= (HD+HF+HR-1)) else '1';
	v_sync_next <= '0' when (v_count_reg >= (VD+VF)) and (v_count_reg <= (VD+VF+VR-1)) else '1';
    
    -- video on/off
    video_on <= '1' when (h_count_reg < HD) and (v_count_reg < VD) else '0';
    
    -- output signals
	hsync <= h_sync_delay2_reg;
	vsync <= v_sync_delay2_reg;
    pixel_x <= std_logic_vector(h_count_reg);
    pixel_y <= std_logic_vector(v_count_reg);
    p_tick <= pixel_tick;
    
    -- Composite sync for some VGA monitors
    comp_sync <= h_sync_reg xor v_sync_reg;
end arch;