library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity match_buffer is
    port(
        clk : in std_logic;
        rst : in std_logic;
        -----------------------------
        -- matching_unit interface --
        -----------------------------
        new_pair_ready : in STD_LOGIC;
        ------------------------------
        -- addr_generator interface --
        ------------------------------
        filter_addr      : in  STD_LOGIC_VECTOR(log_2(MAX_FILTER_ELEMENTS) - 1 downto 0);
        act_addr         : in  STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS) - 1 downto 0);
        new_act_addr     : in  STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS) - 1 downto 0);
        new_act_addr_out : out STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS) - 1 downto 0);
        -----------------------------
        -- pair_selector interface --
        -----------------------------
        pair_taken   : in  STD_LOGIC_VECTOR(PAIRING_BUFFER_DEPTH - 1 downto 0);
        filter_addrs : out tp_match_buffer_filter;
        act_addrs    : out tp_match_buffer_act;
        ----------
        -- Misc --
        ----------
        last_pair_step        : in  STD_LOGIC;
        last_pair             : in  STD_LOGIC;
        buffer_full           : out STD_LOGIC;
        convolution_step_done : out STD_LOGIC;
        convolution_done      : out STD_LOGIC;
        ---------------------------------------
        -- act_values_read_arbiter interface --
        ---------------------------------------
        pairs : out STD_LOGIC_VECTOR(PAIRING_BUFFER_DEPTH - 1 downto 0)
    );
end match_buffer;

architecture match_buffer_arch of match_buffer is
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

    component priority_encoder
        generic(
            input_width : natural := 2
        );
        port(
            input    : in  STD_LOGIC_VECTOR(input_width - 1 downto 0);
            found    : out STD_LOGIC;
            position : out STD_LOGIC_VECTOR(log_2(input_width) - 1 downto 0)
        );
    end component;
    
    component D_flip_flop
        port(
            clk  : in  STD_LOGIC;
            rst  : in  STD_LOGIC;
            ld   : in  STD_LOGIC;
            din  : in  STD_LOGIC;
            dout : out STD_LOGIC
        );
    end component;

    component t_flip_flop
        port(
            clk    : in  STD_LOGIC;
            rst    : in  STD_LOGIC;
            toggle : in  STD_LOGIC;
            dout   : out STD_LOGIC
        );
    end component;    

    component match_buffer_controller
        port(
            clk                   : in STD_LOGIC;
            rst                   : in STD_LOGIC;
            last_pair_step        : in STD_LOGIC;
            last_pair             : in STD_LOGIC;         
            last_taken            : in STD_LOGIC;
            toggle_input          : out STD_LOGIC;
            toggle_output         : out STD_LOGIC;
            convolution_step_done : out STD_LOGIC;
            convolution_done      : out STD_LOGIC
        );
    end component;

    -- Buffer
    signal ld_buffer     : STD_LOGIC_VECTOR(PAIRING_BUFFER_DEPTH - 1 downto 0);    
    signal ld_any_buffer : STD_LOGIC;
    
    -- Pairs available
    signal rst_pairs_available : STD_LOGIC_VECTOR(PAIRING_BUFFER_DEPTH - 1 downto 0);    
    signal pairs_available     : STD_LOGIC_VECTOR(PAIRING_BUFFER_DEPTH - 1 downto 0);
    
    -- Free position selection
    signal pairs_available_masked : STD_LOGIC_VECTOR(PAIRING_BUFFER_DEPTH - 1 downto 0);
    signal free_position_found    : STD_LOGIC;
    signal last_taken             : STD_LOGIC;
    signal free_position          : STD_LOGIC_VECTOR(log_2(PAIRING_BUFFER_DEPTH) - 1 downto 0);

    -- Mixed Convolutions
    signal input_conv_no      : STD_LOGIC;
    signal output_conv_no     : STD_LOGIC;
    signal ld_addr_conv_0     : STD_LOGIC;
    signal ld_addr_conv_1     : STD_LOGIC;
    signal prevent_3_convs    : STD_LOGIC;
    signal ld_prevent_3_convs : STD_LOGIC;

    signal conv_no        : STD_LOGIC_VECTOR(PAIRING_BUFFER_DEPTH - 1 downto 0);    
    signal new_act_conv_0 : STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS) - 1 downto 0);
    signal new_act_conv_1 : STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS) - 1 downto 0);

    signal toggle_input              : STD_LOGIC;
    signal toggle_output             : STD_LOGIC;
    signal reset_pairs_available_reg : STD_LOGIC;
    signal reset_prevent_3_convs_reg : STD_LOGIC;
    signal int_convolution_step_done : STD_LOGIC;
    signal int_convolution_done      : STD_LOGIC;
    
    signal valid_pair        : STD_LOGIC_VECTOR(PAIRING_BUFFER_DEPTH - 1 downto 0);
    signal valid_pair_masked : STD_LOGIC_VECTOR(PAIRING_BUFFER_DEPTH - 1 downto 0);
