library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity filter_offset is
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
end filter_offset;

architecture filter_offset_arch of filter_offset is
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
    
    -- Filter row offset
    signal rst_filter_row_offset  : STD_LOGIC;
    signal load_filter_row_offset : STD_LOGIC;
    signal row_offset_int         : STD_LOGIC_VECTOR(log_2(MAX_FILTER_DEPTH * MAX_FILTER_WIDTH / ACT_IND_WIDTH) - 1 downto 0);
    
    -- Filter col offset
    signal col_offset_int : STD_LOGIC_VECTOR(log_2(MAX_ACT_DEPTH * MAX_ACT_WIDTH * MAX_FILTER_HEIGHT / ACT_IND_WIDTH) - 1 downto 0);
begin
    -----------------------
    -- Filter row offset --
    -----------------------
    filter_row_offset: reg generic map(bits => log_2(MAX_FILTER_WIDTH * MAX_FILTER_DEPTH / ACT_IND_WIDTH))
        port map(clk, rst_filter_row_offset, load_filter_row_offset, row_offset_int + 1, row_offset_int);

    rst_filter_row_offset  <= rst                   OR
                              filter_inc_y          OR
                              convolution_step_done;
    
    load_filter_row_offset <= filter_inc_z OR
                              filter_inc_x;
    
    -----------------------
    -- Filter col offset --
    -----------------------
    filter_col_offset: reg generic map(bits => log_2(MAX_ACT_DEPTH * MAX_ACT_WIDTH * MAX_FILTER_HEIGHT / ACT_IND_WIDTH))
        port map(clk, rst OR convolution_step_done, filter_inc_y, col_offset_int + act_x_z_slice_size, col_offset_int);

    -------------
    -- Outputs --
    -------------
    row_offset <= row_offset_int;
    col_offset <= col_offset_int;
end filter_offset_arch;