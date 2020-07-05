library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_unsigned.all;

entity D_flip_flop is
    port(
        clk  : in  STD_LOGIC;
        rst  : in  STD_LOGIC;
        ld   : in  STD_LOGIC;
        din  : in  STD_LOGIC;
        dout : out STD_LOGIC
    );
end D_flip_flop;

architecture D_flip_flop_arch of D_flip_flop is
begin
    process(clk)
    begin
        if clk'event AND clk = '1' then
            if rst = '1' then
                dout <= '0';
            else         
                if ld = '1' then 
                    dout <= din;
                end if;    
            end if;
        end if;
    end process;
end D_flip_flop_arch;