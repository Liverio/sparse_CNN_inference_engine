library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.std_logic_unsigned.all;
use work.types.all;

entity processing_unit is
    generic(
        unit_no    : natural  := 0;
        bank_depth : positive := 8;
        mem_width  : positive := AXIS_BUS_WIDTH;
        data_width : positive := ACT_VAL_WIDTH
    );
    port(
        clk : in STD_LOGIC;
        rst : in STD_LOGIC;
        ------------------------------ 
        -- Filter storage interface --
        ------------------------------
        store_filter_ind : in STD_LOGIC;
        store_filter_val : in STD_LOGIC;
        new_data         : in STD_LOGIC;
        filter_input     : in STD_LOGIC_VECTOR(AXIS_BUS_WIDTH - 1 downto 0);
        ---------------------------------------------
        -- convolution_engine_controller interface --
        ---------------------------------------------
        start_convolution : in  STD_LOGIC;
        filter_ind_stored : out STD_LOGIC;
        filter_val_stored : out STD_LOGIC;
        convolution_done  : out STD_LOGIC;
        ----------------------------------
        -- act_values_manager interface --
        ----------------------------------
        act_height         : in STD_LOGIC_VECTOR(log_2(MAX_ACT_HEIGHT) - 1 downto 0);
        act_width          : in STD_LOGIC_VECTOR(log_2(MAX_ACT_WIDTH)  - 1 downto 0);
        act_x_z_slice_size : in STD_LOGIC_VECTOR(log_2(MAX_ACT_WIDTH * MAX_ACT_DEPTH) - 1 downto 0);
        -------------------------------
        -- act_ind_arbiter interface --
        -------------------------------
        act_ind_request       : out STD_LOGIC_VECTOR(log_2(ACT_IND_BRAMS_PER_BANK) + addr_width(ACT_IND_WIDTH) + log_2(ACT_IND_BANKS) - 1 downto 0);
        act_ind_request_valid : out STD_LOGIC;
        act_ind_granted       : in  STD_LOGIC;
        act_ind_served        : in  STD_LOGIC;
        act_ind               : in  STD_LOGIC_VECTOR(ACT_IND_WIDTH - 1 downto 0);
        -----------------------------------
        -- act_values_crossbar interface --
        -----------------------------------
        act_val_bank : out STD_LOGIC_VECTOR(log_2(ACT_VAL_BANKS) - 1 downto 0);
        act_val_addr : out STD_LOGIC_VECTOR(ACT_VAL_BANK_ADDRESS_SIZE - 1 downto 0);
        act_val      : in  STD_LOGIC_VECTOR(ACT_VAL_WIDTH - 1 downto 0);
        ---------------------------------------
        -- act_values_read_arbiter interface --
        ---------------------------------------
        act_val_requests_bank_no : out tp_request_set;
        act_val_request_valid    : out STD_LOGIC_VECTOR(PAIRING_BUFFER_DEPTH - 1 downto 0);
        request_served           : in  STD_LOGIC;
        request_no               : in  STD_LOGIC_VECTOR(log_2(PAIRING_BUFFER_DEPTH) - 1 downto 0);
        ----------------------------------------
        -- act_values_write_arbiter interface --
        ----------------------------------------
        new_val                : out STD_LOGIC;
        new_act_val            : out STD_LOGIC_VECTOR(ACT_VAL_WIDTH - 1 downto 0);
        new_act_val_element_no : out STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS) - 1 downto 0);
        new_act_val_written    : in  STD_LOGIC
    );
end processing_unit;  
           
