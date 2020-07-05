library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity addr_translator is
    generic(
        max_elements : positive := 1024;
        banks        : positive :=    1;
        bank_depth   : positive :=    2;
        mem_width    : positive :=   32;
        data_width   : positive :=    8
    );
    port(
        input_addr  : in  STD_LOGIC_VECTOR(log_2(max_elements) - 1 downto 0);
        output_addr : out STD_LOGIC_VECTOR(log_2(bank_depth) + addr_width(mem_width) - 1 downto 0);
        bank_no     : out STD_LOGIC_VECTOR(log_2(banks) - 1 downto 0) 
    );
end addr_translator;

architecture addr_translator_arch of addr_translator is
begin   
    -- Discard log_2(banks) and log_2(mem_width / data_width) LSb
    output_addr(log_2(bank_depth) + addr_width(mem_width) - 1 downto 0) <=
        resize(input_addr(log_2(max_elements) - 1 downto log_2(banks) + log_2(mem_width / data_width)), log_2(bank_depth) + addr_width(mem_width));
        
    bank_no <= input_addr(log_2(banks) + log_2(mem_width / data_width) - 1 downto log_2(mem_width / data_width));
end addr_translator_arch;