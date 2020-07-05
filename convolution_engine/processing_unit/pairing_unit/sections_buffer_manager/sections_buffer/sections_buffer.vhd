library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity sections_buffer is
    port(
        clk : in STD_LOGIC;
        rst : in STD_LOGIC;
        ------------------------------------------
        -- processing_unit_controller interface --
        ------------------------------------------
        start_convolution        : in STD_LOGIC;
        convolution_step_done_in : in STD_LOGIC;
        convolution_done_in      : in STD_LOGIC;
        -------------------------------
        -- act_ind_arbiter interface --
        -------------------------------
        request_ind : out STD_LOGIC;
        ind_granted : in  STD_LOGIC;
        act_ind     : in  STD_LOGIC_VECTOR(ACT_IND_WIDTH - 1 downto 0);
        ------------------------------
        -- filter_manager interface --
        ------------------------------
        filter_ind : in STD_LOGIC_VECTOR(FILTER_IND_WIDTH - 1 downto 0);
        ---------------------------------------
        -- sections_buffer_manager interface --
        ---------------------------------------
        buffer_processed  : in  STD_LOGIC;
        filter_buffer     : out STD_LOGIC_VECTOR(FILTER_IND_WIDTH - 1 downto 0);
        act_buffer        : out STD_LOGIC_VECTOR(ACT_IND_WIDTH - 1 downto 0);
        section_available : out STD_LOGIC;
        ---------------------------------
        -- address_generator interface --
        ---------------------------------
        act_addr_in : in  STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS / ACT_IND_WIDTH) - 1 downto 0);
        act_addr    : out STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS / ACT_IND_WIDTH) - 1 downto 0);
        ----------
        -- Misc --
        ----------
        convolution_step_done : out STD_LOGIC;
        convolution_done      : out STD_LOGIC
    );
end sections_buffer;

architecture sections_buffer_arch of sections_buffer is
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
    
    -- Sections buffer
    signal ld_control  : STD_LOGIC;
    signal ld_sections : STD_LOGIC;
    signal control_in  : STD_LOGIC_VECTOR((1 + 1) - 1 downto 0);
    signal control     : STD_LOGIC_VECTOR((1 + 1) - 1 downto 0);
    
    -- Sections buffer FSM
    type tp_state is (
        UNLOADED,
        LOADING_SECTION,
        LOADED
    );
    signal fsm_cs, fsm_ns: tp_state;
begin
    ---------------------
    -- Sections buffer --
    ---------------------
    -- Sections
    filter_section_buffer_reg : reg generic map(bits => FILTER_IND_WIDTH)
        port map(clk, rst, ld_sections, filter_ind, filter_buffer);
    
    act_section_buffer_reg : reg generic map(bits => ACT_IND_WIDTH)
        port map(clk, rst, ld_sections, act_ind, act_buffer);
    
    -- Control
    control_buffer_reg : reg generic map(bits => 1 + 1)
        port map(clk, rst, ld_control, control_in, control);

    control_in <= convolution_step_done_in & convolution_done_in;
    
    -- Activation base addr
    act_base_addr_reg : reg generic map(bits => log_2(MAX_ACT_ELEMENTS / ACT_IND_WIDTH))
        port map(clk, rst, ld_control, act_addr_in, act_addr);
    
    -- Sections buffer FSM
    sections_buffer_FSM : process(
        fsm_cs,             -- Default                                  
        ind_granted,        -- UNLOADED
        buffer_processed    -- LOADED
    ) 
    begin
        request_ind       <= '0';
        ld_control        <= '0';
        ld_sections       <= '0';
        section_available <= '0';
        fsm_ns            <= fsm_cs;
        
        case fsm_cs is
            when UNLOADED =>
                request_ind <= '1';
                
                if ind_granted = '1' then
                    ld_control <= '1';
                    fsm_ns     <= LOADING_SECTION;
                end if;
            
            when LOADING_SECTION =>                
                ld_sections       <= '1';
                section_available <= '1';                
                fsm_ns            <= LOADED;  
            
            when LOADED =>
                if buffer_processed = '1' then
                    request_ind <= '1';
                    
                    if ind_granted = '1' then
                        ld_control <= '1';
                        fsm_ns     <= LOADING_SECTION;
                    else
                        fsm_ns     <= UNLOADED;
                    end if;
                else
                    section_available <= '1';                    
                end if;
        end case;        
    end process sections_buffer_FSM;
    
    states: process(clk)
    begin              
        if clk'event AND clk = '1' then
            if rst = '1' then
                fsm_cs <= UNLOADED;
            else
                fsm_cs <= fsm_ns;
            end if;
        end if;
    end process states;

    -- Convolution control info
    convolution_step_done <= control(1);
    convolution_done      <= control(0);
end sections_buffer_arch;