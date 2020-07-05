library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity request_comparator is
    generic(
        bank_no : integer := 0
    );
    port(
        bank_requests       : in  tp_act_val_bank_requests;
        bank_request_served : in  STD_LOGIC_VECTOR(PUs - 1 downto 0);
        unit_requesting     : out STD_LOGIC_VECTOR(PUs - 1 downto 0)
    );
end request_comparator;

architecture request_comparator_arch of request_comparator is
begin
    -- Find the unit that accesses to the bank 'bank_no'
    banks_selection: for i in PUs - 1 downto 0 generate
        unit_requesting(i) <= '1' when bank_request_served(i)    = '1'     AND
                                       to_uint(bank_requests(i)) = bank_no else
                              '0';        
    end generate;
end request_comparator_arch;