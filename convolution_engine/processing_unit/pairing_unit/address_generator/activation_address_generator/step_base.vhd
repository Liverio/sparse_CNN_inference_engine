library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity step_base is
    port(
        clk                : in  STD_LOGIC;
        rst                : in  STD_LOGIC;
        start_convolution  : in  STD_LOGIC;
        act_inc_x          : in  STD_LOGIC;
        filter_depth       : in  STD_LOGIC_VECTOR(log_2(MAX_FILTER_DEPTH / ACT_IND_WIDTH) - 1 downto 0);
        act_inc_y          : in  STD_LOGIC;
        act_x_z_slice_size : in  STD_LOGIC_VECTOR(log_2(MAX_ACT_WIDTH * MAX_ACT_DEPTH / ACT_IND_WIDTH) - 1 downto 0);
        act_step_base      : out STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS / ACT_IND_WIDTH) - 1 downto 0)
    );
end step_base;

architecture step_base_arch of step_base is
    component reg
        generic(bits       : positive := 128;
                init_value : natural  := 0
        );
        port (
              clk  : in  STD_LOGIC;
              rst  : in  STD_LOGIC;
              ld   : in  STD_LOGIC;
              din  : in  STD_LOGIC_VECTOR(bits - 1 downto 0);
              dout : out STD_LOGIC_VECTOR(bits - 1 downto 0)
        );
    end component;
    
    -- Activation step base
    signal step_base_input : STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS / ACT_IND_WIDTH) - 1 downto 0);
    signal step_base_int   : STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS / ACT_IND_WIDTH) - 1 downto 0);
    
    -- Base addr when increasing y
    signal step_base_y : STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS / ACT_IND_WIDTH) - 1 downto 0);
begin
    ---------------
    -- Base addr --
    ---------------
    step_base_reg: reg generic map(bits => log_2(MAX_ACT_ELEMENTS / ACT_IND_WIDTH))
        port map(clk, rst OR start_convolution, act_inc_x OR act_inc_y, step_base_input, step_base_int);
    
    step_base_input <=  resize(step_base_y + act_x_z_slice_size, log_2(MAX_ACT_ELEMENTS / ACT_IND_WIDTH)) when act_inc_y = '1' else
                        resize(step_base_int + filter_depth, log_2(MAX_ACT_ELEMENTS / ACT_IND_WIDTH));

    ---------------------------------
    -- Base addr when increasing y --
    ---------------------------------
    step_base_y_reg: reg generic map(bits => log_2(MAX_ACT_ELEMENTS / ACT_IND_WIDTH))
        port map(clk, rst OR start_convolution, act_inc_y, resize(step_base_y + act_x_z_slice_size, log_2(MAX_ACT_ELEMENTS / ACT_IND_WIDTH)), step_base_y);

    -------------
    -- Outputs --
    -------------
    act_step_base <= step_base_int;
end step_base_arch;