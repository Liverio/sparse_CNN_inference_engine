library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity act_ind_controller is
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
end act_ind_controller;

architecture act_ind_controller_arch of act_ind_controller is
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
    
    --------------------------------
    -- Activation storage counter --
    --------------------------------
    signal act_transfers_no      : STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS / AXIS_BUS_WIDTH) - 1 downto 0);
    signal transfer_received     : STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS / AXIS_BUS_WIDTH) - 1 downto 0);
    signal rst_transfer_received : STD_LOGIC;
    signal inc_transfer_received : STD_LOGIC;
    
    ---------
    -- FSM --
    ---------
    type tp_addr is
        array(0 to ACT_IND_BANKS - 1) of STD_LOGIC_VECTOR(log_2(ACT_IND_BRAMS_PER_BANK) + addr_width(ACT_IND_WIDTH) - 1 downto 0);
    signal addr_0_int, addr_1_int: tp_addr;
    type tp_state is (
        IDLE,
        STORING_IMAGE_INDICES
    );
    signal fsm_cs, fsm_ns: tp_state;
begin
    ---------------------------
    -- Image indices storage --
    ---------------------------
    act_transfers_no_reg: reg generic map(log_2(MAX_ACT_ELEMENTS / AXIS_BUS_WIDTH), 0)
        port map(clk, rst, store_image, image_input(log_2(MAX_ACT_ELEMENTS / AXIS_BUS_WIDTH) - 1 downto 0), act_transfers_no);
        
    -- Activation ind elements received from the PS
    transfer_received_counter: counter generic map(log_2(MAX_ACT_ELEMENTS / AXIS_BUS_WIDTH), 1)
        port map(clk, rst, rst_transfer_received, inc_transfer_received, transfer_received);
    
    -- Activation ind FSM
    act_ind_FSM: process(
        fsm_cs, addrs_read, act_input,                              -- Default
        store_image, image_input, write_element, layer, write_addr, -- IDLE
        new_data, transfer_received)                                -- STORING_IMAGE_INDICES
    begin
        rst_transfer_received <= '0';
        inc_transfer_received <= '0';
        image_stored          <= '0';
        fsm_ns                <= fsm_cs;
        for i in ACT_IND_BANKS - 1 downto 0 loop
            addr_0_int(i) <= addrs_read(i)(log_2(ACT_IND_BRAMS_PER_BANK) + addr_width(ACT_IND_WIDTH) + log_2(ACT_IND_BANKS) - 1 downto log_2(ACT_IND_BANKS));
            addr_1_int(i) <= addrs_read(i)(log_2(ACT_IND_BRAMS_PER_BANK) + addr_width(ACT_IND_WIDTH) + log_2(ACT_IND_BANKS) - 1 downto log_2(ACT_IND_BANKS));

            mem_input((i + 1) * ACT_IND_WIDTH - 1 downto i * ACT_IND_WIDTH) <= act_input;
            
            we_0(i) <= '0';
            we_1(i) <= '0';
        end loop;

        case fsm_cs is
            when IDLE =>                                    
                -- Store #transfers
                if store_image = '1' then
                    fsm_ns <= STORING_IMAGE_INDICES;
                end if;
            
            when STORING_IMAGE_INDICES =>                    
                if new_data = '1' then
                    -- Consecutive data are stored in consecutive banks
                    we_0(to_uint(transfer_received(log_2(ACT_IND_BANKS) - 1 downto 0))) <= '1';
                    
                    for i in ACT_IND_BANKS - 1 downto 0 loop 
                        addr_0_int(i)                                                <=
                            transfer_received(log_2(ACT_IND_BRAMS_PER_BANK) + addr_width(ACT_IND_WIDTH) + log_2(ACT_IND_BANKS) - 1 downto log_2(ACT_IND_BANKS));
                        mem_input((i + 1) * ACT_IND_WIDTH - 1 downto i * ACT_IND_WIDTH) <=
                            image_input;
                    end loop;
                    
                    -- Done
                    if transfer_received = act_transfers_no then
                        image_stored          <= '1';
                        rst_transfer_received <= '1';
                        fsm_ns                <= IDLE;
                    else
                        inc_transfer_received <= '1';
                    end if;
                end if;
        end case;
    end process act_ind_FSM;
    
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
    outputs: for i in ACT_IND_BANKS - 1 downto 0 generate
        addr_0((i + 1) * (log_2(ACT_IND_BRAMS_PER_BANK) + addr_width(ACT_IND_WIDTH)) - 1 downto i * (log_2(ACT_IND_BRAMS_PER_BANK) + addr_width(ACT_IND_WIDTH))) <= addr_0_int(i);
        addr_1((i + 1) * (log_2(ACT_IND_BRAMS_PER_BANK) + addr_width(ACT_IND_WIDTH)) - 1 downto i * (log_2(ACT_IND_BRAMS_PER_BANK) + addr_width(ACT_IND_WIDTH))) <= addr_1_int(i);
    end generate;
end act_ind_controller_arch;