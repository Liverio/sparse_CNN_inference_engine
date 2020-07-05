library IEEE;
use IEEE.std_logic_1164.all;
use work.types.all;

entity MAC_processor is
    port(
        clk : in STD_LOGIC;
        rst : in STD_LOGIC;
        ----------------------------------------
        -- MAC processor controller interface --
        ----------------------------------------
        enable : in STD_LOGIC;
        flush  : in STD_LOGIC;
        --------------------------------------------
        -- Filter & activation memories interface --
        -------------------------------------------- 
        filter_val : in STD_LOGIC_VECTOR(FILTER_VAL_WIDTH - 1 downto 0);
        act_val    : in STD_LOGIC_VECTOR(ACT_VAL_WIDTH - 1 downto 0);
        ---------------------------------
        -- MAC output buffer interface --
        ---------------------------------
        enqueue_val : out STD_LOGIC;
        output      : out STD_LOGIC_VECTOR(ACT_VAL_WIDTH - 1 downto 0)
    );
end MAC_processor;

architecture MAC_processor_arch of MAC_processor is
    component MAC
        generic(
            operand_width : positive := 8
        );
        port(
            clk         : in  STD_LOGIC;
            rst         : in  STD_LOGIC;
            enable      : in  STD_LOGIC;
            flush       : in  STD_LOGIC;
            input_A     : in  STD_LOGIC_VECTOR(operand_width - 1 downto 0);
            input_B     : in  STD_LOGIC_VECTOR(operand_width - 1 downto 0);
            enqueue_val : out STD_LOGIC;
            output      : out STD_LOGIC_VECTOR(ACCUMULATOR_SIZE_FACTOR * operand_width - 1 downto 0)
        );
    end component;
    
    component scaler
        generic(
            input_width  : positive := 16;
            output_width : positive := 8
        );
        port(
            input  : in  STD_LOGIC_VECTOR( input_width - 1 downto 0);
            output : out STD_LOGIC_VECTOR(output_width - 1 downto 0)
        );
    end component;
    
    signal MAC_output      : STD_LOGIC_VECTOR(ACCUMULATOR_SIZE_FACTOR * ACT_VAL_WIDTH - 1 downto 0);
    signal MAC_output_ReLU : STD_LOGIC_VECTOR(ACCUMULATOR_SIZE_FACTOR * ACT_VAL_WIDTH - 1 downto 0);
begin
    MAC_I: MAC
        generic map(
            operand_width => ACT_VAL_WIDTH
        )
        port map(
            clk         => clk,
            rst         => rst,
            enable      => enable,
            flush       => flush,
            input_A     => filter_val,
            input_B     => act_val,
            enqueue_val => enqueue_val,
            output      => MAC_output
        );
        
    -- ReLU
    MAC_output_ReLU <= MAC_output when MAC_output(ACCUMULATOR_SIZE_FACTOR * ACT_VAL_WIDTH - 1) = '0' else
                       (others => '0');

    -- Resize MAC output from (2 * operand_width)b to (operand_width)b    
    scaler_I: scaler
        generic map(
            input_width  => ACCUMULATOR_SIZE_FACTOR * ACT_VAL_WIDTH,
            output_width => ACT_VAL_WIDTH
        )
        port map(
            input  => MAC_output_ReLU,
            output => output
        );
end MAC_processor_arch;