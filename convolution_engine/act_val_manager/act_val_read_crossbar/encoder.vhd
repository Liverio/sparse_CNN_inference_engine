library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity encoder is
    generic(
        input_width : natural := 16
    );
    port(
        input    : in  STD_LOGIC_VECTOR(input_width - 1 downto 0);
        position : out STD_LOGIC_VECTOR(log_2(input_width) - 1 downto 0)
    );
end encoder;
architecture encoder_arch of encoder is
begin       
    process(input)
        variable code : STD_LOGIC_VECTOR(log_2(input_width) - 1 downto 0);
    begin
        code := (others => '0');        
        
        for i in 0 to input_width - 1 loop
            if input(i) = '1' then
                code := code OR std_logic_vector(to_unsigned(i, code'length));
            end if;
        end loop;
        
        position <= code;
    end process;
end encoder_arch;

