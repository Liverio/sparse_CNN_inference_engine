library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity priority_encoder is
    generic(
        input_width : natural := 2
    );
    port(
        input    : in  STD_LOGIC_VECTOR(input_width - 1 downto 0);
        found    : out STD_LOGIC;
        position : out STD_LOGIC_VECTOR(log_2(input_width) - 1 downto 0)
    );
end priority_encoder;

architecture priority_encoder_arch of priority_encoder is
begin
    process(input)
    begin
        found    <= '0';
        position <= std_logic_vector(to_unsigned(0, log_2(input_width)));

        for i in 0 to input_width - 1 loop
            if input(i) = '1' then
                found    <= '1';
                position <= std_logic_vector(to_unsigned(i, log_2(input_width)));
            end if;
        end loop;
    end process;
end priority_encoder_arch;