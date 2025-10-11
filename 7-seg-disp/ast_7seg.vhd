library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity counter_7seg is
    port (
        resetn        : in  std_logic;
        clock         : in  std_logic;
        score_update  : in  std_logic;
        lives_value   : in  std_logic_vector(3 downto 0);
        segs          : out std_logic_vector(6 downto 0);
        AN            : out std_logic_vector(7 downto 0);
        counter_value : out std_logic_vector(15 downto 0)
    );
end counter_7seg;

architecture Behavioral of counter_7seg is
    component hex2sevenseg
        port (
            hex  : in  std_logic_vector(3 downto 0);
            leds : out std_logic_vector(6 downto 0)
        );
    end component;

    signal counter      : unsigned(7 downto 0) := (others => '0');
    signal digit_mux    : std_logic_vector(3 downto 0);
    signal segs_internal: std_logic_vector(6 downto 0);
    signal refresh_cnt  : unsigned(19 downto 0) := (others => '0');
    signal sel          : std_logic_vector(1 downto 0) := "00";
    constant REFRESH_MAX: unsigned(19 downto 0) := to_unsigned(100000, 20);
begin
    -- Simple refresh timer for digit multiplexing
    process(clock)
    begin
        if rising_edge(clock) then
            if resetn = '0' then
                refresh_cnt <= (others => '0');
                sel <= "00";
            elsif refresh_cnt = REFRESH_MAX then
                refresh_cnt <= (others => '0');
                sel <= std_logic_vector(unsigned(sel) + 1);
            else
                refresh_cnt <= refresh_cnt + 1;
            end if;
        end if;
    end process;

    -- Score counter logic
    process(clock)
    begin
        if rising_edge(clock) then
            if resetn = '0' then
                counter <= (others => '0');
            elsif score_update = '1' then
                counter <= counter + 1;
            end if;
        end if;
    end process;

    -- Output full 16-bit counter
    counter_value <= "00000000" & std_logic_vector(counter);

    -- Select digit value based on sel
    with sel select
        digit_mux <= lives_value                             when "00",
                     (others => '0')                         when "01",
                     std_logic_vector(counter(3 downto 0))  when "10",
                     std_logic_vector(counter(7 downto 4))  when others;

    -- Active-low digit enable
    with sel select
        AN <= "11111110" when "00",
              "11111101" when "01",
              "11111011" when "10",
              "11110111" when others;

    -- Digit decoder
    HEX_TO_SEG: hex2sevenseg
        port map (
            hex  => digit_mux,
            leds => segs_internal
        );

    segs <= not segs_internal; -- Active-low display
end Behavioral;
