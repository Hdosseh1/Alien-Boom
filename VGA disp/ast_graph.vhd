library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity pong_graph_st is
    port(
        clk             : in std_logic;
        reset           : in std_logic;
        btn             : in std_logic_vector(4 downto 0);
        video_on        : in std_logic;
        pixel_x         : in std_logic_vector(9 downto 0);
        pixel_y         : in std_logic_vector(9 downto 0);
        graph_rgb       : out std_logic_vector(5 downto 0);
        score_update    : out std_logic;
        lives_decrement : out std_logic;
        score_value     : in std_logic_vector(15 downto 0);
        lives_value     : in std_logic_vector(3 downto 0)
    );
end pong_graph_st;

architecture sq_ball_arch of pong_graph_st is

-- Signal used to control speed of ball and how
-- often pushbuttons are checked for paddle movement.
signal refr_tick: std_logic;
-- x, y coordinates (0,0 to (639, 479)
signal pix_x, pix_y: unsigned(9 downto 0);

-- screen dimensions
constant MAX_X: integer := 640;
constant MAX_Y: integer := 480;

-- paddle left, right, top, bottom and height left &
-- right are constant. top & bottom are signals to
-- allow movement. bar_y_t driven by reg below.
constant BAR_SIZE: integer := 32;
signal bar_y_t, bar_y_b, bar_x_l, bar_x_r: unsigned(9 downto 0);

-- reg to track top boundary (x position is fixed)
signal bar_y_reg, bar_x_reg, bar_y_next, bar_x_next: unsigned(9 downto 0);

-- MODIFIED: bar moving velocity reduced from 2 to 1
-- the amount the bar is moved.
constant BAR_V: integer:= 2;

-- NEW: signals for continuous movement
signal move_right, move_left, move_up, move_down: std_logic := '0';

-- square ball -- ball left, right, top and bottom
-- all vary. Left and top driven by registers below.
-- Updated ball size to 32x16
constant BALL_SIZE_X: integer := 32;
constant BALL_SIZE_Y: integer := 32;

-- MODIFIED: Array type to handle multiple balls (5 balls)
type ball_position_array is array(0 to 4) of unsigned(9 downto 0);
signal ball_x_l, ball_x_r: ball_position_array;
signal ball_y_t, ball_y_b: ball_position_array;

-- NEW: Signal for tracking active/visible balls
signal ball_active: std_logic_vector(4 downto 0) := (others => '1');

-- firing ball or bullets
constant FIRING_BALL_SIZE: integer := 8;
signal fir_ball_x_l, fir_ball_x_r: unsigned(9 downto 0);
signal fir_ball_y_t, fir_ball_y_b: unsigned(9 downto 0);

-- reg to track left and top boundary for all balls
signal ball_x_reg, ball_x_next: ball_position_array;
signal ball_y_reg, ball_y_next: ball_position_array;

-- reg to track left and top boundary
signal fir_ball_x_reg, fir_ball_x_next: unsigned(9 downto 0);
signal fir_ball_y_reg, fir_ball_y_next: unsigned(9 downto 0);

-- reg to track ball speed for all balls
signal x_delta_reg, x_delta_next: ball_position_array;
signal y_delta_reg, y_delta_next: ball_position_array;

-- Add signal to detect collision events for all balls
signal ball_hit, ball_hit_reg: std_logic_vector(4 downto 0) := (others => '0');

-- NEW: Signal to detect bar destroyed event
signal bar_destroyed, bar_destroyed_reg: std_logic := '0';

-- NEW: Signal to detect game over (no lives left)
signal game_over: std_logic := '0';

-- ball movement can be pos or neg
constant BALL_V_N: unsigned(9 downto 0):= unsigned(to_signed(-1,10));
constant BALL_V_P: unsigned(9 downto 0):= unsigned(to_signed(1,10));

-- Updated ball image to 32x12
type rom_type is array(0 to 31) of std_logic_vector(0 to 31);
constant BALL_ROM: rom_type:= (
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
-- Updated ROM address bits to match new dimensions
signal rom_addr: unsigned(4 downto 0);  -- 4 bits for 16 rows
signal rom_col: unsigned(4 downto 0);   -- 5 bits for 32 columns
signal rom_data: std_logic_vector(31 downto 0);  -- 32 bits per row
signal rom_bit: std_logic;

-- round ball image
type fir_rom_type is array(0 to 7) of std_logic_vector(0 to 7);
constant FIRING_BALL_ROM: fir_rom_type:= (
    "00111100",
    "01111110",
    "11111111",
    "11111111",
    "11111111",
    "11111111",
    "01111110",
    "00111100");
signal fir_rom_addr, fir_rom_col: unsigned(2 downto 0);
signal fir_rom_data: std_logic_vector(7 downto 0);
signal fir_rom_bit: std_logic;

type bar_rom_type is array(0 to 31) of std_logic_vector(31 downto 0);
    constant BAR_ROM : bar_rom_type := (
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
    signal bar_rom_addr, bar_rom_col : unsigned(4 downto 0);
    signal bar_rom_data : std_logic_vector(31 downto 0);
    signal bar_rom_bit : std_logic;

-- object output signals -- new signal to indicate if
-- scan coord is within ball (modified for 5 balls)
signal wall_on, sq_bar_on, bar_on, fir_sq_ball_on, fir_ball_on: std_logic;
signal sq_ball_on, rd_ball_on: std_logic_vector(4 downto 0);
signal wall_rgb, bar_rgb, fir_ball_rgb: std_logic_vector(5 downto 0);
-- Different colors for each ball
type rgb_array is array(0 to 4) of std_logic_vector(5 downto 0);
signal ball_rgb: rgb_array;

-- Bitmap types for text messages
-- Updated type declaration for 96-bit wide bitmap
type you_win_array is array (0 to 11) of std_logic_vector(95 downto 0);
-- Updated type declaration for game over bitmap
type game_over_array is array (0 to 11) of std_logic_vector(95 downto 0);

constant YOU_WIN_BITMAP : game_over_array := (
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

-- Updated GAME OVER! Bitmap (96x12)
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
    "000000110001100110001110110000110011100000000000000001110011000001111000111000000011000110000000",
    "000000111111100110000110110000110011111111000000000000111111000001111000111111110011000111000000",
    "000000011111001110000110110000110011111111000000000000011110000001111000111111110011000011000000"
);

    -- Control signals for messages
    signal show_win, show_gameover : std_logic := '0';
    signal text_pixel : std_logic;

    constant WIN_X0  : integer := 160;
    constant WIN_Y0  : integer := 100;
    constant GAME_X0 : integer := 120;
    constant GAME_Y0 : integer := 120;

-- Updated constants for bitmap dimensions
    constant WIN_WIDTH  : integer := 96;
    constant WIN_HEIGHT : integer := 12;  
    constant GAME_WIDTH : integer := 96;  -- Updated to match new width
    constant GAME_HEIGHT: integer := 12;  -- Updated to match new height

-- Signal for score comparison
signal score_is_five : std_logic;

-- NEW: Signal to track active ball for rendering
signal active_ball_index: unsigned(2 downto 0);
signal any_ball_hit: std_logic;

-- NEW: Signal to count active balls
signal active_ball_count: unsigned(2 downto 0);

begin
    -- Create score checking signal
    score_is_five <= '1' when unsigned(score_value(3 downto 0)) = 5 else '0';
    
    -- NEW: Create game over signal
    game_over <= '1' when unsigned(lives_value) = 0 else '0';

    pix_x <= unsigned(pixel_x);
    pix_y <= unsigned(pixel_y);

-- refr_tick: 1-clock tick asserted at start of v_sync,
-- e.g., when the screen is refreshed -- speed is 60 Hz
    refr_tick <= '1' when (pix_y = 481) and (pix_x = 0)
    else '0';
    
-- pixel within paddle
    bar_y_t <= bar_y_reg;
    bar_y_b <= bar_y_reg + to_unsigned(BAR_SIZE-1,10);
    bar_x_l <= bar_x_reg;
    bar_x_r <= bar_x_reg + to_unsigned(BAR_SIZE-1,10);
    
    -- pixel within square bar
    sq_bar_on <= '1' when (bar_x_l <= pix_x) and
    (pix_x <= bar_x_r) and (bar_y_t <= pix_y) and
    (pix_y <= bar_y_b) else '0';

-- ROM row
    bar_rom_addr <= pix_y(4 downto 0) - bar_y_t(4 downto 0);

-- ROM column
    bar_rom_col <= pix_x(4 downto 0) - bar_x_l(4 downto 0);

-- Get row data
    bar_rom_data <= BAR_ROM(to_integer(bar_rom_addr));

-- Get column bit
    bar_rom_bit <= bar_rom_data(to_integer(bar_rom_col));

process(bar_y_reg, bar_x_reg, refr_tick, btn, game_over)
begin
    -- Default: maintain current position
    bar_y_next <= bar_y_reg;
    bar_x_next <= bar_x_reg;
    
    -- Only move the bar if game is not over
    -- FIXED: Removed the bar_respawning condition that was preventing movement after respawn
    if refr_tick = '1' and game_over = '0' then
        -- if btn 1 pressed and paddle not at bottom yet
        if (btn(1) = '1' and bar_y_b < (MAX_Y - 1 - BAR_V)) then
            bar_y_next <= bar_y_reg + BAR_V;
        -- if btn 0 pressed and bar not at top yet
        elsif (btn(0) = '1' and bar_y_t > BAR_V) then
            bar_y_next <= bar_y_reg - BAR_V;
        -- if btn 2 pressed and bar not at right yet
        elsif (btn(2) = '1' and bar_x_r < (MAX_X - 1 - BAR_V)) then
            bar_x_next <= bar_x_reg + BAR_V;
        -- if btn 3 pressed and bar not at left yet
        elsif (btn(3) = '1' and bar_x_l > BAR_V) then
            bar_x_next <= bar_x_reg - BAR_V;
        end if;
    end if;
end process;

-- MODIFIED: Collision detection for bar being hit
process(bar_x_l, bar_x_r, bar_y_t, bar_y_b, ball_x_l, ball_x_r, ball_y_t, ball_y_b, game_over, ball_active)
begin
    bar_destroyed <= '0';
    -- FIXED: Only check collisions when bar is not in respawning state
    if game_over = '0' then
        -- Check collision with each active ball
        for i in 0 to 4 loop
            if ball_active(i) = '1' and  -- Only check active balls
               (bar_x_l <= ball_x_r(i) and ball_x_l(i) <= bar_x_r) and
               (bar_y_t <= ball_y_b(i) and ball_y_t(i) <= bar_y_b) then
                bar_destroyed <= '1';
            end if;
        end loop;
    end if;
end process;
-- NEW: Process to count active balls
process(ball_active)
    variable count : unsigned(2 downto 0);
begin
    count := "000";
    for i in 0 to 4 loop
        if ball_active(i) = '1' then
            count := count + 1;
        end if;
    end loop;
    active_ball_count <= count;
end process;

-- MODIFIED: Set coordinates for all five balls
generate_ball_coords: for i in 0 to 4 generate
    -- Set coordinates of square ball, updated for new dimensions
    ball_x_l(i) <= ball_x_reg(i);
    ball_y_t(i) <= ball_y_reg(i);
    ball_x_r(i) <= ball_x_l(i) + BALL_SIZE_X - 1;
    ball_y_b(i) <= ball_y_t(i) + BALL_SIZE_Y - 1;
    
    -- Create square ball on signals for each ball (only if active)
    sq_ball_on(i) <= '1' when ball_active(i) = '1' and  -- Only show active balls
        (ball_x_l(i) <= pix_x) and
        (pix_x <= ball_x_r(i)) and (ball_y_t(i) <= pix_y) and
        (pix_y <= ball_y_b(i)) else '0';
end generate;

-- set coordinates of firing ball.
fir_ball_x_l <= fir_ball_x_reg;
fir_ball_y_t <= fir_ball_y_reg;
fir_ball_x_r <= fir_ball_x_l + FIRING_BALL_SIZE - 1;
fir_ball_y_b <= fir_ball_y_t + FIRING_BALL_SIZE - 1;

-- pixel within firing ball
fir_sq_ball_on <= '1' when (fir_ball_x_l <= pix_x) and
(pix_x <= fir_ball_x_r) and (fir_ball_y_t <= pix_y) and
(pix_y <= fir_ball_y_b) else '0';

-- Determine which ball is being rendered
active_ball_identification: process(pix_x, pix_y, sq_ball_on)
    variable found : boolean := false;
begin
    active_ball_index <= (others => '0');
    found := false;
    
    -- Find the first ball that contains the current pixel
    for i in 0 to 4 loop
        if sq_ball_on(i) = '1' and not found then
            active_ball_index <= to_unsigned(i, 3);
            found := true;
        end if;
    end loop;
end process;

-- ROM addressing for the active ball
rom_addr <= pix_y(4 downto 0) - ball_y_t(to_integer(active_ball_index))(4 downto 0) when sq_ball_on /= "00000" else (others => '0');
rom_col <= pix_x(4 downto 0) - ball_x_l(to_integer(active_ball_index))(4 downto 0) when sq_ball_on /= "00000" else (others => '0');
rom_data <= BALL_ROM(to_integer(rom_addr)) when sq_ball_on /= "00000" else (others => '0');
rom_bit <= rom_data(to_integer(rom_col)) when sq_ball_on /= "00000" else '0';

-- Turn balls on only if within square and ROM bit is 1
rd_ball_generation: for i in 0 to 4 generate
    rd_ball_on(i) <= '1' when (sq_ball_on(i) = '1') and (i = to_integer(active_ball_index)) and (rom_bit = '1') else '0';
end generate;

-- Assign different colors to each ball
ball_rgb(0) <= "001100"; -- Ball 1: red
ball_rgb(1) <= "000011"; -- Ball 2: blue
ball_rgb(2) <= "001111"; -- Ball 3: light blue
ball_rgb(3) <= "111100"; -- Ball 4: yellow
ball_rgb(4) <= "110011"; -- Ball 5: purple

-- Update the ball positions 60 times per second for all 5 balls
ball_position_update: for i in 0 to 4 generate
    ball_x_next(i) <= ball_x_reg(i) + x_delta_reg(i) when refr_tick = '1' and ball_active(i) = '1' else ball_x_reg(i);
    ball_y_next(i) <= ball_y_reg(i) + y_delta_reg(i) when refr_tick = '1' and ball_active(i) = '1' else ball_y_reg(i);
end generate;

-- ROM row
fir_rom_addr <= pix_y(2 downto 0) - fir_ball_y_t(2 downto 0);

-- ROM column
fir_rom_col <= pix_x(2 downto 0) - fir_ball_x_l(2 downto 0);

-- Get row data
fir_rom_data <= FIRING_BALL_ROM(to_integer(fir_rom_addr));

-- Get column bit
fir_rom_bit <= fir_rom_data(to_integer(fir_rom_col));

-- Turn ball on only if within square and ROM bit is 1.
fir_ball_on <= '1' when (fir_sq_ball_on = '1') and
(fir_rom_bit = '1') and game_over = '0' else '0';  -- No firing in game over
fir_ball_rgb <= "111000"; 

-- Check for collision between firing ball and all enemy balls
collision_detection: process(ball_x_l, ball_x_r, ball_y_t, ball_y_b, 
        fir_ball_x_l, fir_ball_x_r, fir_ball_y_t, fir_ball_y_b, ball_active)
begin
    -- Default - no collisions
    ball_hit <= (others => '0');
    
    -- Check for collisions with each active ball
    for i in 0 to 4 loop
        if ball_active(i) = '1' then  -- Only check active balls
            -- Check if firing ball hits enemy ball
            if ((fir_ball_x_l <= ball_x_r(i)) and (ball_x_l(i) <= fir_ball_x_r)) and
               ((fir_ball_y_t <= ball_y_b(i)) and (ball_y_t(i) <= fir_ball_y_b)) then
                ball_hit(i) <= '1';
            else
                ball_hit(i) <= '0';
            end if;
        else
            ball_hit(i) <= '0';
        end if;
    end loop;
end process;

-- Generate any_ball_hit signal when any ball is hit
any_ball_hit <= '1' when (ball_hit /= "00000") and (ball_hit_reg = "00000") else '0';

-- Generate score_update pulse when any ball is hit (rising edge)
score_update <= any_ball_hit and not game_over;

-- Set the value of the next ball positions according to boundaries for all balls
ball_movement_logic: process(x_delta_reg, y_delta_reg, ball_y_t, fir_ball_x_l, fir_ball_x_r,
     ball_x_l, ball_x_r, ball_y_b, bar_y_t, bar_y_b, bar_x_l, bar_x_r, game_over, ball_active)
begin
    -- Default: maintain current directions
    for i in 0 to 4 loop
        x_delta_next(i) <= x_delta_reg(i);
        y_delta_next(i) <= y_delta_reg(i);
        
        -- Only process movement for active balls
        if ball_active(i) = '1' then
            if ((game_over = '1') or (score_is_five = '1')) then
                -- Stop ball movement in game over
                x_delta_next(i) <= (others => '0');
                y_delta_next(i) <= (others => '0');
            else
                -- Normal ball movement logic
                if ball_y_t(i) < 1 then
                    y_delta_next(i) <= BALL_V_P;
                elsif ball_y_b(i) > (MAX_Y - 1) then
                    y_delta_next(i) <= BALL_V_N;
                elsif ball_x_l(i) < 1 then
                    x_delta_next(i) <= BALL_V_P;
                elsif ball_x_r(i) > (MAX_X - 1) then
                    x_delta_next(i) <= BALL_V_N;
                elsif ((fir_ball_x_l <= ball_x_r(i)) and (ball_x_r(i) <= fir_ball_x_r)) then
                    x_delta_next(i) <= ("0000000100");
                    y_delta_next(i) <= ("0000000100");
                end if;
            end if;
        end if;
    end loop;
end process;

-- Set the value of the next firing ball position according to
-- the boundaries.
process (refr_tick, fir_ball_y_reg, fir_ball_x_reg, 
         bar_y_t, bar_x_l, bar_x_r, btn, game_over)
begin
    -- Default assignment (maintain current position)
    fir_ball_x_next <= fir_ball_x_reg;
    fir_ball_y_next <= fir_ball_y_reg;
    
    if game_over = '1' then
        -- Stop firing ball in game over state
        fir_ball_x_next <= (others => '0');
        fir_ball_y_next <= (others => '0');
    elsif (refr_tick = '1') then
        -- Fire button pressed - launch the ball
        if ((btn(4) = '1') and (fir_ball_y_reg = 0)) then
            fir_ball_x_next <= bar_x_l + (BAR_SIZE / 2) - (FIRING_BALL_SIZE / 2);
            fir_ball_y_next <= bar_y_t - FIRING_BALL_SIZE;
            if (fir_ball_y_t > 0) then
                fir_ball_y_next <= fir_ball_y_reg - 2;                     
            end if;
        else
            -- Ball is already fired and moving - continue moving upward
            if (fir_ball_y_t > 0) then
                fir_ball_y_next <= fir_ball_y_reg - 2;  -- Move upward with fixed speed
            else
                -- Reset ball position when it reaches top of screen
                fir_ball_x_next <= (others => '0');
                fir_ball_y_next <= (others => '0');
            end if;
        end if;
    end if;
end process;

-- Process to handle bitmap text rendering
process(pix_x, pix_y, score_is_five, game_over)
    variable row : integer;
    variable col : integer;
begin
    text_pixel <= '0';
    
    -- Display "YOU WIN!" when score reaches 5
    if score_is_five = '1' and
        pix_x >= WIN_X0 and pix_x < WIN_X0 + WIN_WIDTH and
        pix_y >= WIN_Y0 and pix_y < WIN_Y0 + WIN_HEIGHT then

        row := to_integer(pix_y - WIN_Y0);
        col := to_integer(pix_x - WIN_X0);
        text_pixel <= YOU_WIN_BITMAP(row)(95 - col);
    end if;
    
    -- Display "GAME OVER!" when lives reach 0
    if game_over = '1' and
        pix_x >= GAME_X0 and pix_x < GAME_X0 + GAME_WIDTH and
        pix_y >= GAME_Y0 and pix_y < GAME_Y0 + GAME_HEIGHT then
        
        row := to_integer(pix_y - GAME_Y0);
        col := to_integer(pix_x - GAME_X0);
        text_pixel <= GAME_OVER_BITMAP(row)(95 - col);
    end if;
end process;
   
process (video_on, wall_on, bar_on, rd_ball_on, fir_ball_on, text_pixel, 
     fir_ball_rgb, wall_rgb, bar_rgb, ball_rgb)
begin
    -- Default: display black
    graph_rgb <= (others => '0');
    
    if video_on = '0' then
        graph_rgb <= (others => '0');
    else
        -- Display priority: text messages, then game elements
        if text_pixel = '1' then
            graph_rgb <= "111111";  -- White for text
        elsif bar_on = '1' then
            graph_rgb <= bar_rgb;   -- Bar color
        elsif rd_ball_on(0) = '1' then
            graph_rgb <= ball_rgb(0);  -- First enemy ball color
        elsif rd_ball_on(1) = '1' then
            graph_rgb <= ball_rgb(1);  -- Second enemy ball color
        elsif rd_ball_on(2) = '1' then
            graph_rgb <= ball_rgb(2);  -- Third enemy ball color
        elsif rd_ball_on(3) = '1' then
            graph_rgb <= ball_rgb(3);  -- Fourth enemy ball color
        elsif rd_ball_on(4) = '1' then
            graph_rgb <= ball_rgb(4);  -- Fifth enemy ball color
        elsif fir_ball_on = '1' then
            graph_rgb <= fir_ball_rgb; -- Player's firing ball color
        else
            if ((pix_x(5 downto 0) = "000000") and (pix_y(4 downto 0) = "00000")) then
                graph_rgb <= "111111";  -- white star
            else
                graph_rgb <= "000000";  -- black background
            end if;
        end if;
    end if;
end process;

-- Register and sequential logic
process (clk, reset)
begin
    if reset = '1' then
        -- Reset all registers to initial position
        -- Initialize each ball at different positions
        ball_x_reg(0) <= to_unsigned(100, 10);
        ball_y_reg(0) <= to_unsigned(100, 10);
        ball_x_reg(1) <= to_unsigned(200, 10);
        ball_y_reg(1) <= to_unsigned(150, 10);
        ball_x_reg(2) <= to_unsigned(300, 10);
        ball_y_reg(2) <= to_unsigned(100, 10);
        ball_x_reg(3) <= to_unsigned(400, 10);
        ball_y_reg(3) <= to_unsigned(150, 10);
        ball_x_reg(4) <= to_unsigned(500, 10);
        ball_y_reg(4) <= to_unsigned(100, 10);
        
        -- Initialize each ball with different movement directions
        x_delta_reg(0) <= BALL_V_P;
        y_delta_reg(0) <= BALL_V_P;
        x_delta_reg(1) <= BALL_V_N;
        y_delta_reg(1) <= BALL_V_P;
        x_delta_reg(2) <= BALL_V_P;
        y_delta_reg(2) <= BALL_V_N;
        x_delta_reg(3) <= BALL_V_N;
        y_delta_reg(3) <= BALL_V_N;
        x_delta_reg(4) <= BALL_V_P;
        y_delta_reg(4) <= BALL_V_P;
        
        -- Initialize all balls as active
        ball_active <= (others => '1');
        
        -- Initialize bar position to center bottom
        bar_y_reg <= to_unsigned(448, 10);  -- Fixed starting position near bottom
        bar_x_reg <= to_unsigned(1, 10);  -- Fixed starting position near center
        
        -- Reset firing ball
        fir_ball_x_reg <= (others => '0');
        fir_ball_y_reg <= (others => '0');
        bar_destroyed_reg <= '0';
        -- Reset hit detection
        ball_hit_reg <= (others => '0');
    elsif rising_edge(clk) then
        -- Update position registers for all balls
        for i in 0 to 4 loop
            ball_x_reg(i) <= ball_x_next(i);
            ball_y_reg(i) <= ball_y_next(i);
            x_delta_reg(i) <= x_delta_next(i);
            y_delta_reg(i) <= y_delta_next(i);
            
            -- When a ball is hit (rising edge detection), mark it as inactive
            if ball_hit(i) = '1' and ball_hit_reg(i) = '0' then
                ball_active(i) <= '0';  -- Make the ball disappear when hit
            end if;
        end loop;
            
            bar_x_reg <= bar_x_next;
            bar_y_reg <= bar_y_next;       
        -- Update firing ball position
        fir_ball_x_reg <= fir_ball_x_next;
        fir_ball_y_reg <= fir_ball_y_next;
        bar_destroyed_reg <= bar_destroyed;
        -- Update hit detection register for edge detection
        ball_hit_reg <= ball_hit;
        
        -- Reset all balls when game is over or player wins
        if game_over = '1' or score_is_five = '1' then
            -- Option to reset all balls if needed when game ends
            -- ball_active <= (others => '1');
        end if;
    end if;
end process;

bar_on <= '1' when (sq_bar_on = '1') and
(bar_rom_bit = '1') and (game_over = '0') else '0';
-- Modified: Make bar blink during respawning for visual feedback
bar_rgb <= "110000";
-- Generate lives_decrement signal on bar destruction (rising edge detection)
lives_decrement <= '1' when bar_destroyed = '1' and bar_destroyed_reg = '0' and game_over = '0' else '0';
end sq_ball_arch;