architecture processing_unit_arch of processing_unit is
    component filter_manager
        generic(
            max_elements : positive := MAX_FILTER_ELEMENTS;
            bank_depth   : positive := 2;
            mem_width    : positive := AXIS_BUS_WIDTH;
            data_width   : positive := FILTER_VAL_WIDTH
        );
        port(
            clk : in STD_LOGIC;
            rst : in STD_LOGIC;
            ------------------------------
            -- Filter storage interface --
            ------------------------------
            store_filter  : in  STD_LOGIC;
            new_data      : in  STD_LOGIC;         
            filter_input  : in  STD_LOGIC_VECTOR(AXIS_BUS_WIDTH - 1 downto 0);
            filter_stored : out STD_LOGIC;
            -----------------------------
            -- Pair selector interface --
            -----------------------------
            read_element_no : in STD_LOGIC_VECTOR(log_2(max_elements) - 1 downto 0);
            ----------------------------
            -- Pairing unit interface --
            ----------------------------
            filters_no    : out STD_LOGIC_VECTOR(log_2(MAX_FILTERS) - 1 downto 0);         
            filter_height : out STD_LOGIC_VECTOR(log_2(MAX_FILTER_HEIGHT) - 1 downto 0);
            filter_width  : out STD_LOGIC_VECTOR(log_2(MAX_FILTER_WIDTH) - 1 downto 0);
            filter_depth  : out STD_LOGIC_VECTOR(log_2(MAX_FILTER_DEPTH) - 1 downto 0);
            -----------------------------
            -- MAC processor interface --
            -----------------------------
            filter_output : out STD_LOGIC_VECTOR(data_width - 1 downto 0)
        );
    end component;
    
    component pair_selector
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
    end component;
    
    component pairing_unit
        port(
            clk : in STD_LOGIC;
            rst : in STD_LOGIC;
            ------------------------------------------
            -- processing_unit_controller interface --
            ------------------------------------------
            start_convolution     : in  STD_LOGIC;
            convolution_step_done : out STD_LOGIC;
            convolution_done      : out STD_LOGIC;
            ----------------------------------
            -- act_values_manager interface --
            ----------------------------------
            act_height         : in STD_LOGIC_VECTOR(log_2(MAX_ACT_HEIGHT) - 1 downto 0);
            act_width          : in STD_LOGIC_VECTOR(log_2(MAX_ACT_WIDTH) - 1 downto 0);
            act_x_z_slice_size : in STD_LOGIC_VECTOR(log_2(MAX_ACT_WIDTH * MAX_ACT_DEPTH) - 1 downto 0);
            ------------------------------
            -- filter_manager interface --
            ------------------------------
            filter_height : in STD_LOGIC_VECTOR(log_2(MAX_FILTER_HEIGHT) - 1 downto 0);
            filter_width  : in STD_LOGIC_VECTOR(log_2(MAX_FILTER_WIDTH) - 1 downto 0);
            filter_depth  : in STD_LOGIC_VECTOR(log_2(MAX_FILTER_DEPTH) - 1 downto 0);
            filter_no     : in STD_LOGIC_VECTOR(log_2(MAX_FILTERS) - 1 downto 0);
            filters_no    : in STD_LOGIC_VECTOR(log_2(MAX_FILTERS) - 1 downto 0);
            -------------------------------
            -- act_ind_arbiter interface --
            -------------------------------
            request_ind  : out STD_LOGIC;
            act_ind_addr : out STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS / ACT_IND_WIDTH) - 1 downto 0);
            ind_granted  : in  STD_LOGIC;
            ind_served   : in  STD_LOGIC;
            act_ind      : in  STD_LOGIC_VECTOR(ACT_IND_WIDTH - 1 downto 0);
            ----------------------------------
            -- filter_ind_manager interface --
            ----------------------------------
            filter_ind_addr : out STD_LOGIC_VECTOR(log_2(MAX_FILTER_ELEMENTS / FILTER_IND_WIDTH) - 1 downto 0);
            filter_ind      : in  STD_LOGIC_VECTOR(FILTER_IND_WIDTH - 1 downto 0);
            -----------------------------
            -- pair_selector interface --
            -----------------------------
            filter_addrs : out tp_match_buffer_filter;
            act_addrs    : out tp_match_buffer_act;
            pair_taken   : in  STD_LOGIC_VECTOR(PAIRING_BUFFER_DEPTH - 1 downto 0);
            ---------------------------------------
            -- act_values_read_arbiter interface --
            ---------------------------------------
            pairs_available : out STD_LOGIC_VECTOR(PAIRING_BUFFER_DEPTH - 1 downto 0);
            ---------------------------------
            -- MAC_output_buffer interface --
            ---------------------------------
            new_act_val_addr : out STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS) - 1 downto 0)
        );
    end component;
    
    component MAC_processor
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
    end component;
    
    component MAC_output_buffer
        generic(
            queue_depth : positive := 2
        );
        port(
            clk               : in  STD_LOGIC;
            rst               : in  STD_LOGIC;
            enqueue_val       : in  STD_LOGIC;
            enqueue_addr      : in  STD_LOGIC;
            dequeue           : in  STD_LOGIC;
            value_in          : in  STD_LOGIC_VECTOR(ACT_VAL_WIDTH - 1 downto 0);
            addr_in           : in  STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS) - 1 downto 0);
            value_queue_full  : out STD_LOGIC;
            value_queue_empty : out STD_LOGIC;
            addr_queue_empty  : out STD_LOGIC;
            value_out         : out STD_LOGIC_VECTOR(ACT_VAL_WIDTH - 1 downto 0);
            addr_out          : out STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS) - 1 downto 0)
        );
    end component;
    
    component processing_unit_controller
        port(
            clk                   : in  STD_LOGIC;
            rst                   : in  STD_LOGIC;
            start_convolution     : in  STD_LOGIC;
            new_MAC               : in  STD_LOGIC;
            convolution_step_done : in  STD_LOGIC;
            convolution_done      : in  STD_LOGIC;
            MAC_buffer_empty      : in  STD_LOGIC;
            MAC_buffer_full       : in  STD_LOGIC;
            MAC_enable            : out STD_LOGIC;
            MAC_flush             : out STD_LOGIC;
            enqueue_addr          : out STD_LOGIC;
            done                  : out STD_LOGIC
        );
    end component;
    
    component pipeline
        generic(
            unit_no : natural := 0
        );
        port(
            clk                             : in  STD_LOGIC;
            rst                             : in  STD_LOGIC;        
            new_product                     : in  STD_LOGIC;
            write_addr                      : in  STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS) - 1 downto 0);
            convolution_step_done           : in  STD_LOGIC;
            convolution_done                : in  STD_LOGIC;
            new_product_pipelined           : out STD_LOGIC;
            write_addr_pipelined            : out STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS) - 1 downto 0);
            convolution_step_done_pipelined : out STD_LOGIC;
            convolution_done_pipelined      : out STD_LOGIC
        );
    end component;
    
    ---------------------------
    -- Filter values manager --
    ---------------------------
    signal filter_val_element_no : STD_LOGIC_VECTOR(log_2(MAX_FILTER_ELEMENTS) - 1 downto 0);
    signal filter_val            : STD_LOGIC_VECTOR(FILTER_VAL_WIDTH - 1 downto 0);
    signal filters_no            : STD_LOGIC_VECTOR(log_2(MAX_FILTERS) - 1 downto 0);
    signal filter_height         : STD_LOGIC_VECTOR(log_2(MAX_FILTER_HEIGHT) - 1 downto 0);
    signal filter_width          : STD_LOGIC_VECTOR(log_2(MAX_FILTER_WIDTH) - 1 downto 0);
    signal filter_depth          : STD_LOGIC_VECTOR(log_2(MAX_FILTER_DEPTH) - 1 downto 0);
    signal pair_taken_position   : STD_LOGIC_VECTOR(log_2(PAIRING_BUFFER_DEPTH) - 1 downto 0);
    
    ----------------------------
    -- Filter indices manager --
    ----------------------------
    signal filter_ind_element_no : STD_LOGIC_VECTOR(log_2(MAX_FILTER_ELEMENTS / FILTER_IND_WIDTH) - 1 downto 0);
    signal filter_ind            : STD_LOGIC_VECTOR(FILTER_IND_WIDTH - 1 downto 0);
    
    ------------------
    -- Pairing unit --
    ------------------
    signal filter_val_addrs      : tp_match_buffer_filter;
    signal act_val_addrs         : tp_match_buffer_act;
    signal act_ind_element_no    : STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS / ACT_IND_WIDTH) - 1 downto 0);
    signal pair_taken            : STD_LOGIC_VECTOR(PAIRING_BUFFER_DEPTH - 1 downto 0);
    signal new_act_val_position  : STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS) - 1 downto 0);
    signal convolution_step_done : STD_LOGIC;
    signal convolution_done_int  : STD_LOGIC;
    
    -------------------
    -- MAC_processor --
    -------------------
    signal MAC_enable : STD_LOGIC;
    signal MAC_flush  : STD_LOGIC;
    signal MAC_output : STD_LOGIC_VECTOR(ACT_VAL_WIDTH - 1 downto 0);
    
    -----------------------
    -- MAC output buffer --
    -----------------------
    signal enqueue_val         : STD_LOGIC;
    signal enqueue_addr        : STD_LOGIC;
    signal val_queue_full      : STD_LOGIC;
    signal val_queue_empty     : STD_LOGIC;
    signal addr_queue_empty    : STD_LOGIC;
    signal MAC_buffer_addr_out : STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS) - 1 downto 0);
    
    --------------------------------
    -- Processing unit controller --
    --------------------------------
    signal new_section : STD_LOGIC;
    
    --------------
    -- Pipeline --
    --------------
    signal new_product_pipelined           : STD_LOGIC;
    signal write_addr_pipelined            : STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS) - 1 downto 0);
    signal convolution_step_done_pipelined : STD_LOGIC;
    signal convolution_done_pipelined      : STD_LOGIC;
