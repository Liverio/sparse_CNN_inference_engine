library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity act_val_controller is
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
end act_val_controller;

architecture act_val_controller_arch of act_val_controller is
    component reg
        generic(
            bits       : natural := 128;
            init_value : natural := 0
        );
        port(
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
            clk   : in STD_LOGIC;
            rst   : in STD_LOGIC;
            rst_2 : in STD_LOGIC;
            inc   : in STD_LOGIC;
            count : out STD_LOGIC_VECTOR(bits - 1 downto 0)
        );
    end component;
    
    ------------------------
    -- Activation storage --
    ------------------------
    signal ld_act_height          : STD_LOGIC;
    signal ld_act_width           : STD_LOGIC;
    signal ld_act_x_z_slice_size  : STD_LOGIC;
    signal ld_act_transfers_no    : STD_LOGIC;
    signal act_transfers_no       : STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS) - 1 downto 0);
    signal rst_transfers_received : STD_LOGIC;
    signal inc_transfers_received : STD_LOGIC;
    signal transfers_received     : STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS) - 1 downto 0);
    
    ---------
    -- FSM --
    ---------
    type tp_addr is
        array(ACT_VAL_BANKS - 1 downto 0) of STD_LOGIC_VECTOR(log_2(ACT_VAL_BRAMS_PER_BANK) + addr_width(ACT_VAL_WIDTH) - 1 downto 0);
    signal addr_0_int : tp_addr;
    signal addr_1_int : tp_addr;
    type tp_state is (
        IDLE,
        STORING_ACT_HEIGHT,
        STORING_ACT_WIDTH,
        STORING_ACT_X_Z_SLICE_SIZE,
        STORING_IMAGE
    );
    signal fsm_cs, fsm_ns: tp_state; 
