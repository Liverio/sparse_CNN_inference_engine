library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity scaler is
    generic(
        input_width  : positive := 16;
        output_width : positive := 8
    );
    port(
        input  : in  STD_LOGIC_VECTOR( input_width - 1 downto 0);
        output : out STD_LOGIC_VECTOR(output_width - 1 downto 0)
    );
end scaler;

architecture scaler_arch of scaler is
    signal rounder : STD_LOGIC_VECTOR(input_width - 1 downto 0);
    signal add     : STD_LOGIC_VECTOR(input_width - 1 downto 0);
begin
    rounder_I: for i in 0 to input_width - 1 generate
        one: if i = input_width / 2 - 1 generate
            rounder(i) <= '1';
        end generate;
        
        zero: if i /= input_width / 2 - 1 generate
            rounder(i) <= '0';
        end generate;
    end generate;    

    add    <= std_logic_vector(unsigned(input) + unsigned(rounder));    
    output <= add(input_width - 1 downto input_width - output_width);
end scaler_arch;

