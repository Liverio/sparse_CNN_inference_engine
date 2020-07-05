library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity tree_adder is
    generic(
        input_width : positive := 32
    );
    port(
        input  : in  STD_LOGIC_VECTOR(input_width - 1 downto 0);
        output : out STD_LOGIC_VECTOR(log_2(input_width + 1) - 1 downto 0)
    );
end tree_adder;

architecture tree_adder_arch of tree_adder is
    component tree_adder
        generic(
            input_width : positive
        );
        port(
            input  : in  STD_LOGIC_VECTOR(input_width - 1 downto 0);
            output : out STD_LOGIC_VECTOR(log_2(input_width + 1) - 1 downto 0)
        );
    end component;
begin
    ---------------
    -- Base case --
    ---------------
    base_case: if input_width = 1 generate
        output <= input;
    end generate;
    
    ---------------
    -- Recursion --
    ---------------
    -- Input width is even
    even_width: if (input_width >= 2) AND (input_width MOD 2 = 0) generate
        signal out_a        : STD_LOGIC_VECTOR(log_2(input_width / 2 + 1) - 1 downto 0);
        signal out_b        : STD_LOGIC_VECTOR(log_2(input_width / 2 + 1) - 1 downto 0);
        signal stage_output : STD_LOGIC_VECTOR(log_2(input_width + 1) - 1 downto 0);
    begin
        left_tree_adder: tree_adder
            generic map(
                input_width => input_width / 2
            )
            port map(
                input  => input(input_width - 1 downto input_width / 2),
                output => out_a
            );
        
        right_tree_adder: tree_adder
            generic map(
                input_width => input_width / 2
            )
            port map(
                input  => input((input_width / 2) - 1 downto 0), 
                output => out_b
            );

        output <= c_add(out_a, out_b);
    end generate;
    
    -- Input width is odd
    odd_width: if (input_width > 2) AND (input_width MOD 2 /= 0) generate
        signal out_a        : STD_LOGIC_VECTOR(log_2(input_width / 2 + 1) - 1 downto 0);
        signal out_b        : STD_LOGIC_VECTOR(log_2(input_width / 2 + 1) - 1 downto 0);
        signal stage_output : STD_LOGIC_VECTOR(log_2(input_width + 1) - 1 downto 0);
    begin
        left_tree_adder: tree_adder
            generic map(
                input_width => input_width / 2
            )
            port map(
                input  => input(input_width - 1 downto input_width / 2 + 1),
                output => out_a
            );
        
        right_tree_adder: tree_adder
            generic map(
                input_width => input_width / 2
            )
            port map(
                input  => input(input_width / 2 downto 1),
                output => out_b
            );
 
        output <= add(c_add(out_a, out_b), input(0 downto 0));
    end generate;
end tree_adder_arch;