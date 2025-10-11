-- File: pong_top_st.vhd
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pong_top_st is
  port(
    clk            : in  std_logic;
    reset          : in  std_logic;
    btn            : in  std_logic_vector(4 downto 0);
    hsync          : out std_logic;
    vsync          : out std_logic;
    comp_sync      : out std_logic;
    blank          : out std_logic;
    vga_pixel_tick : out std_logic;
    rgb_top        : out std_logic_vector(5 downto 0);
    segs           : out std_logic_vector(6 downto 0);
    AN             : out std_logic_vector(7 downto 0)
  );
end entity pong_top_st;

architecture arch of pong_top_st is
  signal pixel_x, pixel_y   : std_logic_vector(9 downto 0);
  signal video_on           : std_logic;
  signal p_tick             : std_logic;
  signal rgb_reg, rgb_next  : std_logic_vector(5 downto 0);

  signal score_update       : std_logic;
  signal lives_decrement    : std_logic;
  signal score_resetn       : std_logic;

  signal score_value        : std_logic_vector(15 downto 0);
  signal lives_value        : std_logic_vector(3 downto 0);
  signal game_over          : std_logic;

  signal lives_cnt          : unsigned(3 downto 0);

  component vga_sync is
    port(
      clk       : in  std_logic;
      reset     : in  std_logic;
      hsync     : out std_logic;
      vsync     : out std_logic;
      video_on  : out std_logic;
      p_tick    : out std_logic;
      pixel_x   : out std_logic_vector(9 downto 0);
      pixel_y   : out std_logic_vector(9 downto 0);
      comp_sync : out std_logic
    );
  end component;

  component pong_graph_st is
    port(
      clk             : in  std_logic;
      reset           : in  std_logic;
      btn             : in  std_logic_vector(4 downto 0);
      video_on        : in  std_logic;
      pixel_x         : in  std_logic_vector(9 downto 0);
      pixel_y         : in  std_logic_vector(9 downto 0);
      graph_rgb       : out std_logic_vector(5 downto 0);
      score_update    : out std_logic;
      lives_decrement : out std_logic;
      score_value     : in  std_logic_vector(15 downto 0);
      lives_value     : in  std_logic_vector(3 downto 0);
      game_over       : in  std_logic
    );
  end component;

  component counter_7seg is
    port(
      resetn        : in  std_logic;
      clock         : in  std_logic;
      score_update  : in  std_logic;
      lives_value   : in  std_logic_vector(3 downto 0);
      segs          : out std_logic_vector(6 downto 0);
      AN            : out std_logic_vector(7 downto 0);
      counter_value : out std_logic_vector(15 downto 0)
    );
  end component;

begin
  -- VGA sync
  vga_sync_unit: vga_sync
    port map(
      clk       => clk,
      reset     => reset,
      hsync     => hsync,
      vsync     => vsync,
      video_on  => video_on,
      p_tick    => p_tick,
      pixel_x   => pixel_x,
      pixel_y   => pixel_y,
      comp_sync => comp_sync
    );

  vga_pixel_tick <= p_tick;
  blank          <= video_on;
  score_resetn  <= not reset;

  -- Latch VGA output
  process(clk)
  begin
    if rising_edge(clk) and p_tick = '1' then
      rgb_reg <= rgb_next;
    end if;
  end process;
  rgb_top <= rgb_reg;

  -- Lives counter: start at 3, decrement on each hit
  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        lives_cnt <= to_unsigned(3,4);
      elsif lives_decrement = '1' and lives_cnt > 0 then
        lives_cnt <= lives_cnt - 1;
      end if;
    end if;
  end process;
  lives_value <= std_logic_vector(lives_cnt);
  game_over   <= '1' when lives_cnt = to_unsigned(0,4) else '0';

  -- Instantiate game logic
  pong_grf_st_unit: pong_graph_st
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
      game_over       => game_over
    );

  -- 7-seg display
  score_counter: counter_7seg
    port map(
      resetn        => score_resetn,
      clock         => clk,
      score_update  => score_update,
      lives_value   => lives_value,
      segs          => segs,
      AN            => AN,
      counter_value => score_value
    );
