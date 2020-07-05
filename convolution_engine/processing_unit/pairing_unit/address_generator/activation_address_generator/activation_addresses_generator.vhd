library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity act_addrs_generator is
    port(
        clk                       : in  STD_LOGIC;
        rst                       : in  STD_LOGIC;
        start_convolution         : in  STD_LOGIC;
        convolution_step_done     : in  STD_LOGIC;
        act_x_z_slice_size        : in  STD_LOGIC_VECTOR(log_2(MAX_ACT_WIDTH * MAX_ACT_DEPTH) - 1 downto 0);
        filter_depth              : in  STD_LOGIC_VECTOR(log_2(MAX_FILTER_DEPTH) - 1 downto 0);
        act_base                  : in  STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS / SECTION_WIDTH) - 1 downto 0);
        act_section_offset        : in  STD_LOGIC_VECTOR(log_2(SECTION_WIDTH) - 1 downto 0);
        filter_no                 : in  STD_LOGIC_VECTOR(log_2(MAX_FILTERS) - 1 downto 0);
        filters_no                : in  STD_LOGIC_VECTOR(log_2(MAX_FILTERS) - 1 downto 0);
        ind_filter_inc_x          : in  STD_LOGIC;
        ind_filter_inc_y          : in  STD_LOGIC;
        ind_filter_inc_z          : in  STD_LOGIC;
        ind_act_inc_x             : in  STD_LOGIC;
        ind_act_inc_y             : in  STD_LOGIC;
        ind_convolution_step_done : in  STD_LOGIC;
        act_ind_addr              : out STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS / ACT_IND_WIDTH) - 1 downto 0);
        act_val_addr              : out STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS) - 1 downto 0);
        new_act_val_addr          : out STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS) - 1 downto 0)
    );
end act_addrs_generator;

architecture act_addrs_generator_arch of act_addrs_generator is
    component step_base
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
    end component;
    
    component filter_offset
        generic(
            divisor : positive := 1
        );
        port(
            clk                   : in  STD_LOGIC;
            rst                   : in  STD_LOGIC;
            filter_inc_z          : in  STD_LOGIC;
            filter_inc_x          : in  STD_LOGIC;
            filter_inc_y          : in  STD_LOGIC;
            convolution_step_done : in  STD_LOGIC;
            act_x_z_slice_size    : in  STD_LOGIC_VECTOR(log_2(MAX_ACT_WIDTH * MAX_ACT_DEPTH / ACT_IND_WIDTH) - 1 downto 0);
            row_offset            : out STD_LOGIC_VECTOR(log_2(MAX_FILTER_WIDTH * MAX_FILTER_DEPTH / ACT_IND_WIDTH) - 1 downto 0);
            col_offset            : out STD_LOGIC_VECTOR(log_2(MAX_ACT_DEPTH * MAX_ACT_WIDTH * MAX_FILTER_HEIGHT / ACT_IND_WIDTH) - 1 downto 0)
        );
    end component;
    
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
    
    --------------------------------------
    -- Current layer activation address --
    --------------------------------------
    -- Values
    signal act_step_base : STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS / ACT_IND_WIDTH) - 1 downto 0);
    signal row_offset    : STD_LOGIC_VECTOR(log_2(MAX_FILTER_WIDTH * MAX_FILTER_DEPTH / ACT_IND_WIDTH) - 1 downto 0);
    signal col_offset    : STD_LOGIC_VECTOR(log_2(MAX_ACT_DEPTH * MAX_ACT_WIDTH * MAX_FILTER_HEIGHT / ACT_IND_WIDTH) - 1 downto 0);
    -- Indices
    signal ind_act_step_base     : STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS / ACT_IND_WIDTH) - 1 downto 0);
    signal ind_row_offset        : STD_LOGIC_VECTOR(log_2(MAX_FILTER_WIDTH * MAX_FILTER_DEPTH / ACT_IND_WIDTH) - 1 downto 0);
    signal ind_col_offset        : STD_LOGIC_VECTOR(log_2(MAX_ACT_DEPTH * MAX_ACT_WIDTH * MAX_FILTER_HEIGHT / ACT_IND_WIDTH) - 1 downto 0);
    signal ind_section_beginning : STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS / ACT_IND_WIDTH) - 1 downto 0);    
    
    -----------------------------------------------
    -- Next layer activation address accumulator --
    -----------------------------------------------
    signal new_act_values_addr_current : STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS) - 1 downto 0);
    signal new_act_values_addr_next    : STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS) - 1 downto 0);
begin
    --------------------------------------
    -- Current layer activation address --
    --------------------------------------
    -- Values addressing
    act_val_addr <= std_logic_vector(unsigned(act_base)) & std_logic_vector(unsigned(act_section_offset));
                      
    -- Indices addressing
    ind_act_step_base_I: step_base
        port map(
            clk                => clk,
            rst                => rst,
            start_convolution  => start_convolution,
            act_inc_x          => ind_act_inc_x,
            filter_depth       => filter_depth(log_2(MAX_FILTER_DEPTH) - 1 downto log_2(ACT_IND_WIDTH)),
            act_inc_y          => ind_act_inc_y,
            act_x_z_slice_size => act_x_z_slice_size(log_2(MAX_ACT_WIDTH * MAX_ACT_DEPTH) - 1 downto log_2(ACT_IND_WIDTH)),
            act_step_base      => ind_act_step_base
        );

    ind_filter_offset_I: filter_offset
        port map(
            clk                   => clk,
            rst                   => rst,
            filter_inc_z          => ind_filter_inc_z,
            filter_inc_x          => ind_filter_inc_x,
            filter_inc_y          => ind_filter_inc_y,
            convolution_step_done => ind_convolution_step_done,
            act_x_z_slice_size    => act_x_z_slice_size(log_2(MAX_ACT_WIDTH * MAX_ACT_DEPTH) - 1 downto log_2(ACT_IND_WIDTH)),
            row_offset            => ind_row_offset,
            col_offset            => ind_col_offset
        );

    -----------------------------------
    -- Next layer activation address --
    -----------------------------------
    new_act_values_pos: reg generic map(bits => log_2(MAX_ACT_ELEMENTS))
        port map(clk, rst OR start_convolution, convolution_step_done, new_act_values_addr_next, new_act_values_addr_current);
    
    new_act_values_addr_next <= new_act_values_addr_current + filters_no;    
    
    -------------
    -- Outputs --
    -------------
    new_act_val_addr <= new_act_values_addr_current;
    act_ind_addr     <= resize(ind_act_step_base + (ind_row_offset + ind_col_offset), log_2(MAX_ACT_ELEMENTS / ACT_IND_WIDTH));
end act_addrs_generator_arch;