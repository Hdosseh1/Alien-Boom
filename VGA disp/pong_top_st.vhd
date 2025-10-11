library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
entity pong_top_st is
    port(
        clk, reset       : in  std_logic;
        btn              : in  std_logic_vector(4 downto 0);
        hsync, vsync     : out std_logic;
        rgb_top          : out std_logic_vector(5 downto 0);
        vga_pixel_tick   : out std_logic;
        blank, comp_sync : out std_logic;
        segs             : out std_logic_vector(6 downto 0);
        AN               : out std_logic_vector(7 downto 0)
    );
end entity;

architecture rtl of pong_top_st is
    -- VGA timing signals
    signal video_on      : std_logic;
    signal p_tick        : std_logic;
    signal pixel_x, pixel_y : std_logic_vector(9 downto 0);

    -- Graph signals
    signal rgb_next      : std_logic_vector(5 downto 0);
    signal rgb_reg       : std_logic_vector(5 downto 0);
    signal score_update  : std_logic;
    signal score_value   : std_logic_vector(15 downto 0);
    signal lives_value   : std_logic_vector(3 downto 0);
    signal lives_cnt   : unsigned(3 downto 0);  -- 2 bits, counts 3,2,1,0
    signal game_over   : std_logic;             -- goes high when lives reach 0
    signal lives_decrement : std_logic;
    signal score_resetn        : std_logic;

begin
    -- VGA sync instance
    vga_sync: entity work.vga_sync
        port map(
            clk       => clk,
            reset     => reset,
            hsync     => hsync,
            vsync     => vsync,
            comp_sync => comp_sync,
            p_tick  => p_tick,
            video_on  => video_on,
            pixel_x   => pixel_x,
            pixel_y   => pixel_y
        );
    blank         <= not video_on;
     -- Lives counter logic
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                lives_cnt <= to_unsigned(3,4);
            elsif lives_decrement = '1' and lives_cnt /= 0 then
                lives_cnt <= lives_cnt - 1;
            end if;
        end if;
    end process;
    lives_value <= std_logic_vector(lives_cnt);
    game_over   <= '1' when lives_cnt = 0 else '0';
        score_resetn <= not reset;

    -- Instantiate graph, now passing game_over in
    pong_grf_st_unit: entity work.pong_graph_st
      port map(
        clk             => clk,
        reset           => reset,
        btn             => btn,
        video_on        => video_on,
        pixel_x         => pixel_x,
        pixel_y         => pixel_y,
        graph_rgb       => rgb_next,
        score_update    => score_update,
        lives_decrement => lives_decrement,
        score_value     => score_value,
        lives_value     => lives_value,
        game_over       => game_over    -- NEW port
      );
    -- Score counter for 7-segment display
    score_counter: entity work.counter_7seg
        port map(
            resetn       => score_resetn,
            clock        => clk,
            score_update => score_update,
            segs         => segs,
            AN           => AN,
            counter_value => score_value,
            lives_value =>  lives_value
        );

    -- Pipeline RGB output
    process(clk)
    begin
        if rising_edge(clk) then
            if p_tick = '1' then
                rgb_reg <= rgb_next;
            end if;
        end if;
    end process;

    rgb_top        <= rgb_reg;
    vga_pixel_tick <= p_tick;

end architecture;