end architecture;

-- File: pong_graph_st.vhd
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pong_graph_st is
  port(
    clk, reset        : in  std_logic;
    btn               : in  std_logic_vector(4 downto 0);
    video_on          : in  std_logic;
    pixel_x, pixel_y  : in  std_logic_vector(9 downto 0);
    graph_rgb         : out std_logic_vector(5 downto 0);
    score_update      : out std_logic;
    lives_decrement   : out std_logic;
    score_value       : in  std_logic_vector(15 downto 0);
    lives_value       : in  std_logic_vector(3 downto 0);
    game_over         : in  std_logic
  );
end entity pong_graph_st;

architecture sq_ball_arch of pong_graph_st is
    constant MAX_X       : integer := 640;
    constant MAX_Y       : integer := 480;
    constant BAR_SIZE    : integer := 32;
    constant BALL_SIZE   : integer := 32;
    constant FIRING_SIZE : integer := 8;

    -- Text message origin offsets
    constant WIN_X0  : integer := 160;
    constant WIN_Y0  : integer := 100;
    constant GAME_X0 : integer := 120;
    constant GAME_Y0 : integer := 120;

    signal pix_x, pix_y  : unsigned(9 downto 0);
    signal refr_tick     : std_logic;

    signal bar_x_reg, bar_y_reg   : unsigned(9 downto 0) := (others=>'0');
    signal bar_x_next, bar_y_next : unsigned(9 downto 0);

    signal ball_x_reg, ball_y_reg : unsigned(9 downto 0);
    signal x_delta_reg, y_delta_reg : unsigned(9 downto 0);
    signal ball_x_next, ball_y_next : unsigned(9 downto 0);
    constant BALL_P_N: unsigned(9 downto 0):= to_unsigned(1,10);
    constant BALL_V_N: unsigned(9 downto 0):= unsigned(to_unsigned(-1,10));

    signal fir_x_reg, fir_y_reg   : unsigned(9 downto 0) := (others=>'0');
    signal fir_x_next, fir_y_next : unsigned(9 downto 0);
    signal firing_active          : std_logic := '0';

    signal ball_hit, ball_hit_reg : std_logic := '0';

    signal bar_destroyed     : std_logic;
    signal bar_destroyed_reg : std_logic;
    signal bar_x_l, bar_x_r, bar_y_t, bar_y_b : unsigned(9 downto 0);

    type rom32x32 is array(0 to 31) of std_logic_vector(31 downto 0);
    constant BALL_ROM : rom32x32 := (
        "00000001110000000000001111000000",
        "00000001110000000000001111000000",
        "00000001110000000000001111000000",
        "00000001110000000000001111000000",
        "00000000001110000001110000000000",
        "00000000001110000001110000000000",
        "00000000001110000001110000000000",
        "00000000001110000001110000000000",
        "00000001111111111111111111000000",
        "00000001111111111111111111000000",
        "00000001111111111111111111000000",
        "00000001111111111111111111000000",
        "00011111110001111110001111111000",
        "00011111110001111110001111111000",
        "00011111110001111110001111111000",
        "00011111110001111110001111111000",
        "11111111111111111111111111111111",
        "11111111111111111111111111111111",
        "11111111111111111111111111111111",
        "11111111111111111111111111111111",
        "11100001111111111111111111000111",
        "11100001111111111111111111000111",
        "11100001111111111111111111000111",
        "11100001111111111111111111000111",
        "11100001110000000000001111000111",
        "11100001110000000000001111000111",
        "11100001110000000000001111000111",
        "11100001110000000000001111000111",
        "00000000001110000001110000000000",
        "00000000001110000001110000000000",
        "00000000001110000001110000000000",
        "00000000001110000001110000000000"
    );

    type rom8x8 is array(0 to 7) of std_logic_vector(7 downto 0);
    constant FIRING_ROM : rom8x8 := (
        "00111100",
        "01111110",
        "11111111",
        "11111111",
        "11111111",
        "11111111",
        "01111110",
        "00111100"
    );

    constant BAR_ROM : rom32x32 := (
        "00000000000000111100000000000000",
        "00000000000001111110000000000000",
        "00000000000011111111000000000000",
        "00000000000111111111100000000000",
        "00000000000111111111100000000000",
        "00000000001111111111100000000000",
        "00000000001111111111110000000000",
        "00000000001111111111111000000000",
        "00000000001111111111110000000000",
        "00000000011111111111111000000000",
        "00000000111111111111111100000000",
        "00000111111111111111111111100000",
        "00100111111111111111111111100100",
        "00111111111111111111111111111100",
        "01111111111111111111111111111110",
        "11111111111111111111111111111111",
        "11111111111111111111111111111111",
        "11111111111111111111111111111111",
        "11111111111111111111111111111111",
        "11111111111111111111111111111111",
        "11111111111111111111111111111111",
        "11111111111111111111111111111111",
        "11111111111111111111111111111111",
        "11111111111111111111111011111111",
        "11111101111110111101111111011111",
        "11111011111110000001111111011111",
        "11111011111110000001111111011111",
        "11110011111110000001111111001111",
        "11000011111110000001111111000001",
        "10000011111110000001111111000001",
        "00000011111110000001111111000000",
        "00000000111100000000011000000000"
    );

    type you_win_array is array(0 to 11) of std_logic_vector(95 downto 0);
    constant YOU_WIN_BITMAP : you_win_array := (
        "000000000000000011100011100011100001100011000000000011000001101111111001100011000000000000000000",
        "000000000000000001100011000110110001100011000000000011000001100011100001110011000000000000000000",
        "000000000000000001110111001100011001100011000000000011000001100011100001110011000000000000000000",
        "000000000000000000110110001100011001100011000000000011001101100011100001111011000000000000000000",
        "000000000000000000111110001100011001100011000000000001011101100011100001111011000000000000000000",
        "000000000000000000011100001100011001100011000000000001011101000011100001101011000000000000000000",
        "000000000000000000011100001100011001100011000000000001111111000011100001101111000000000000000000",
        "000000000000000000011100001100011001100011000000000001110111000011100001101111000000000000000000",
        "000000000000000000011100001100011001100011000000000001110111000011100001100111000000000000000000",
        "000000000000000000011100000110110001100011000000000001110111000011100001100111000000000000000000",
        "000000000000000000011100000011100000111110000000000001100011001111111001100011000000000000000000",
        "000000000000000000011100000001100000111100000000000001100011001111111001100011000000000000000000"
    );

    type game_over_array is array(0 to 11) of std_logic_vector(95 downto 0);
    constant GAME_OVER_BITMAP : game_over_array := (
        "000000001111000001110000111001110011111111000000000000011110000110000110111111110011111100000000",
        "000000111111000001111000111001110011111111000000000000111111000110000110111111110011111110000000",
        "000000111000000001111000111001110011100000000000000001110011000110001110111000000011000110000000",
        "000001110000000011111000111011110011100000000000000001100011100110001100111000000011000111000000",
        "000001100000000011011000111111110011100000000000000001100011100111001100111000000011000110000000",
        "000001100000000011001100111110110011111110000000000001100001100011001100111111100011111110000000",
        "000001100111100011001100110110110011111110000000000001100011100011001100111111100011111100000000",
        "000001100111100111111100110110110011100000000000000001100011100011011000111000000011001110000000",
        "000001110001100111111100110000110011100000000000000001100011100011111000111000000011000110000000",
        "000001100011001100011101100001100111000000000000000111001100000111100011100000001100011000000000",
        "000000111111100110000110110000110011111111000000000000111111000001111000111111110011000111000000",
        "000000011111001110000110110000110011111111000000000000011110000001111000111111110011000011000000"
    );

    signal bar_on, ball_on, fir_on, text_on : std_logic;
    signal rgb_bar, rgb_ball, rgb_fir       : std_logic_vector(5 downto 0);
    signal score_five                       : std_logic;

    signal text_pixel : std_logic;
