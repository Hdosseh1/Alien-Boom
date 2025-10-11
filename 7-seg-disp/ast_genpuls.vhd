library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.math_real.log2;
use ieee.math_real.ceil;

entity my_genpulse is
    generic (COUNT: INTEGER:= (10**8)/2); -- (10**8)/2 cycles of T = 10 ns --> 0.5 s
    port (
        clock, resetn, E: in std_logic;
        Q: out std_logic_vector (integer(ceil(log2(real(COUNT)))) - 1 downto 0);
        z: out std_logic
    );
end my_genpulse;

architecture Behavioral of my_genpulse is
    signal count_int: integer range 0 to COUNT-1;
    signal z_int: std_logic;
begin
    process(clock, resetn)
    begin
        if resetn = '0' then
            count_int <= 0;
            z_int <= '0';
        elsif rising_edge(clock) then
            if E = '1' then
                if count_int = COUNT-1 then
                    count_int <= 0;
                    z_int <= '1';
                else
                    count_int <= count_int + 1;
                    z_int <= '0';
                end if;
            end if;
        end if;
    end process;
    
    Q <= std_logic_vector(to_unsigned(count_int, integer(ceil(log2(real(COUNT))))));
    z <= z_int;
end Behavioral;