library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_unsigned.all;

entity reg is
    generic(
        bits       : natural := 128;
        init_value : natural := 0
    );
    port(
        clk  : in  STD_LOGIC;
        rst  : in  STD_LOGIC;
        ld   : in  STD_LOGIC;
        din  : in  STD_LOGIC_VECTOR(bits - 1 downto 0);
        dout : out STD_LOGIC_VECTOR(bits - 1 downto 0)
    );
end reg;

architecture reg_arch of reg is
   signal cs, ns : STD_LOGIC_VECTOR(bits - 1 downto 0);
begin
    process(clk)
    begin
        if clk'event AND clk = '1' then
            if rst = '1' then
                cs <= std_logic_vector(to_unsigned(init_value, bits));
            else         
                cs <= ns;
            end if;
        end if;
    end process;

    ns   <= din when ld = '1' else cs;
    dout <= cs;
end reg_arch;