begin
    pix_x <= unsigned(pixel_x);
    pix_y <= unsigned(pixel_y);
    refr_tick <= '1' when pix_x = to_unsigned(0,10) and pix_y = to_unsigned(481,10) else '0';

    score_five   <= '1' when score_value(3 downto 0) = "0101" else '0';
    score_update <= ball_hit and not ball_hit_reg;

    bar_on  <= '1' when pix_x >= bar_x_reg and pix_x < bar_x_reg + to_unsigned(BAR_SIZE,10)
                     and pix_y >= bar_y_reg and pix_y < bar_y_reg + to_unsigned(BAR_SIZE,10)
              else '0';
    rgb_bar <= "001100";

    ball_on <= '1' when pix_x >= ball_x_reg and pix_x < ball_x_reg + to_unsigned(BALL_SIZE,10)
                       and pix_y >= ball_y_reg and pix_y < ball_y_reg + to_unsigned(BALL_SIZE,10)
               else '0';
    rgb_ball <= "110000";

    fir_on  <= '1' when firing_active = '1' and pix_x >= fir_x_reg and pix_x < fir_x_reg + to_unsigned(FIRING_SIZE,10)
                     and pix_y >= fir_y_reg and pix_y < fir_y_reg + to_unsigned(FIRING_SIZE,10)
              else '0';
    rgb_fir <= "111000";

    text_on <= YOU_WIN_BITMAP(to_integer(pix_y - to_unsigned(WIN_Y0,10)))(95 - to_integer(pix_x - to_unsigned(WIN_X0,10)))
              when score_five = '1'
                and pix_x >= to_unsigned(WIN_X0,10)
                and pix_x < to_unsigned(WIN_X0+96,10)
                and pix_y >= to_unsigned(WIN_Y0,10)
                and pix_y < to_unsigned(WIN_Y0+12,10)
              else GAME_OVER_BITMAP(to_integer(pix_y - to_unsigned(GAME_Y0,10)))(95 - to_integer(pix_x - to_unsigned(GAME_X0,10)))
              when game_over = '1'
                and pix_x >= to_unsigned(GAME_X0,10)
                and pix_x < to_unsigned(GAME_X0+96,10)
                and pix_y >= to_unsigned(GAME_Y0,10)
                and pix_y < to_unsigned(GAME_Y0+12,10)
              else '0';

    process(video_on, text_on, bar_on, ball_on, fir_on)
    begin
        if video_on = '0' then
            graph_rgb <= "000000";
        elsif text_on = '1' then
            graph_rgb <= "111111";
        elsif bar_on = '1' then
            graph_rgb <= rgb_bar;
        elsif ball_on = '1' then
            graph_rgb <= rgb_ball;
        elsif fir_on = '1' then
            graph_rgb <= rgb_fir;
        else
            graph_rgb <= "000000";
        end if;
    end process;

    process(refr_tick, btn, bar_x_reg, bar_y_reg, ball_x_reg, ball_y_reg, fir_x_reg, fir_y_reg, x_delta_reg, y_delta_reg)
    begin
        bar_x_next   <= bar_x_reg;
        bar_y_next   <= bar_y_reg;
        ball_x_next  <= ball_x_reg;
        ball_y_next  <= ball_y_reg;
        fir_x_next   <= fir_x_reg;
        fir_y_next   <= fir_y_reg;
        ball_hit     <= '0';

        if refr_tick = '1' then
            -- vertical movement (up/down)
            if btn(1) = '1' and bar_y_reg + to_unsigned(BAR_SIZE,10) < to_unsigned(MAX_Y,10) then
                bar_y_next <= bar_y_reg + to_unsigned(4,10);
            elsif btn(0) = '1' and bar_y_reg > to_unsigned(0,10) then
                bar_y_next <= bar_y_reg - to_unsigned(4,10);
            end if;
            -- horizontal movement (right/left)
            if btn(2) = '1' and bar_x_reg + to_unsigned(BAR_SIZE,10) < to_unsigned(MAX_X,10) then
                bar_x_next <= bar_x_reg + to_unsigned(4,10);
            elsif btn(3) = '1' and bar_x_reg > to_unsigned(0,10) then
                bar_x_next <= bar_x_reg - to_unsigned(4,10);
            end if;

            -- fire projectile
            if btn(4) = '1' and firing_active = '0' then
                firing_active <= '1';
                fir_x_next    <= bar_x_reg + to_unsigned(BAR_SIZE/2,10) - to_unsigned(FIRING_SIZE/2,10);
                fir_y_next    <= bar_y_reg;
            elsif firing_active = '1' then
                if fir_y_reg > to_unsigned(0,10) then
                    fir_y_next <= fir_y_reg - to_unsigned(4,10);
                else
                    firing_active <= '0';
                end if;
            end if;

            -- ball movement
            ball_x_next <= unsigned(ball_x_reg) + unsigned(x_delta_reg);
            ball_y_next <= unsigned(ball_y_reg) + unsigned(y_delta_reg);

            -- bounce walls
            if ball_x_next < to_unsigned(0,10) or ball_x_next > to_unsigned(MAX_X - BALL_SIZE,10) then
                x_delta_reg <= BALL_V_N;
            end if;
            if ball_y_next < to_unsigned(0,10) then
                y_delta_reg <= BALL_V_N;
            end if;

            -- collision resets and hit detection
            if ball_y_next + to_unsigned(BALL_SIZE,10) >= bar_y_reg and
               ball_x_next >= bar_x_reg and ball_x_next < bar_x_reg + to_unsigned(BAR_SIZE,10) then
                bar_x_next  <= to_unsigned((MAX_X - BAR_SIZE)/2,10);
                bar_y_next  <= to_unsigned(MAX_Y - BAR_SIZE - 16,10);
                ball_x_next <= to_unsigned((MAX_X/2) - BALL_SIZE/2,10);
                ball_y_next <= to_unsigned(BALL_SIZE,10);
            end if;

            if firing_active = '1' and
               fir_x_reg >= ball_x_reg and fir_x_reg < ball_x_reg + to_unsigned(BALL_SIZE,10) and
               fir_y_reg >= ball_y_reg and fir_y_reg < ball_y_reg + to_unsigned(BALL_SIZE,10) then
                ball_hit      <= '1';
                firing_active <= '0';
            end if;
        end if;
    end process;

    process(clk, reset)
    begin
        if reset = '1' then
            bar_x_reg    <= to_unsigned((MAX_X - BAR_SIZE)/2,10);
            bar_y_reg    <= to_unsigned(MAX_Y - BAR_SIZE - 16,10);
            ball_x_reg   <= to_unsigned((MAX_X/2) - BALL_SIZE/2,10);
            ball_y_reg   <= to_unsigned(BALL_SIZE,10);
            x_delta_reg  <= to_unsigned(1,10);
            y_delta_reg  <= to_unsigned(1,10);
            fir_x_reg    <= (others=>'0');
            fir_y_reg    <= (others=>'0');
            ball_hit_reg <= '0';
            bar_destroyed_reg <= '0';
        elsif rising_edge(clk) then
            bar_x_reg           <= bar_x_next;
            bar_y_reg           <= bar_y_next;
            ball_x_reg          <= ball_x_next;
            ball_y_reg          <= ball_y_next;
            fir_x_reg           <= fir_x_next;
            fir_y_reg           <= fir_y_next;
            ball_hit_reg        <= ball_hit;
            bar_destroyed_reg   <= bar_destroyed;
        end if;
    end process;

end architecture sq_ball_arch;
