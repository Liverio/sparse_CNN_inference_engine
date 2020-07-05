library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity bidirectional_counter is
    generic(
        bits : positive := 2;
        step : positive := 1
    );
    port(
        clk   : in  STD_LOGIC;
        rst   : in  STD_LOGIC;
        inc   : in  STD_LOGIC;
        dec   : in  STD_LOGIC;
        count : out STD_LOGIC_VECTOR(bits - 1 downto 0)
    );
end bidirectional_counter;

architecture bidirectional_counter_arch of bidirectional_counter is    
    signal cs : STD_LOGIC_VECTOR(bits - 1 downto 0);
    signal ns : STD_LOGIC_VECTOR(bits - 1 downto 0);
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
    process(cs, inc, dec)
        begin
            if inc = '1' then 
                ns <= std_logic_vector(unsigned(cs) + step);
            elsif dec = '1' then 
                ns <= std_logic_vector(unsigned(cs) - step);
            else 
                ns <= cs;
         end if;
   end process;

   count <= cs;
end bidirectional_counter_arch;