library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity act_val_manager is
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
end act_val_manager;

architecture act_val_manager_arch of act_val_manager is
    component act_val_memory
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
            --------------------
            -- PUs interface ---
            --------------------
            write_value        : in  STD_LOGIC_VECTOR(ACT_VAL_BANKS - 1 downto 0);
            addr_write         : in  tp_act_val_mem_addr;
            act_input          : in  tp_act_val_mem_data;
            addr_read          : in  tp_act_val_mem_addr;
            layer              : in  STD_LOGIC;
            act_height         : out STD_LOGIC_VECTOR(log_2(MAX_ACT_HEIGHT) - 1 downto 0);
            act_width          : out STD_LOGIC_VECTOR(log_2(MAX_ACT_WIDTH)  - 1 downto 0);
            act_x_z_slice_size : out STD_LOGIC_VECTOR(log_2(MAX_ACT_WIDTH * MAX_ACT_DEPTH) - 1 downto 0);
            act_output         : out tp_act_val_mem_data;
            ---------------------------------------------
            -- Convolution engine controller interface --
            ---------------------------------------------
            store_image  : in  STD_LOGIC;
            image_stored : out STD_LOGIC
        );
    end component;
    
    component act_val_read_arbiter
        port(
            clk : in STD_LOGIC;
            rst : in STD_LOGIC;
            -------------------
            -- PUs interface --
            -------------------
            requests                  : in  tp_request_array;
            requests_valid            : in  tp_request_valid_array;
            request_served_to_pairing : out STD_LOGIC_VECTOR(PUs - 1 downto 0);
            request_to_pairing        : out tp_bank_requests_selected;
            request_served            : out STD_LOGIC_VECTOR(PUs - 1 downto 0);
            request                   : out tp_bank_requests_selected
        );
    end component;

    component act_val_read_crossbar
        port(
            clk : in STD_LOGIC;
            rst : in STD_LOGIC;
            ----------------------------------------------
            -- Activation values read arbiter interface --
            ----------------------------------------------
            bank_request        : in tp_act_val_bank_requests;
            bank_request_served : in STD_LOGIC_VECTOR(PUs - 1 downto 0);
            bank_request_addrs  : in tp_addrs_selected;
            ---------------------------------
            -- Activation memory interface --
            ---------------------------------
            act_val       : in  tp_act_val_mem_data;
            act_mem_addrs : out tp_act_val_mem_addr;
            -------------------
            -- PUs interface --
            -------------------
            MAC_act_val : out tp_MACs_act_input
        );
    end component;
    
    component act_val_write_arbiter
        port(
            clk : in STD_LOGIC;
            rst : in STD_LOGIC;
            -------------------
            -- PUs interface --
            -------------------
            requests       : in  tp_act_val_bank_requests;
            requests_valid : in  STD_LOGIC_VECTOR(PUs - 1 downto 0);
            served         : out STD_LOGIC_VECTOR(PUs - 1 downto 0)
        );
    end component;
    
    component act_val_write_crossbar
        port(
            -----------------------------------------------
            -- Activation values write arbiter interface --
            -----------------------------------------------
            bank_requests_served : in STD_LOGIC_VECTOR(PUs - 1 downto 0);
            -------------------
            -- PUs interface --
            -------------------
            bank_requests       : in tp_act_val_bank_requests;
            bank_requests_addrs : in tp_new_act_val_addr_requests;
            requests_values     : in tp_new_act_val_requests;
            ----------------------------------------
            -- Activation values memory interface --
            ----------------------------------------
            act_mem_write  : out STD_LOGIC_VECTOR(ACT_VAL_BANKS - 1 downto 0);
            act_mem_addrs  : out tp_act_val_mem_addr;
            act_mem_values : out tp_act_val_mem_data
        );
    end component;
    
    ------------------------------
    -- Activation values memory --
    ------------------------------
    signal act_val : tp_act_val_mem_data;

    -------------------------------------
    -- Activation values read crossbar --
    -------------------------------------
    signal act_val_addrs_read : tp_act_val_mem_addr;

    ----------------------------------------
    -- Activation values readings arbiter --
    ----------------------------------------
    signal read_request_served : STD_LOGIC_VECTOR(PUs - 1 downto 0);
   
    ----------------------------------------
    -- Activation values writings arbiter --
    ----------------------------------------
    signal write_requests_served_int : STD_LOGIC_VECTOR(PUs - 1 downto 0);

    -----------------------
    -- Writings crossbar --
    -----------------------
    signal act_mem_write              : STD_LOGIC_VECTOR(ACT_VAL_BANKS - 1 downto 0);
    signal new_act_val_addrs_selected : tp_act_val_mem_addr;
    signal new_act_val_val_selected   : tp_act_val_mem_data;