begin
    -------------------
    -- Image storing --
    -------------------
    -- Activation dimensions
    act_height_reg: reg generic map(log_2(MAX_ACT_HEIGHT), 0)
        port map(clk, rst, ld_act_height,         image_input(log_2(MAX_ACT_HEIGHT) - 1 downto 0),                act_height);
    
    act_width_reg: reg generic map(log_2(MAX_ACT_WIDTH), 0)
        port map(clk, rst, ld_act_width,          image_input(log_2(MAX_ACT_WIDTH) - 1 downto 0),                 act_width);

    act_x_z_slice_size_reg: reg generic map(log_2(MAX_ACT_WIDTH * MAX_ACT_DEPTH), 0)
        port map(clk, rst, ld_act_x_z_slice_size, image_input(log_2(MAX_ACT_WIDTH * MAX_ACT_DEPTH) - 1 downto 0), act_x_z_slice_size);
    
    act_transfers_no_reg: reg generic map(log_2(MAX_ACT_ELEMENTS), 0)
        port map(clk, rst, ld_act_transfers_no,   image_input(log_2(MAX_ACT_ELEMENTS) - 1 downto 0),              act_transfers_no);        
        
    -- Activation element received from the PS
    transfers_received_counter: counter generic map(log_2(MAX_ACT_ELEMENTS), 1)
        port map(clk, rst, rst_transfers_received, inc_transfers_received, transfers_received);                
    
    -- Activation data memory FSM
    act_data_mem_FSM: process(
        fsm_cs, addr_read, act_input,
        store_image, layer, write_element, addr_write,
        new_data, transfers_received, image_input
    )
    begin        
        ld_act_height          <= '0';
        ld_act_width           <= '0';
        ld_act_x_z_slice_size  <= '0';
        ld_act_transfers_no    <= '0';
        rst_transfers_received <= '0';
        inc_transfers_received <= '0';
        image_stored           <= '0';
        fsm_ns                 <= fsm_cs;
        
        for i in 0 to ACT_VAL_BANKS - 1 loop
            addr_0_int(i) <= addr_read(i);
            addr_1_int(i) <= addr_read(i);
            
            mem_input((i + 1) * ACT_VAL_WIDTH - 1 downto i * ACT_VAL_WIDTH) <= act_input(i);
            
            we_0(i) <= '0';
            we_1(i) <= '0';
        end loop;

        case fsm_cs is
            when IDLE =>                                    
                if store_image = '1' then
                    ld_act_transfers_no <= '1';
                    fsm_ns              <= STORING_ACT_HEIGHT;
                -- elsif retrieve_act = '1' then
                --     for i in ACT_VAL_BANKS - 1 downto 0 loop        
                --         addr_1_int(i) <= addr_retrieve(ACT_VAL_BANK_ADDRESS_SIZE - 1 downto 0);
                --     end loop;    
                -- Even layers write in memory_1                
                elsif layer = EVEN then
                    we_1 <= write_element;

                    -- Switch between read & write addrs
                    for i in 0 to ACT_VAL_BANKS - 1 loop
                        if write_element(i) = '1' then                              
                            addr_1_int(i) <= addr_write(i);
                        end if;
                    end loop;
                -- Odd layers write in memory_0
                else
                    we_0 <= write_element;
                    
                    -- Switch between read & write addrs
                    for i in 0 to ACT_VAL_BANKS - 1 loop
                        if write_element(i) = '1' then
                            addr_0_int(i) <= addr_write(i);
                        end if;
                    end loop;
                end if;
           
            when STORING_ACT_HEIGHT =>
                if new_data = '1' then
                    ld_act_height <= '1';
                    fsm_ns        <= STORING_ACT_WIDTH;
                end if;
            
            when STORING_ACT_WIDTH =>
                if new_data = '1' then
                    ld_act_width <= '1';
                    fsm_ns       <= STORING_ACT_X_Z_SLICE_SIZE;
                end if;
            
            when STORING_ACT_X_Z_SLICE_SIZE =>
                if new_data = '1' then
                    ld_act_x_z_slice_size <= '1';
                    fsm_ns                <= STORING_IMAGE;
                end if;

            when STORING_IMAGE =>                    
                if new_data = '1' then
                    -- +++ Consecutive data are stored in consecutive banks +++
                    -- WEs
                    for i in 0 to AXIS_BUS_WIDTH / ACT_VAL_WIDTH - 1 loop
                        we_0(to_uint(transfers_received(log_2(ACT_VAL_BANKS / (AXIS_BUS_WIDTH / ACT_VAL_WIDTH)) - 1 downto 0)      & 
                                                        std_logic_vector(to_unsigned(0, log_2(AXIS_BUS_WIDTH / ACT_VAL_WIDTH)))) + i)   <= '1';
                    end loop;
                    
                    -- Addresses
                    for i in 0 to ACT_VAL_BANKS - 1 loop
                        addr_0_int(i) <= transfers_received(ACT_VAL_BANK_ADDRESS_SIZE + log_2(ACT_VAL_BANKS) - 1 downto log_2(ACT_VAL_BANKS));
                    end loop;
                    
                    -- Data inputs
                    for i in 0 to (ACT_VAL_BANKS * ACT_VAL_WIDTH) / AXIS_BUS_WIDTH - 1 loop
                        mem_input(((i + 1) * AXIS_BUS_WIDTH) - 1 downto i * AXIS_BUS_WIDTH) <= image_input;
                    end loop;
                    
                    -- Done
                    if transfers_received = act_transfers_no then
                        image_stored           <= '1';
                        rst_transfers_received <= '1';
                        fsm_ns                 <= IDLE;
                    else
                        inc_transfers_received <= '1';
                    end if;
                end if;
        end case;
    end process act_data_mem_FSM;    
    
    process(clk)
    begin              
        if rising_edge(clk) then
            if rst = '1' then
                fsm_cs <= IDLE;
            else
                fsm_cs <= fsm_ns;
            end if;
        end if;
    end process;
    
    -------------
    -- Outputs --
    -------------
    outputs: for i in ACT_VAL_BANKS - 1 downto 0 generate
        addr_0((i + 1) * ACT_VAL_BANK_ADDRESS_SIZE - 1 downto i * ACT_VAL_BANK_ADDRESS_SIZE) <= addr_0_int(i);
        addr_1((i + 1) * ACT_VAL_BANK_ADDRESS_SIZE - 1 downto i * ACT_VAL_BANK_ADDRESS_SIZE) <= addr_1_int(i);
    end generate;
end act_val_controller_arch;