library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity act_ind_memory is
    port(
        clk : in STD_LOGIC;
        rst : in STD_LOGIC;
        -------------------------
        -- Datamover interface --
        -------------------------
        store_image : in STD_LOGIC;
        new_data    : in STD_LOGIC;
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
        image_input  : in STD_LOGIC_VECTOR(AXIS_BUS_WIDTH - 1 downto 0);
        image_stored : out STD_LOGIC
    );
end act_ind_memory;

architecture act_ind_memory_arch of act_ind_memory is
    component memory
        generic(banks      : positive := 1;
                bank_depth : positive := 2;
                data_width : positive := 32
        );
        port(
            clk         : in  STD_LOGIC;
            rst         : in  STD_LOGIC;
            addrs       : in  STD_LOGIC_VECTOR((banks * (log_2(bank_depth) + addr_width(data_width))) - 1 downto 0);
            data_input  : in  STD_LOGIC_VECTOR((banks * data_width) - 1 downto 0);
            we          : in  STD_LOGIC_VECTOR(banks - 1 downto 0);
            data_output : out STD_LOGIC_VECTOR((banks * data_width) - 1 downto 0)
        );
    end component;
    
    component act_ind_controller
        port(
            clk : in STD_LOGIC;
            rst : in STD_LOGIC;
            -------------------------
            -- Datamover interface --
            -------------------------
            new_data    : in STD_LOGIC;         
            image_input : in STD_LOGIC_VECTOR(AXIS_BUS_WIDTH - 1 downto 0);
            --------------------
            -- PUs interface --
            --------------------
            write_element : in STD_LOGIC;
            write_addr    : in STD_LOGIC_VECTOR(log_2(ACT_IND_BRAMS_PER_BANK) + addr_width(ACT_IND_WIDTH) - 1 downto 0);
            act_input     : in STD_LOGIC_VECTOR(ACT_IND_WIDTH - 1 downto 0);
            addrs_read    : in tp_act_ind_requests_served;
            layer         : in STD_LOGIC;
            ------------------------------
            -- act_ind_memory interface --
            ------------------------------
            addr_0       : out STD_LOGIC_VECTOR(ACT_IND_BANKS * (log_2(ACT_IND_BRAMS_PER_BANK) + addr_width(ACT_IND_WIDTH)) - 1 downto 0);
            addr_1       : out STD_LOGIC_VECTOR(ACT_IND_BANKS * (log_2(ACT_IND_BRAMS_PER_BANK) + addr_width(ACT_IND_WIDTH)) - 1 downto 0);
            we_0         : out STD_LOGIC_VECTOR(ACT_IND_BANKS - 1 downto 0);
            we_1         : out STD_LOGIC_VECTOR(ACT_IND_BANKS - 1 downto 0);
            mem_input    : out STD_LOGIC_VECTOR(ACT_IND_BANKS * ACT_IND_WIDTH - 1 downto 0);
            ---------------------------------------------
            -- Convolution engine controller interface --
            ---------------------------------------------
            store_image  : in  STD_LOGIC;
            image_stored : out STD_LOGIC
        );
    end component;    
   
    signal mem_input    : STD_LOGIC_VECTOR(ACT_IND_BANKS * ACT_IND_WIDTH - 1 downto 0);
    --------------
    -- memory_0 --
    --------------
    signal we_0         : STD_LOGIC_VECTOR(ACT_IND_BANKS - 1 downto 0);
    signal addr_0       : STD_LOGIC_VECTOR(ACT_IND_BANKS * (log_2(ACT_IND_BRAMS_PER_BANK) + addr_width(ACT_IND_WIDTH)) - 1 downto 0);
    signal mem_output_0 : STD_LOGIC_VECTOR(ACT_IND_BANKS * ACT_IND_WIDTH - 1 downto 0);

    --------------
    -- memory_1 --
    --------------
    signal we_1         : STD_LOGIC_VECTOR(ACT_IND_BANKS - 1 downto 0);
    signal addr_1       : STD_LOGIC_VECTOR(ACT_IND_BANKS * (log_2(ACT_IND_BRAMS_PER_BANK) + addr_width(ACT_IND_WIDTH)) - 1 downto 0);
    signal mem_output_1 : STD_LOGIC_VECTOR(ACT_IND_BANKS * ACT_IND_WIDTH - 1 downto 0);
begin
    memory_0: memory
        generic map(
            banks      => ACT_IND_BANKS,
            bank_depth => ACT_IND_BRAMS_PER_BANK,
            data_width => AXIS_BUS_WIDTH
        )
        port map(
            clk         => clk,
            rst         => rst,
            addrs       => addr_0,
            data_input  => mem_input,
            we          => we_0,
            data_output => mem_output_0
        );        
    
    memory_1: memory
        generic map(
            banks      => ACT_IND_BANKS,
            bank_depth => ACT_IND_BRAMS_PER_BANK,
            data_width => AXIS_BUS_WIDTH
        )
        port map(
            clk         => clk,
            rst         => rst,
            addrs       => addr_1,
            data_input  => mem_input,
            we          => we_0,
            data_output => mem_output_1
        );
    
    act_ind_controller_I: act_ind_controller
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
            write_element => write_element,
            write_addr    => element_addr_write,
            act_input     => act_input,
            addrs_read    => addrs_read,
            layer         => layer,
            -------------------------------------------
            ---- Activation indices memory interface --
            -------------------------------------------
            addr_0       => addr_0,
            addr_1       => addr_1,
            we_0         => we_0,
            we_1         => we_1,
            mem_input    => mem_input,
            ---------------------------------------------
            -- Convolution engine controller interface --
            ---------------------------------------------
            store_image  => store_image,
            image_stored => image_stored
        );    

    -- Type conversion
    output_conv: for i in 0 to ACT_IND_BANKS - 1 generate
        act_output(i) <= vector_slice(mem_output_0, i, ACT_IND_WIDTH);        
--        act_output(i) <= vector_slice(mem_output_0, i, ACT_VALUE_WIDTH) when (layer = EVEN AND retrieve_act = '0') OR (layer = ODD AND retrieve_act = '1') else
--                                vector_slice(mem_output_1, i, ACT_VALUE_WIDTH);
    end generate;
end act_ind_memory_arch;