begin
    ------------------------------
    -- Activation values memory --
    ------------------------------
    act_val_memory_I: act_val_memory
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
            image_input => image_input,                 
            --------------------
            -- PUs interface ---
            --------------------
            write_value        => act_mem_write,
            addr_write         => new_act_val_addrs_selected,
            act_input          => new_act_val_val_selected,
            addr_read          => act_val_addrs_read,
            layer              => layer,
            act_height         => act_height,
            act_width          => act_width,
            act_x_z_slice_size => act_x_z_slice_size,
            act_output         => act_val,
            ---------------------------------------------
            -- Convolution engine controller interface --
            ---------------------------------------------
            store_image  => store_image,
            image_stored => image_stored
        );
    
    ----------------------------------------
    -- Activation values readings arbiter --
    ----------------------------------------
    act_val_read_arbiter_I: act_val_read_arbiter
        port map(
            clk => clk,
            rst => rst,
            -------------------
            -- PUs interface --
            -------------------
            requests                  => read_requests,
            requests_valid            => read_requests_valid,
            request_served_to_pairing => read_request_served_to_pairing,
            request_to_pairing        => read_request_to_pairing,
            request_served            => read_request_served,
            request                   => open
        );

    -------------------------------------
    -- Activation values read crossbar --
    -------------------------------------
    act_val_read_crossbar_I: act_val_read_crossbar
        port map(
            clk => clk,
            rst => rst,
            ----------------------------------------------
            -- Activation values read arbiter interface --
            ----------------------------------------------
            bank_request        => read_bank,
            bank_request_served => read_request_served,
            bank_request_addrs  => read_addr,
            ---------------------------------
            -- Activation memory interface --
            ---------------------------------
            act_val       => act_val,
            act_mem_addrs => act_val_addrs_read,
            -------------------
            -- PUs interface --
            -------------------
            MAC_act_val => read_val
        );

    ----------------------------------------
    -- Activation values writings arbiter --
    ----------------------------------------
    act_val_write_arbiter_I: act_val_write_arbiter
        port map(
            clk => clk,
            rst => rst,
            -------------------
            -- PUs interface --
            -------------------
            requests       => write_requests,
            requests_valid => write_requests_valid,
            served         => write_requests_served_int
        );

    write_requests_served <= write_requests_served_int;
    
    -----------------------------------------
    -- Activation values writings crossbar --
    -----------------------------------------
    act_val_write_crossbar_I: act_val_write_crossbar
        port map(
            -----------------------------------------------
            -- Activation values write arbiter interface --
            -----------------------------------------------
            bank_requests_served => write_requests_served_int,
            -------------------
            -- PUs interface --
            -------------------
            bank_requests       => new_act_val_bank,
            bank_requests_addrs => new_act_val_addr,
            requests_values     => new_act_val,
            ----------------------------------------
            -- Activation values memory interface --
            ----------------------------------------
            act_mem_write  => act_mem_write,
            act_mem_addrs  => new_act_val_addrs_selected,
            act_mem_values => new_act_val_val_selected
        );
end act_val_manager_arch;