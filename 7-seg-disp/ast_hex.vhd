library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity hex2sevenseg is
    port (
        hex: in std_logic_vector (3 downto 0);
        leds: out std_logic_vector (6 downto 0)
    );
end hex2sevenseg;

architecture Behavioral of hex2sevenseg is
begin
    -- 7-segment encoding: abcdefg (active high)
    -- segment a is MSB (leds(6)), segment g is LSB (leds(0))
    process(hex)
    begin
        case hex is
            when "0000" => leds <= "0111111"; -- 0
            when "0001" => leds <= "0000110"; -- 1
            when "0010" => leds <= "1011011"; -- 2
            when "0011" => leds <= "1001111"; -- 3
            when "0100" => leds <= "1100110"; -- 4
            when "0101" => leds <= "1101101"; -- 5
            when "0110" => leds <= "1111101"; -- 6
            when "0111" => leds <= "0000111"; -- 7
            when "1000" => leds <= "1111111"; -- 8
            when "1001" => leds <= "1101111"; -- 9
            when "1010" => leds <= "1110111"; -- A
            when "1011" => leds <= "1111100"; -- b
            when "1100" => leds <= "0111001"; -- C
            when "1101" => leds <= "1011110"; -- d
            when "1110" => leds <= "1111001"; -- E
            when "1111" => leds <= "1110001"; -- F
            when others => leds <= "0000000"; -- Blank
        end case;

    end process;
end Behavioral;