begin
    filter_values_manager_I: filter_manager
        generic map(
            max_elements => MAX_FILTER_ELEMENTS,
            bank_depth   => FILTER_VAL_BRAMS_PER_BANK,
            mem_width    => AXIS_BUS_WIDTH,
            data_width   => FILTER_VAL_WIDTH
        )                    
        port map(
                clk => clk,
                rst => rst,
                ------------------------------
                -- Filter storage interface --
                ------------------------------
                store_filter  => store_filter_val,
                new_data      => new_data,
                filter_input  => filter_input,
                filter_stored => filter_val_stored,
                -----------------------------
                -- Pair selector interface --
                -----------------------------
                read_element_no => filter_val_element_no,
                ----------------------------
                -- Pairing unit interface --
                ----------------------------
                filters_no    => filters_no,
                filter_height => filter_height,
                filter_width  => filter_width,
                filter_depth  => filter_depth,
                -----------------------------
                -- MAC processor interface --
                -----------------------------
                filter_output => filter_val
        );    
        
    filter_ind_manager_I: filter_manager
        generic map(
            max_elements => MAX_FILTER_ELEMENTS / FILTER_IND_WIDTH,
            bank_depth   => FILTER_IND_BRAMS_PER_BANK,
            mem_width    => AXIS_BUS_WIDTH,
            data_width   => FILTER_IND_WIDTH
        )
        port map(
                clk => clk,
                rst => rst,
                ------------------------------
                -- Filter storage interface --
                ------------------------------
                store_filter  => store_filter_ind,
                new_data      => new_data,
                filter_input  => filter_input,
                filter_stored => filter_ind_stored,
                -----------------------------
                -- Pair selector interface --
                -----------------------------
                read_element_no => filter_ind_element_no,
                ----------------------------
                -- Pairing unit interface --
                ----------------------------
                filters_no    => open,
                filter_height => open,
                filter_width  => open,
                filter_depth  => open,
                -----------------------------
                -- MAC processor interface --
                -----------------------------
                filter_output => filter_ind
        );
    
    pairing_unit_I: pairing_unit
        port map(
            clk => clk,
            rst => rst,
            ------------------------------------------
            -- processing_unit_controller interface --
            ------------------------------------------
            start_convolution     => start_convolution,
            convolution_step_done => convolution_step_done,
            convolution_done      => convolution_done_int,
            ----------------------------------
            -- act_values_manager interface --
            ----------------------------------
            act_height         => act_height,
            act_width          => act_width,
            act_x_z_slice_size => act_x_z_slice_size,
            ------------------------------
            -- filter_manager interface --
            ------------------------------
            filter_height => filter_height,
            filter_width  => filter_width,
            filter_depth  => filter_depth,
            filter_no     => (others => '0'),  --filter_no,
            filters_no    => filters_no,
            -------------------------------
            -- act_ind_arbiter interface --
            -------------------------------
            request_ind  => act_ind_request_valid,
            act_ind_addr => act_ind_element_no,
            ind_granted  => act_ind_granted,
            ind_served   => act_ind_served,
            act_ind      => act_ind,
            ----------------------------------
            -- filter_ind_manager interface --
            ----------------------------------
            filter_ind_addr => filter_ind_element_no,
            filter_ind      => filter_ind,
            -----------------------------
            -- pair_selector interface --
            -----------------------------
            filter_addrs => filter_val_addrs,
            act_addrs    => act_val_addrs,
            pair_taken   => pair_taken,
            ---------------------------------------
            -- act_values_read_arbiter interface --
            ---------------------------------------
            pairs_available => act_val_request_valid,
            ---------------------------------
            -- MAC_output_buffer interface --
            ---------------------------------
            new_act_val_addr => new_act_val_position
        );
    
    pair_selector_I: pair_selector
        generic map(
            unit_no => unit_no
        )
        port map(
            clk => clk,
            rst => rst,
            ------------------------------
            -- filter_manager interface --
            ------------------------------
            filter_val_element => filter_val_element_no,
            ----------------------------
            -- pairing_unit interface --
            ----------------------------
            filter_val_element_no => filter_val_addrs,
            act_val_element_no    => act_val_addrs,
            pair_taken            => pair_taken,
            ------------------------------------
            -- act_val_read_arbiter interface --
            ------------------------------------
            bank_no        => act_val_requests_bank_no,
            request_served => request_served,
            request_no     => request_no,
            -----------------------------------
            -- act_values_crossbar interface --
            -----------------------------------
            act_val_bank => act_val_bank,
            act_val_addr => act_val_addr
        );
    
    MAC_processor_I: MAC_processor
        port map(
            clk => clk,
            rst => rst,
            ----------------------------------------
            -- MAC processor controller interface --
            ----------------------------------------
            enable => MAC_enable,
            flush  => MAC_flush,
            --------------------------------------------
            -- Filter & activation memories interface --
            -------------------------------------------- 
            filter_val => filter_val,
            act_val    => act_val,
            ---------------------------------
            -- MAC output buffer interface --
            ---------------------------------
            enqueue_val => enqueue_val,
            output      => MAC_output
        );
    
    MAC_output_buffer_I: MAC_output_buffer
        generic map(
            queue_depth => 2
        )
        port map(
            clk               => clk,
            rst               => rst,
            enqueue_val       => enqueue_val,
            enqueue_addr      => enqueue_addr,
            dequeue           => new_act_val_written,
            value_in          => MAC_output,
            addr_in           => write_addr_pipelined,
            value_queue_full  => val_queue_full,
            value_queue_empty => val_queue_empty,
            addr_queue_empty  => addr_queue_empty,
            value_out         => new_act_val,
            addr_out          => MAC_buffer_addr_out
        );
    
    new_val                <= NOT(val_queue_empty);    
    new_act_val_element_no <= MAC_buffer_addr_out;

    controller: processing_unit_controller
        port map(
            clk                   => clk,
            rst                   => rst,
            start_convolution     => start_convolution,
            new_MAC               => new_product_pipelined,
            convolution_step_done => convolution_step_done_pipelined,
            convolution_done      => convolution_done_pipelined,
            MAC_buffer_empty      => addr_queue_empty,
            MAC_buffer_full       => val_queue_full,
            MAC_enable            => MAC_enable,
            MAC_flush             => MAC_flush,
            enqueue_addr          => enqueue_addr,
            done                  => convolution_done
        );
    
    pipeline_I: pipeline
        generic map(
            unit_no => unit_no
        )
        port map(
            clk                             => clk,
            rst                             => rst,
            new_product                     => request_served,
            write_addr                      => new_act_val_position,
            convolution_step_done           => convolution_step_done,
            convolution_done                => convolution_done_int,
            new_product_pipelined           => new_product_pipelined,
            write_addr_pipelined            => write_addr_pipelined,
            convolution_step_done_pipelined => convolution_step_done_pipelined,
            convolution_done_pipelined      => convolution_done_pipelined
        );
    
    -- Outputs
    act_ind_request <= resize(act_ind_element_no, log_2(ACT_IND_BRAMS_PER_BANK) + addr_width(ACT_IND_WIDTH) + log_2(ACT_IND_BANKS));
end processing_unit_arch;