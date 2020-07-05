library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity convolution_engine is
    port(
        clk         : in  STD_LOGIC;
        rst         : in  STD_LOGIC;
        new_data    : in  STD_LOGIC;          
        data_input  : in  STD_LOGIC_VECTOR(AXIS_BUS_WIDTH - 1 downto 0);
        done        : out STD_LOGIC;         
        conv_output : out STD_LOGIC_VECTOR(AXIS_BUS_WIDTH - 1 downto 0)
    );
end convolution_engine;

architecture convolution_engine_arch of convolution_engine is    
    ------------------------
    -- Activation indices --
    ------------------------
    component act_ind_manager
        port(
            clk : in STD_LOGIC;
            rst : in STD_LOGIC;
            -------------------------
            -- Datamover interface --
            -------------------------
            new_data    : in STD_LOGIC;         
            image_input : in STD_LOGIC_VECTOR(AXIS_BUS_WIDTH - 1 downto 0);
            -------------------
            -- PUs interface --
            -------------------
            -- Memory interface
            store       : in  STD_LOGIC;
            store_addr  : in  STD_LOGIC_VECTOR(log_2(ACT_IND_BRAMS_PER_BANK) + addr_width(ACT_IND_WIDTH) - 1 downto 0);
            store_input : in  STD_LOGIC_VECTOR(ACT_IND_WIDTH - 1 downto 0);
            read_addrs  : in  tp_act_ind_requests_served;
            layer       : in  STD_LOGIC;
            act_ind     : out tp_act_ind_mem_output;
            -- Arbiter interface
            requests       : in  tp_act_ind_requests;
            requests_valid : in  STD_LOGIC_VECTOR(PUs - 1 downto 0);
            granted        : out STD_LOGIC_VECTOR(PUs - 1 downto 0);
            served         : out STD_LOGIC_VECTOR(PUs - 1 downto 0);
            -- Crossbar interface
            PU_requests_addrs : in  tp_act_ind_requests;
            act_ind_read      : out tp_act_ind_read;
            ---------------------------------------------
            -- convolution_engine_controller interface --
            ---------------------------------------------
            store_image_ind  : in  STD_LOGIC;
            image_ind_stored : out STD_LOGIC
        );
    end component;
    
    -----------------------
    -- Activation values --
    -----------------------
    component act_val_manager
        generic(
            banks      : positive := ACT_VAL_BANKS;
            bank_depth : positive := ACT_VAL_BRAMS_PER_BANK;
            data_width : positive := ACT_VAL_WIDTH
        );
        port(
            clk : in STD_LOGIC;
            rst : in STD_LOGIC;
            -------------------------
            -- Datamover interface --
            -------------------------
            new_data    : in STD_LOGIC;         
            image_input : in STD_LOGIC_VECTOR(AXIS_BUS_WIDTH - 1 downto 0);
            -------------------
            -- PUs interface --
            -------------------
            -- Memory
            act_height         : out STD_LOGIC_VECTOR(log_2(MAX_ACT_HEIGHT) - 1 downto 0);
            act_width          : out STD_LOGIC_VECTOR(log_2(MAX_ACT_WIDTH)  - 1 downto 0);
            act_x_z_slice_size : out STD_LOGIC_VECTOR(log_2(MAX_ACT_WIDTH * MAX_ACT_DEPTH) - 1 downto 0);
            act_output         : out tp_act_val_mem_data;
            -- Reading crossbar
            read_bank : in  tp_act_val_bank_requests;
            read_addr : in  tp_addrs_selected;
            read_val  : out tp_MACs_act_input;
            -- Reading arbiter
            read_requests                  : in  tp_request_array;
            read_requests_valid            : in  tp_request_valid_array;
            read_request_served_to_pairing : out STD_LOGIC_VECTOR(PUs - 1 downto 0);
            read_request_to_pairing        : out tp_bank_requests_selected;
            -- Writing arbiter
            write_requests        : in  tp_act_val_bank_requests;
            write_requests_valid  : in  STD_LOGIC_VECTOR(PUs - 1 downto 0);
            write_requests_served : out STD_LOGIC_VECTOR(PUs - 1 downto 0);
            -- Write crossbar
            new_act_val_bank : in tp_act_val_bank_requests;
            new_act_val_addr : in tp_new_act_val_addr_requests;
            new_act_val      : in tp_new_act_val_requests;
            ---------------------------------------------
            -- Convolution engine controller interface --
            ---------------------------------------------
            layer        : in  STD_LOGIC;
            store_image  : in  STD_LOGIC;
            image_stored : out STD_LOGIC
        );
    end component;
    
    ----------------------
    -- Processing units --
    ----------------------
    component processing_unit
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
    end component;

    -----------------------------------
    -- Convolution engine controller --
    -----------------------------------
    component convolution_engine_controller is    
        port(
            clk, rst : in STD_LOGIC;
            -----------------------------
            -- Image storing interface --
            -----------------------------
            new_data   : in  STD_LOGIC;          
            data_input : in  STD_LOGIC_VECTOR(AXIS_BUS_WIDTH - 1 downto 0);
            done       : out STD_LOGIC;
            -------------------
            -- PUs interface --
            -------------------
            compute_convolution : out STD_LOGIC_VECTOR(PUs - 1 downto 0);
            convolution_done    : in  STD_LOGIC_VECTOR(PUs - 1 downto 0);
            -------------------------------
            -- act_ind_manager interface --
            -------------------------------
            store_image_ind   : out STD_LOGIC;
            store_filter_ind  : out STD_LOGIC_VECTOR(PUs - 1 downto 0);
            image_ind_stored  : in  STD_LOGIC;
            filter_ind_stored : in  STD_LOGIC_VECTOR(PUs - 1 downto 0);
            -------------------------------
            -- act_val_manager interface --
            -------------------------------
            store_image_val   : out STD_LOGIC;
            store_filter_val  : out STD_LOGIC_VECTOR(PUs - 1 downto 0);
            image_val_stored  : in  STD_LOGIC;
            filter_val_stored : in  STD_LOGIC_VECTOR(PUs - 1 downto 0)
        );
    end component;
    
    signal layer: STD_LOGIC;    -- TEMP

    ------------------------
    -- Activation indices --
    ------------------------
    -- Memory interface
    signal act_ind_store      : STD_LOGIC;
    signal act_ind_store_addr : STD_LOGIC_VECTOR(log_2(ACT_IND_BRAMS_PER_BANK) + addr_width(ACT_IND_WIDTH) - 1 downto 0);
    signal act_ind_read_addrs : tp_act_ind_requests_served;
    signal act_ind            : tp_act_ind_mem_output;
    -- Arbiter interface
    signal act_ind_requests       : tp_act_ind_requests;
    signal act_ind_requests_valid : STD_LOGIC_VECTOR(PUs - 1 downto 0);
    signal act_ind_granted        : STD_LOGIC_VECTOR(PUs - 1 downto 0);
    signal act_ind_served         : STD_LOGIC_VECTOR(PUs - 1 downto 0);
    -- Crossbar interface
    signal act_ind_PU_requests_addrs : tp_act_ind_requests;
    signal act_ind_read              : tp_act_ind_read;
    -- Convolution engine controller interface
    signal image_ind_stored : STD_LOGIC;

    -----------------------
    -- Activation values --
    -----------------------
    -- Memory interface
    signal image_val_stored    : STD_LOGIC;
    signal write_act_val       : STD_LOGIC_VECTOR(ACT_VAL_BANKS - 1 downto 0);
    signal act_val_addrs_write : tp_act_val_mem_addr;
    signal act_val_addrs_read  : tp_act_val_mem_addr;
    signal retrieve_act_val    : STD_LOGIC;
    signal act_height          : STD_LOGIC_VECTOR(log_2(MAX_ACT_HEIGHT) - 1 downto 0);
    signal act_width           : STD_LOGIC_VECTOR(log_2(MAX_ACT_WIDTH)  - 1 downto 0);
    signal act_x_z_slice_size  : STD_LOGIC_VECTOR(log_2(MAX_ACT_WIDTH * MAX_ACT_DEPTH) - 1 downto 0);    
    signal act_val             : tp_act_val_mem_data;
    -- Read arbiter
    signal act_val_read_requests                  : tp_request_array;
    signal act_val_read_requests_valid            : tp_request_valid_array;
    signal act_val_read_request_served_to_pairing : STD_LOGIC_VECTOR(PUs - 1 downto 0);
    signal act_val_read_request_to_pairing        : tp_bank_requests_selected;
    -- Read crossbar
    signal act_val_bank : tp_act_val_bank_requests;
    signal act_val_addr : tp_addrs_selected;    
    signal MAC_act_val  : tp_MACs_act_input;
    -- Write arbiter
    signal new_act_val_bank                 : tp_act_val_bank_requests;
    signal new_act_val_write_request        : STD_LOGIC_VECTOR(PUs - 1 downto 0);
    signal new_act_val_served : STD_LOGIC_VECTOR(PUs - 1 downto 0);
    -- Write crossbar
    signal new_act_val_addr : tp_new_act_val_addr_requests;
    signal new_act_val      : tp_new_act_val_requests;
    
    ---------
    -- PUs --
    ---------
    signal filter_ind_stored            : STD_LOGIC_VECTOR(PUs - 1 downto 0);
    signal filter_val_stored            : STD_LOGIC_VECTOR(PUs - 1 downto 0);
    signal new_act_val_element_no       : tp_act_val_elements_no;
    signal new_act_val_local_element_no : tp_act_val_elements_no;
    signal convolution_done             : STD_LOGIC_VECTOR(PUs - 1 downto 0);
    
    -----------------------------------
    -- Convolution engine controller --
    -----------------------------------
    signal store_image_ind   : STD_LOGIC;
    signal store_image_val   : STD_LOGIC;
    signal store_filter_ind  : STD_LOGIC_VECTOR(PUs - 1 downto 0);
    signal store_filter_val  : STD_LOGIC_VECTOR(PUs - 1 downto 0);
    signal start_convolution : STD_LOGIC_VECTOR(PUs - 1 downto 0);
