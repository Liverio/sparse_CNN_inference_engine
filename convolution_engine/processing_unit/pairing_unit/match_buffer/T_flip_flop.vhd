
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity t_flip_flop is
    port(
        clk    : in  STD_LOGIC;
        rst    : in  STD_LOGIC;
        toggle : in  STD_LOGIC;
        dout   : out STD_LOGIC
    );
end t_flip_flop;

architecture t_flip_flop_arch of t_flip_flop is
    signal int_dout : STD_LOGIC;
begin
    sync_proc: process(clk)
    begin
        if clk'event and clk = '1' then
            if rst = '1' then
                int_dout <= '0';
            else
                if toggle = '1' then 
                    int_dout <= NOT(int_dout);
                end if;    
            end if;        
        end if;
    end process;

    dout <= int_dout;
end t_flip_flop_arch;

