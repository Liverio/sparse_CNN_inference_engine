library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity pair_selector is
    generic(
        unit_no : natural := 0
    );
    port(
        clk : in STD_LOGIC;
        rst : in STD_LOGIC;
        ------------------------------
        -- filter_manager interface --
        ------------------------------
        filter_val_element : out STD_LOGIC_VECTOR(log_2(MAX_FILTER_ELEMENTS) - 1 downto 0);
        ----------------------------
        -- pairing_unit interface --
        ----------------------------
        filter_val_element_no : in  tp_match_buffer_filter;
        act_val_element_no    : in  tp_match_buffer_act;
        -- One-hot encoded request served
        pair_taken              : out STD_LOGIC_VECTOR(PAIRING_BUFFER_DEPTH - 1 downto 0);
        ------------------------------------
        -- act_val_read_arbiter interface --
        ------------------------------------
        bank_no        : out tp_request_set;
        request_served : in  STD_LOGIC;
        request_no     : in  STD_LOGIC_VECTOR(log_2(PAIRING_BUFFER_DEPTH) - 1 downto 0);
        -----------------------------------
        -- act_values_crossbar interface --
        -----------------------------------
        act_val_bank : out STD_LOGIC_VECTOR(log_2(ACT_VAL_BANKS) - 1 downto 0);
        act_val_addr : out STD_LOGIC_VECTOR(ACT_VAL_BANK_ADDRESS_SIZE - 1 downto 0)
    );
end pair_selector;

architecture pair_selector_arch of pair_selector is    
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
    
    constant BANK_ADDRESS_SIZE         : positive := log_2(ACT_VAL_BRAMS_PER_BANK) + addr_width(ACT_VAL_WIDTH);
    constant FILTER_ADDRESS_SIZE       : positive := log_2(FILTER_VAL_BRAMS_PER_BANK) + addr_width(FILTER_VAL_WIDTH);
    signal bank_no_int                 : tp_request_set;
    signal full_act_val_addr           : STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS) - 1 downto 0);
    signal full_filter_val_addr        : STD_LOGIC_VECTOR(log_2(MAX_FILTER_ELEMENTS) - 1 downto 0);
    signal act_val_bank_selected       : STD_LOGIC_VECTOR(log_2(ACT_VAL_BANKS) - 1 downto 0);
    signal act_val_addr_selected       : STD_LOGIC_VECTOR(ACT_VAL_BANK_ADDRESS_SIZE - 1 downto 0);
    signal filter_val_element_selected : STD_LOGIC_VECTOR(log_2(MAX_FILTER_ELEMENTS) - 1 downto 0);
begin
    ------------------------------------
    -- act_val_read_arbiter interface --
    ------------------------------------
    -- Select bank_no from addrs
    requests: for i in 0 to PAIRING_BUFFER_DEPTH - 1 generate
        -- #bank of each request passed to act value read arbiter in order to select a feasible request
        bank_no_int(i) <= act_val_element_no(i)(log_2(ACT_VAL_BANKS) - 1 downto 0);        
        bank_no(i)     <= bank_no_int(i);
    end generate;
    
    -------------------------------
    -- act_val_manager interface --
    -------------------------------
    full_act_val_addr    <= act_val_element_no(to_uint(request_no));
    full_filter_val_addr <= filter_val_element_no(to_uint(request_no));
    
    -- Activation & filter addr of the request selected
    act_val_bank_selected       <= bank_no_int(to_uint(request_no));
    act_val_addr_selected       <= full_act_val_addr(BANK_ADDRESS_SIZE + log_2(ACT_VAL_BANKS) - 1 downto log_2(ACT_VAL_BANKS));
    filter_val_element_selected <= full_filter_val_addr;
    
    --------------
    -- Pipeline --
    --------------
    pipeline_arch: if unit_no /= 0 generate
        type tp_pipeline_info is
            array(unit_no downto 1) of STD_LOGIC_VECTOR(log_2(ACT_VAL_BANKS) + ACT_VAL_BANK_ADDRESS_SIZE + log_2(MAX_FILTER_ELEMENTS) - 1 downto 0);
        signal pipeline       : tp_pipeline_info;
        signal pipeline_input : STD_LOGIC_VECTOR(log_2(ACT_VAL_BANKS) + ACT_VAL_BANK_ADDRESS_SIZE + log_2(MAX_FILTER_ELEMENTS) - 1 downto 0);
    begin
        pipeline_stages: for i in unit_no downto 1 generate
            first: if i = unit_no generate
                -- Bank no + @act + @filter
                pipeline_info: reg generic map(bits => log_2(ACT_VAL_BANKS) + ACT_VAL_BANK_ADDRESS_SIZE + log_2(MAX_FILTER_ELEMENTS))
                    port map(clk, rst, '1', pipeline_input, pipeline(i));
                
                pipeline_input <= act_val_bank_selected & act_val_addr_selected & filter_val_element_selected;
            end generate;
            
            remaining: if i /= unit_no generate
                pipeline_info: reg generic map(bits => log_2(ACT_VAL_BANKS) + ACT_VAL_BANK_ADDRESS_SIZE + log_2(MAX_FILTER_ELEMENTS))
                    port map(clk, rst, '1', pipeline(i + 1), pipeline(i));
            end generate;
        end generate;
        
        -- Outputs
        act_val_bank       <= pipeline(1)(log_2(ACT_VAL_BANKS)           +
                                            ACT_VAL_BANK_ADDRESS_SIZE      +
                                            log_2(MAX_FILTER_ELEMENTS) - 1   downto ACT_VAL_BANK_ADDRESS_SIZE +
                                                                                    log_2(MAX_FILTER_ELEMENTS));
        act_val_addr       <= pipeline(1)(ACT_VAL_BANK_ADDRESS_SIZE      +
                                            log_2(MAX_FILTER_ELEMENTS) - 1   downto log_2(MAX_FILTER_ELEMENTS));

        filter_val_element <= pipeline(1)(log_2(MAX_FILTER_ELEMENTS) - 1   downto 0);
    end generate;    
    
    last_stage: if unit_no = 0 generate
        act_val_bank       <= act_val_bank_selected;
        act_val_addr       <= act_val_addr_selected;
        filter_val_element <= filter_val_element_selected;
    end generate;

    ----------------
    -- To pairing --
    ----------------
    -- Decoder for the request served
    decoder: for i in 0 to PAIRING_BUFFER_DEPTH - 1 generate
        pair_taken(i) <= '1' when i = to_uint(request_no) AND request_served = '1' else '0';
    end generate;
end pair_selector_arch;