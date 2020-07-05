library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity counter is
    generic(
        bits : positive := 2;
        step : positive := 1);
    port(
        clk   : in  STD_LOGIC;
        rst   : in  STD_LOGIC;
        rst_2 : in  STD_LOGIC;
        inc   : in  STD_LOGIC;
        count : out STD_LOGIC_VECTOR(bits - 1 downto 0));
end counter;

architecture counter_arch of counter is    
    signal cs, ns : STD_LOGIC_VECTOR(bits - 1 downto 0);
begin    
    fsm_cs:
    process(clk)
    begin        
        if rising_edge(clk) then
            if rst = '1' then 
                cs <= (others => '0');
            else             
                cs <= ns;
            end if;
        end if;
    end process; 
    
    fsm_ns:
    process(cs, rst_2, inc)
        begin
            if rst_2 = '1' then
                ns <= (others => '0');                
            elsif inc = '1' then 
                ns <= std_logic_vector(unsigned(cs) + step);
            else 
                ns <= cs;
         end if;
   end process;

   count <= cs;
end counter_arch;