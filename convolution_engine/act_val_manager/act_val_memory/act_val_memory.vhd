library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity act_val_memory is
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
end act_val_memory;

architecture act_val_memory_arch of act_val_memory is
    component memory
        generic(
            banks      : positive := 2;
            bank_depth : positive := 2;
            data_width : positive := 32
        );
        port(
            clk         : in  STD_LOGIC;
            rst         : in  STD_LOGIC;
            addrs       : in  STD_LOGIC_VECTOR(banks * (log_2(bank_depth) + addr_width(data_width)) - 1 downto 0);
            data_input  : in  STD_LOGIC_VECTOR(banks * data_width - 1 downto 0);
            we          : in  STD_LOGIC_VECTOR(banks - 1 downto 0);
            data_output : out STD_LOGIC_VECTOR(banks * data_width - 1 downto 0)
        );
    end component;
    
    component act_val_controller
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
            act_height         : out STD_LOGIC_VECTOR(log_2(MAX_ACT_HEIGHT) - 1 downto 0);
            act_width          : out STD_LOGIC_VECTOR(log_2(MAX_ACT_WIDTH) - 1 downto 0);
            act_x_z_slice_size : out STD_LOGIC_VECTOR(log_2(MAX_ACT_WIDTH * MAX_ACT_DEPTH) - 1 downto 0);
            addr_read          : in  tp_act_val_mem_addr;
            write_element      : in  STD_LOGIC_VECTOR(ACT_VAL_BANKS - 1 downto 0);
            addr_write         : in  tp_act_val_mem_addr;
            act_input          : in  tp_act_val_mem_data;
            ---------------------------------
            -- Activation memory interface --
            ---------------------------------
            addr_0       : out STD_LOGIC_VECTOR(ACT_VAL_BANKS * (log_2(ACT_VAL_BRAMS_PER_BANK) + addr_width(ACT_VAL_WIDTH)) - 1 downto 0);
            addr_1       : out STD_LOGIC_VECTOR(ACT_VAL_BANKS * (log_2(ACT_VAL_BRAMS_PER_BANK) + addr_width(ACT_VAL_WIDTH)) - 1 downto 0);
            we_0         : out STD_LOGIC_VECTOR(ACT_VAL_BANKS - 1 downto 0);
            we_1         : out STD_LOGIC_VECTOR(ACT_VAL_BANKS - 1 downto 0);
            mem_input    : out STD_LOGIC_VECTOR(ACT_VAL_BANKS * ACT_VAL_WIDTH - 1 downto 0);
            ---------------------------------------------
            -- Convolution engine controller interface --
            ---------------------------------------------
            store_image  : in  STD_LOGIC;
            image_stored : out STD_LOGIC;
            layer        : in  STD_LOGIC
        );
    end component;
    
    --------------
    -- Memories --
    --------------
    signal addr_0       : STD_LOGIC_VECTOR((banks * (log_2(bank_depth) + addr_width(data_width))) - 1 downto 0);
    signal addr_1       : STD_LOGIC_VECTOR((banks * (log_2(bank_depth) + addr_width(data_width))) - 1 downto 0);
    signal mem_input    : STD_LOGIC_VECTOR((banks * ACT_VAL_WIDTH) - 1 downto 0);
    signal we_0         : STD_LOGIC_VECTOR(banks - 1 downto 0);
    signal we_1         : STD_LOGIC_VECTOR(banks - 1 downto 0);
    signal mem_output_0 : STD_LOGIC_VECTOR((banks * data_width) - 1 downto 0);
    signal mem_output_1 : STD_LOGIC_VECTOR((banks * data_width) - 1 downto 0);
begin
    memory_0_I: memory
        generic map(
            banks      => ACT_VAL_BANKS,
            bank_depth => ACT_VAL_BRAMS_PER_BANK,
            data_width => ACT_VAL_WIDTH
        )
        port map(
            clk         => clk,
            rst         => rst,
            addrs       => addr_0,
            data_input  => mem_input,
            we          => we_0,
            data_output => mem_output_0
        );
    
    memory_1_I: memory
        generic map(
            banks      => ACT_VAL_BANKS,
            bank_depth => ACT_VAL_BRAMS_PER_BANK,
            data_width => ACT_VAL_WIDTH
        )
        port map(
            clk         => clk,
            rst         => rst,
            addrs       => addr_1,
            data_input  => mem_input,
            we          => we_1,
            data_output => mem_output_1
        );
    
    act_val_controller_I: act_val_controller
        port map(
            clk => clk,
            rst => rst,
            -------------------------
            -- Datamover interface --
            -------------------------
            new_data    => new_data,
            image_input => image_input,
            -------------------
            -- PUs interface --
            -------------------
            write_element      => write_value,
            addr_write         => addr_write,
            act_input          => act_input,
            addr_read          => addr_read,
            layer              => layer,
            act_height         => act_height,
            act_width          => act_width,
            act_x_z_slice_size => act_x_z_slice_size,
            ---------------------------------
            -- Activation memory interface --
            ---------------------------------
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
    
    -------------
    -- Outputs --
    -------------
    -- Type conversion
    act_output_conv: for i in 0 to ACT_VAL_BANKS - 1 generate
        act_output(i) <= vector_slice(mem_output_0, i, ACT_VAL_WIDTH);
    end generate;
end act_val_memory_arch;