begin
    layer <= '0';   -- TEMP
    
    ------------------------
    -- Activation indices --
    ------------------------
    act_ind_manager_I: act_ind_manager
        port map(
            clk => clk,
            rst => rst,
            -------------------------
            -- Datamover interface --
            -------------------------
            new_data    => new_data,
            image_input => data_input,
            -------------------
            -- PUs interface --
            -------------------
            -- Memory interface
            store       => act_ind_store,
            store_addr  => act_ind_store_addr,
            store_input => (others => '0'),
            read_addrs  => act_ind_read_addrs,
            layer       => layer,
            act_ind     => act_ind,
            -- Arbiter interface
            requests       => act_ind_requests,
            requests_valid => act_ind_requests_valid,
            granted        => act_ind_granted,
            served         => act_ind_served,
            -- Crossbar interface
            PU_requests_addrs => act_ind_PU_requests_addrs,
            act_ind_read      => act_ind_read,
            ---------------------------------------------
            -- convolution_engine_controller interface --
            ---------------------------------------------
            store_image_ind  => store_image_ind,
            image_ind_stored => image_ind_stored
        );

    -----------------------
    -- Activation values --
    -----------------------
    act_val_manager_I: act_val_manager
        generic map(
            banks      => ACT_VAL_BANKS,
            bank_depth => ACT_VAL_BRAMS_PER_BANK,
            data_width => ACT_VAL_WIDTH
        )
        port map(
            clk => clk,
            rst => rst,
            -------------------------
            -- Datamover interface --
            -------------------------
            new_data    => new_data,
            image_input => data_input,                 
            -------------------
            -- PUs interface --
            -------------------
            -- Memory
            act_height         => act_height,
            act_width          => act_width,
            act_x_z_slice_size => act_x_z_slice_size,
            act_output         => act_val,
            -- Read arbiter
            read_requests                  => act_val_read_requests,
            read_requests_valid            => act_val_read_requests_valid,
            read_request_served_to_pairing => act_val_read_request_served_to_pairing,
            read_request_to_pairing        => act_val_read_request_to_pairing,
            -- Read crossbar
            read_bank => act_val_bank,
            read_addr => act_val_addr,
            read_val  => MAC_act_val,
            -- Write arbiter
            write_requests        => new_act_val_bank,
            write_requests_valid  => new_act_val_write_request,
            write_requests_served => new_act_val_served,
            -- Write crossbar
            new_act_val_bank => new_act_val_bank,
            new_act_val_addr => new_act_val_addr,
            new_act_val      => new_act_val,
            ---------------------------------------------
            -- Convolution engine controller interface --
            ---------------------------------------------
            layer        => layer,
            store_image  => store_image_val,
            image_stored => image_val_stored
        );

    ----------------------
    -- Processing units --
    ----------------------
    PU: for i in 0 to PUs - 1 generate
        processing_unit_I: processing_unit
            generic map(
                unit_no    => i,
                bank_depth => 2,
                mem_width  => AXIS_BUS_WIDTH,
                data_width => ACT_VAL_WIDTH
            )
            port map(
                clk => clk,
                rst => rst,
                ------------------------------ 
                -- Filter storage interface --
                ------------------------------
                store_filter_ind => store_filter_ind(i),
                store_filter_val => store_filter_val(i),
                new_data         => new_data,
                filter_input     => data_input,
                ---------------------------------------------
                -- convolution_engine_controller interface --
                ---------------------------------------------
                start_convolution => start_convolution(i),
                filter_ind_stored => filter_ind_stored(i),
                filter_val_stored => filter_val_stored(i),
                convolution_done  => convolution_done(i),
                -------------------------------
                -- act_ind_arbiter interface --
                -------------------------------
                act_ind_request       => act_ind_requests(i),
                act_ind_request_valid => act_ind_requests_valid(i),
                act_ind_granted       => act_ind_granted(i),
                act_ind_served        => act_ind_served(i),
                act_ind               => act_ind_read(i),
                ----------------------------------
                -- act_values_manager interface --
                ----------------------------------
                -- act_values_memory interface
                act_height         => act_height,
                act_width          => act_width,
                act_x_z_slice_size => act_x_z_slice_size,
                -- act_values_crossbar interface
                act_val_bank => act_val_bank(i),
                act_val_addr => act_val_addr(i),
                act_val      => MAC_act_val(i),
                -- act_values_read_arbiter interface
                act_val_requests_bank_no => act_val_read_requests(i),
                act_val_request_valid    => act_val_read_requests_valid(i),
                request_served           => act_val_read_request_served_to_pairing(i),
                request_no               => act_val_read_request_to_pairing(i),
                ----------------------------------------
                -- act_values_write_arbiter interface --
                ----------------------------------------
                new_val                => new_act_val_write_request(i),
                new_act_val            => new_act_val(i),
                new_act_val_element_no => new_act_val_local_element_no(i),
                new_act_val_written    => new_act_val_served(i)
            );

            new_act_val_element_no(i) <= std_logic_vector(to_unsigned(to_uint(new_act_val_local_element_no(i)) + i, log_2(MAX_ACT_ELEMENTS)));
            new_act_val_bank(i)       <= new_act_val_element_no(i)(log_2(ACT_VAL_BANKS) - 1 downto 0);
            new_act_val_addr(i)       <= new_act_val_element_no(i)(ACT_VAL_BANK_ADDRESS_SIZE + log_2(ACT_VAL_BANKS) - 1 downto log_2(ACT_VAL_BANKS));        
    end generate;
   
    -----------------------------------
    -- convolution_engine_controller --
    -----------------------------------
    convolution_engine_controller_I: convolution_engine_controller
        port map(
            clk => clk,
            rst => rst,
            -----------------------------
            -- Image storing interface --
            -----------------------------
            new_data   => new_data,
            data_input => data_input,
            done       => done,
            -------------------
            -- PUs interface --
            -------------------
            compute_convolution => start_convolution,
            convolution_done    => convolution_done,
            -------------------------------
            -- act_ind_manager interface --
            -------------------------------
            store_image_ind   => store_image_ind,
            store_filter_ind  => store_filter_ind,
            image_ind_stored  => image_ind_stored,
            filter_ind_stored => filter_ind_stored,
            -------------------------------
            -- act_val_manager interface --
            -------------------------------
            store_image_val   => store_image_val,
            store_filter_val  => store_filter_val,
            image_val_stored  => image_val_stored,
            filter_val_stored => filter_val_stored
        );

    -- TEMP
    -- conv_output <= std_logic_vector(to_unsigned(0, AXIS_BUS_WIDTH - ACT_VAL_WIDTH)) & act_val(to_uint(DEBUG_addr_read(log_2(ACT_VAL_BANKS) - 1 downto 0)));
    conv_output <= std_logic_vector(to_unsigned(0, AXIS_BUS_WIDTH - ACT_VAL_WIDTH)) & act_val(0);
end convolution_engine_arch;