begin
    ------------
    -- Buffer --
    ------------
    addrs_buffer: for i in 0 to PAIRING_BUFFER_DEPTH - 1 generate        
        ld_buffer(i) <= '1' when free_position_found    = '1' AND
                                 new_pair_ready         = '1' AND
                                 to_uint(free_position) = i   AND
                                 prevent_3_convs        = '0' else 
                        '0';
        
       -- Filter addr
        filter_buffer : reg generic map(bits => log_2(MAX_FILTER_ELEMENTS))
            port map(clk, rst, ld_buffer(i), filter_addr, filter_addrs(i));
        
        -- Activation addr
        act_buffer : reg generic map(bits => log_2(MAX_ACT_ELEMENTS))
            port map(clk, rst, ld_buffer(i), act_addr, act_addrs(i));        
        
        -- The buffers support mixing two different convolutions.
        -- This registers identify whether the pair belongs to convolution #0 or #1
        conv_no_reg : D_flip_flop
            port map(clk, rst, ld_buffer(i), input_conv_no, conv_no(i));
     end generate;
    
    -- New act addr (convolution #0)
    new_act_addr_conv_0: reg generic map(bits => log_2(MAX_ACT_ELEMENTS))
        port map(clk, rst, ld_addr_conv_0, new_act_addr, new_act_conv_0);
        
    -- New act addr (convolution #1)
    new_act_addr_conv_1: reg generic map(bits => log_2(MAX_ACT_ELEMENTS))
        port map(clk, rst, ld_addr_conv_1, new_act_addr, new_act_conv_1);

    new_act_addr_out <= new_act_conv_0 when output_conv_no = '0' else
                        new_act_conv_1;

    ---------------------
    -- Pairs available --
    ---------------------
    pairs_available_ctrl : for i in 0 to PAIRING_BUFFER_DEPTH - 1 generate
        -- Valid pair indicates that valid information is stored (can be from the current convolution or from the next one)
        pairs_available_reg : D_flip_flop
            port map(clk, rst_pairs_available(i), ld_buffer(i), '1', valid_pair(i));        
        
        rst_pairs_available(i) <= rst OR (pair_taken(i) AND NOT ld_buffer(i));
        
        -- Pair available indicates which pairs store valid data for the convolution being processed
        pairs_available(i) <= '1' when valid_pair(i) = '1' AND conv_no(i) = output_conv_no else '0';
    end generate;
    
    -- Two additional registers identify which one is the current convolution,
    -- and if the incoming pairs belong to the current convolution or to the next one
    -- #convolution belongs the pairs received
    t_conv_input_reg: t_flip_flop
        port map(toggle_input, clk, rst, input_conv_no);
           
    -- #convolution under processing
    processing_conv_reg: t_flip_flop
        port map(toggle_output, clk, rst, output_conv_no);
    
    ld_any_buffer  <= '1' when ld_buffer /= std_logic_vector(to_unsigned(0, PAIRING_BUFFER_DEPTH)) else '0';
    ld_addr_conv_0 <= '1' when ld_any_buffer = '1' AND input_conv_no = '0' else '0';                                
    ld_addr_conv_1 <= '1' when ld_any_buffer = '1' AND input_conv_no = '1' else '0';    
             
    -- Prevent three convolutions mixed at the same time
    prevent_3_convs <= '1' when input_conv_no /= output_conv_no           AND
                                (last_pair = '1' OR last_pair_step = '1') else
                       '0';

    --------------------------------------------------------
    -- Selection of the free position to store a new pair --
    --------------------------------------------------------    
    -- Mask current pair taken (if exists) in the valid list (used to select a free position)
    valid_pair_mask: for i in 0 to PAIRING_BUFFER_DEPTH - 1 generate
        valid_pair_masked(i) <= valid_pair(i) AND NOT pair_taken(i);
    end generate;
    
    -- Mask current pair taken (if exists) in the avaliable list (used to identify when the last pair of the current convolution is selected)
    pairs_available_mask: for i in 0 to PAIRING_BUFFER_DEPTH - 1 generate
        pairs_available_masked(i) <= pairs_available(i) AND NOT(pair_taken(i));
    end generate;
    
    -- Selection
    free_position_selector: priority_encoder
        generic map(
            input_width => PAIRING_BUFFER_DEPTH
        )
        port map(
            input    => NOT(valid_pair_masked),
            found    => free_position_found,
            position => free_position
        );

    match_buffer_controller_I: match_buffer_controller
        port map(
            clk                   => clk,
            rst                   => rst,
            last_pair_step        => last_pair_step,
            last_pair             => last_pair,
            last_taken            => last_taken,
            toggle_input          => toggle_input,
            toggle_output         => toggle_output,
            convolution_step_done => int_convolution_step_done,
            convolution_done      => int_convolution_done
        );
        
    last_taken <= '1' when pairs_available_masked = std_logic_vector(to_unsigned(0, PAIRING_BUFFER_DEPTH)) else '0';    
    
    -------------
    -- Outputs --
    -------------
    -- Block pipeline whether the match buffer is full or there is risk of mixing three different convolution steps
    --buffer_full <= NOT(free_position_found) OR prevent_3_convs;
    buffer_full <= NOT(free_position_found);    
    
    pairs                 <= pairs_available;    
    convolution_step_done <= int_convolution_step_done;
    convolution_done      <= int_convolution_done;
end match_buffer_arch;