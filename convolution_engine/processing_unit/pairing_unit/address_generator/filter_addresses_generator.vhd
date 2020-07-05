library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity filter_addrs_generator is
    port(
        clk                       : in  STD_LOGIC;
        rst                       : in  STD_LOGIC;
        convolution_step_done     : in  STD_LOGIC;
        ind_granted               : in  STD_LOGIC;         
        match_processed           : in  STD_LOGIC;
        last_match                : in  STD_LOGIC;
        no_match                  : in  STD_LOGIC;
        filter_jump               : in  STD_LOGIC_VECTOR(log_2(SECTION_WIDTH + 1) - 1 downto 0);
        filter_rest               : in  STD_LOGIC_VECTOR(log_2(SECTION_WIDTH + 1) - 1 downto 0);
        ind_convolution_step_done : in  STD_LOGIC;
        filter_ind_addr           : out STD_LOGIC_VECTOR(log_2(MAX_FILTER_ELEMENTS / FILTER_IND_WIDTH) - 1 downto 0);
        filter_val_addr           : out STD_LOGIC_VECTOR(log_2(MAX_FILTER_ELEMENTS) - 1 downto 0)
    );
end filter_addrs_generator;

architecture filter_addrs_generator_arch of filter_addrs_generator is
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
    
    component counter
        generic(
            bits : positive := 2;
            step : positive := 1
        );
        port(
            clk   : in  STD_LOGIC;
            rst   : in  STD_LOGIC;
            rst_2 : in  STD_LOGIC;
            inc   : in  STD_LOGIC;
            count : out STD_LOGIC_VECTOR(bits - 1 downto 0)
        );
    end component;
    
    -- Accumulator for filter values addr
    signal new_filter_values_addr : STD_LOGIC_VECTOR(log_2(MAX_FILTER_ELEMENTS) - 1 downto 0);
    signal filter_values_addr_int : STD_LOGIC_VECTOR(log_2(MAX_FILTER_ELEMENTS) - 1 downto 0);
begin
    --------------------------------------
    -- Accumulators for filter addrs --
    --------------------------------------
    -- Indices
    filter_ind_addr_count: counter generic map(bits => log_2(MAX_FILTER_ELEMENTS / FILTER_IND_WIDTH),
                                               step => 1)
        port map(clk, rst, ind_convolution_step_done, ind_granted, filter_ind_addr);

    -- Values
    filter_values_addr_count: reg generic map(bits => log_2(MAX_FILTER_ELEMENTS))
        port map(clk, rst OR convolution_step_done, match_processed OR no_match, new_filter_values_addr, filter_values_addr_int);

    new_filter_values_addr <= std_logic_vector(unsigned(filter_values_addr_int) +
                              (unsigned(filter_jump) + unsigned(filter_rest)))    when last_match = '1' OR no_match = '1' else
                              std_logic_vector(unsigned(filter_values_addr_int) +
                              unsigned(filter_jump));
                                 
    -- Output
    filter_val_addr <= std_logic_vector(unsigned(filter_values_addr_int) + (unsigned(filter_jump) - 1));
end filter_addrs_generator_arch;