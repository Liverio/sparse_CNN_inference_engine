library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity act_ind_manager is
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
end act_ind_manager;

architecture act_ind_manager_arch of act_ind_manager is
    component act_ind_memory
        port(
            clk : in STD_LOGIC;
            rst : in STD_LOGIC;
            -----------------------------
            -- Image storage interface --
            -----------------------------
            store_image : in STD_LOGIC;
            new_data    : in STD_LOGIC;         
            image_input : in STD_LOGIC_VECTOR(AXIS_BUS_WIDTH - 1 downto 0);
            --------------------
            -- PUs interface --
            --------------------
            write_element      : in  STD_LOGIC;
            element_addr_write : in  STD_LOGIC_VECTOR(log_2(ACT_IND_BRAMS_PER_BANK) + addr_width(ACT_IND_WIDTH) - 1 downto 0);
            act_input          : in  STD_LOGIC_VECTOR(ACT_IND_WIDTH - 1 downto 0);
            addrs_read         : in  tp_act_ind_requests_served;
            layer              : in  STD_LOGIC;
            act_output         : out tp_act_ind_mem_output;
            ---------------------------------------------
            -- convolution_engine_controller interface --
            ---------------------------------------------
            image_stored : out STD_LOGIC
        );
    end component;

    component act_ind_arbiter
        port(
            clk            : in  STD_LOGIC;
            rst            : in  STD_LOGIC;
            requests       : in  tp_act_ind_requests;
            requests_valid : in  STD_LOGIC_VECTOR(PUs - 1 downto 0);
            granted        : out STD_LOGIC_VECTOR(PUs - 1 downto 0);
            served         : out STD_LOGIC_VECTOR(PUs - 1 downto 0);
            PUs_granted    : out tp_act_ind_PUs_served
        );
    end component;

    component act_ind_read_crossbar
        port(
            clk : in STD_LOGIC;
            rst : in STD_LOGIC;
            ---------------------------------
            -- Act_ind arbiter_r interface --
            ---------------------------------
            PUs_granted : in tp_act_ind_PUs_served;
            -------------------
            -- PUs interface --
            -------------------
            PU_requests_addrs : in  tp_act_ind_requests;
            act_ind_read      : out tp_act_ind_read;
            -------------------------------
            -- Act_ind manager interface --
            -------------------------------
            act_ind           : in  tp_act_ind_mem_output;
            act_mem_ind_addrs : out tp_act_ind_requests_served
        );
    end component;

    --------------------
    -- act_ind_memory --
    --------------------
    signal act_ind_read_addrs : tp_act_ind_requests_served;
    signal act_ind_int        : tp_act_ind_mem_output;
    
    ---------------------
    -- act_ind_arbiter --
    ---------------------
    signal act_ind_requests             : tp_act_ind_requests;
    signal act_ind_requests_valid       : STD_LOGIC_VECTOR(PUs - 1 downto 0);
    signal act_ind_read_request_granted : STD_LOGIC_VECTOR(PUs - 1 downto 0);
    signal act_ind_read_request_served  : STD_LOGIC_VECTOR(PUs - 1 downto 0);
    signal act_ind_read_addrs_served    : tp_act_ind_PUs_served;
begin
    --------------------
    -- act_ind_memory --
    --------------------
    act_ind_memory_I: act_ind_memory
        port map(
            clk => clk,
            rst => rst,
            -------------------------
            -- Datamover interface --
            -------------------------
            new_data    => new_data,
            image_input => image_input,
            --------------------
            -- PUs interface --
            --------------------
            write_element      => '0',                -- TEMP
            element_addr_write => (others => '0'),    -- TEMP
            act_input          => (others => '0'),    -- TEMP
            addrs_read         => read_addrs,
            layer              => layer,
            act_output         => act_ind_int,
            ---------------------------------------------
            -- convolution_engine_controller interface --
            ---------------------------------------------
            store_image  => store_image_ind,
            image_stored => image_ind_stored
        );
   
    ---------------------
    -- act_ind_arbiter --
    ---------------------
    act_ind_arbiter_I: act_ind_arbiter
        port map(
                clk            => clk,
                rst            => rst,
                requests       => act_ind_requests,
                requests_valid => act_ind_requests_valid,
                -- PUs that were granted
                granted        => act_ind_read_request_granted,
                served         => act_ind_read_request_served,                 
                -- PU assigned to each bank
                PUs_granted    => act_ind_read_addrs_served);
    
    ---------------------------
    -- act_ind_read_crossbar --
    ---------------------------
    act_ind_read_crossbar_I: act_ind_read_crossbar
        port map(
                clk => clk,
                rst => rst,
                ------------------------------------
                -- act_ind_read_arbiter interface --
                ------------------------------------
                PUs_granted => act_ind_read_addrs_served,
                -------------------
                -- PUs interface --
                -------------------
                PU_requests_addrs => act_ind_requests,
                act_ind_read      => act_ind_read,
                ------------------------------
                -- act_ind memory interface --
                ------------------------------
                act_ind           => act_ind_int,
                act_mem_ind_addrs => act_ind_read_addrs
        );

    act_ind <= act_ind_int;
end act_ind_manager_arch;