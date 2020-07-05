library ieee;
use ieee.std_logic_1164.ALL;
use work.types.all;

entity convolution_controller is
    port(
        clk : in STD_LOGIC;
        rst : in STD_LOGIC;
        ----------------------------------
        -- act_values_manager interface --
        ----------------------------------
        act_height    : in STD_LOGIC_VECTOR(log_2(MAX_ACT_HEIGHT) - 1 downto 0);
        act_width     : in STD_LOGIC_VECTOR(log_2(MAX_ACT_WIDTH) - 1 downto 0);
        ------------------------------
        -- filter_manager interface --
        ------------------------------
        filter_height : in STD_LOGIC_VECTOR(log_2(MAX_FILTER_HEIGHT) - 1 downto 0);
        filter_width  : in STD_LOGIC_VECTOR(log_2(MAX_FILTER_WIDTH) - 1 downto 0);
        filter_depth  : in STD_LOGIC_VECTOR(log_2(MAX_FILTER_DEPTH) - 1 downto 0);
        -------------------------------
        -- act_ind_arbiter interface --
        -------------------------------
        ind_granted : in STD_LOGIC;
        ---------------------------------
        -- address_generator interface --
        ---------------------------------
        filter_inc_x : out STD_LOGIC;
        filter_inc_y : out STD_LOGIC;
        filter_inc_z : out STD_LOGIC;
        act_inc_x    : out STD_LOGIC;
        act_inc_y    : out STD_LOGIC;
        ----------
        -- Misc --
        ----------
        convolution_step_done : out STD_LOGIC;
        convolution_done      : out STD_LOGIC
    );
end convolution_controller;

architecture convolution_controller_arch of convolution_controller is    
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
    
    -- Convolution coordinates    
    signal rst_filter_x, inc_filter_x : STD_LOGIC;
    signal rst_filter_y, inc_filter_y : STD_LOGIC;
    signal rst_filter_z, inc_filter_z : STD_LOGIC;
    signal filter_x_int : STD_LOGIC_VECTOR(log_2(MAX_FILTER_HEIGHT) - 1 downto 0);
    signal filter_y_int : STD_LOGIC_VECTOR(log_2(MAX_FILTER_WIDTH) - 1 downto 0);
    signal filter_z_int : STD_LOGIC_VECTOR(log_2(MAX_FILTER_DEPTH / FILTER_IND_WIDTH) - 1 downto 0);
    
    signal rst_act_base_x, inc_act_base_x : STD_LOGIC;
    signal rst_act_base_y, inc_act_base_y : STD_LOGIC;
    signal act_base_x : STD_LOGIC_VECTOR(log_2(MAX_ACT_HEIGHT) - 1 downto 0);
    signal act_base_y : STD_LOGIC_VECTOR(log_2(MAX_ACT_WIDTH) - 1 downto 0);
    
    signal act_x_int : STD_LOGIC_VECTOR(log_2(MAX_ACT_HEIGHT) - 1 downto 0);
    signal act_y_int : STD_LOGIC_VECTOR(log_2(MAX_ACT_WIDTH) - 1 downto 0);
    
    -- Endings
    signal filter_x_done : STD_LOGIC;
    signal filter_y_done : STD_LOGIC;
    signal filter_z_done : STD_LOGIC;
    signal act_x_done    : STD_LOGIC;
    signal act_y_done    : STD_LOGIC;
begin
    -----------------------------
    -- Convolution coordinates --
    -----------------------------
    -- Filter coordinates
    filter_x_I: counter generic map(log_2(MAX_FILTER_HEIGHT))
        port map(clk, rst, rst_filter_x, inc_filter_x, filter_x_int);        
    filter_y_I: counter generic map(log_2(MAX_FILTER_WIDTH))
        port map(clk, rst, rst_filter_y, inc_filter_y, filter_y_int);
    filter_z_I: counter generic map(log_2(MAX_FILTER_DEPTH / FILTER_IND_WIDTH))
        port map(clk, rst, rst_filter_z, inc_filter_z, filter_z_int);    
    
    -- Activation base coordinates
    act_base_x_I: counter generic map(log_2(MAX_ACT_HEIGHT))
        port map(clk, rst, rst_act_base_x, inc_act_base_x, act_base_x);
    act_base_y_I: counter generic map(log_2(MAX_ACT_WIDTH))
        port map(clk, rst, rst_act_base_y, inc_act_base_y, act_base_y);
    
    -- Activation coordinates
    act_x_int <= act_base_x + filter_x_int;
    act_y_int <= act_base_y + filter_y_int;
    
    -- Convolution controller
    filter_z_done <= '1' when filter_z_int = filter_depth(log_2(MAX_FILTER_DEPTH) - 1 downto log_2(FILTER_IND_WIDTH)) - 1 else '0';
    filter_x_done <= '1' when filter_x_int = filter_width  else '0';
    filter_y_done <= '1' when filter_y_int = filter_height else '0';
    
    act_x_done <= '1' when act_x_int = act_width  else '0';
    act_y_done <= '1' when act_y_int = act_height else '0';
    
    inc_filter_z <= ind_granted AND NOT filter_z_done;
    inc_filter_x <= ind_granted AND filter_z_done AND NOT filter_x_done;
    inc_filter_y <= ind_granted AND filter_z_done AND filter_x_done AND NOT filter_y_done;
    
    rst_filter_z <= ind_granted AND filter_z_done;
    rst_filter_x <= ind_granted AND filter_z_done AND filter_x_done;
    rst_filter_y <= ind_granted AND filter_z_done AND filter_x_done AND filter_y_done;

    inc_act_base_x <= ind_granted AND filter_x_done AND filter_y_done AND filter_z_done AND NOT act_x_done;
    inc_act_base_y <= ind_granted AND filter_x_done AND filter_y_done AND filter_z_done AND act_x_done AND NOT act_y_done;
    
    rst_act_base_x <= ind_granted AND filter_x_done AND filter_y_done AND filter_z_done AND act_x_done;
    rst_act_base_y <= ind_granted AND filter_x_done AND filter_y_done AND filter_z_done AND act_x_done AND act_y_done;

    convolution_step_done <= ind_granted AND filter_x_done AND filter_y_done AND filter_z_done;
    convolution_done      <= ind_granted AND filter_x_done AND filter_y_done AND filter_z_done AND act_x_done AND act_y_done;
    
    --------------    
    -- Outputs ---
    --------------
    filter_inc_x <= inc_filter_x;
    filter_inc_y <= inc_filter_y;
    filter_inc_z <= inc_filter_z;
    act_inc_x    <= inc_act_base_x;
    act_inc_y    <= inc_act_base_y;
end convolution_controller_arch;