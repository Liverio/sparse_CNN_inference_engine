library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity matching_unit is
    port(
        clk : in STD_LOGIC; 
        rst : in STD_LOGIC;
        ------------------------------------------
        -- processing_unit_controller interface --
        ------------------------------------------
        start_convolution     : in STD_LOGIC;
        convolution_step_done : in STD_LOGIC;
        convolution_done      : in STD_LOGIC;
        ---------------------------------------
        -- sections_buffer_manager interface --
        ---------------------------------------
        new_section_available : in STD_LOGIC;
        filter_input          : in STD_LOGIC_VECTOR(SECTION_WIDTH - 1 downto 0);
        act_input             : in STD_LOGIC_VECTOR(SECTION_WIDTH - 1 downto 0);
        ----------------------------
        -- match_buffer interface --
        ----------------------------
        match_accepted : in  STD_LOGIC;
        found          : out STD_LOGIC;
        no_match       : out STD_LOGIC;
        position       : out STD_LOGIC_VECTOR(log_2(SECTION_WIDTH) - 1 downto 0);
        ---------------------------------
        -- address_generator interface --
        ---------------------------------
        last        : out STD_LOGIC;
        filter_jump : out STD_LOGIC_VECTOR(log_2(SECTION_WIDTH + 1) - 1 downto 0);
        filter_rest : out STD_LOGIC_VECTOR(log_2(SECTION_WIDTH + 1) - 1 downto 0)
    );
end matching_unit;

architecture matching_unit_arch of matching_unit is
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
    
    component priority_encoder
        generic(
            input_width : natural := 2
        );
        port(
            input    : in  STD_LOGIC_VECTOR(input_width - 1 downto 0);
            found    : out STD_LOGIC;
            position : out STD_LOGIC_VECTOR(log_2(input_width) - 1 downto 0)
        );
    end component;
    
    component tree_adder
        generic(
            input_width : positive := 32
        );
        port(
            input  : in  STD_LOGIC_VECTOR(input_width - 1 downto 0);
            output : out STD_LOGIC_VECTOR(log_2(input_width + 1) - 1 downto 0)
        );
    end component;
    
    -- Matching
    signal rst_mask       : STD_LOGIC;
    signal new_mask       : STD_LOGIC_VECTOR(SECTION_WIDTH - 1 downto 0);
    signal current_mask   : STD_LOGIC_VECTOR(SECTION_WIDTH - 1 downto 0);
    signal matching       : STD_LOGIC_VECTOR(SECTION_WIDTH - 1 downto 0);
    signal next_matching  : STD_LOGIC_VECTOR(SECTION_WIDTH - 1 downto 0);
    signal last_match     : STD_LOGIC;
    signal no_match_found : STD_LOGIC;
    
    -- Match selector
    signal match_found    : STD_LOGIC;
    signal match_position : STD_LOGIC_VECTOR(log_2(SECTION_WIDTH) - 1 downto 0);
    
    -- Matching unit FSM
    type tp_state is (
        IDLE,
        WAITING_FOR_SECTION,
        PROCESSING_SECTION
    );
    signal fsm_cs, fsm_ns: tp_state;
begin        
    --------------
    -- Matching -- 
    --------------
    mask_reg : reg generic map(bits => SECTION_WIDTH)
        port map(clk, rst OR rst_mask, match_accepted, new_mask, current_mask);

    new_mask_composer: for i in SECTION_WIDTH - 1 downto 0 generate
        new_mask(i) <= '1' when match_found = '1' AND i >= to_uint(match_position) else current_mask(i);
    end generate;
        
    matching      <= act_input AND filter_input AND NOT(current_mask);    
    next_matching <= act_input AND filter_input AND NOT(new_mask);
    
    selector: priority_encoder
        generic map(
            input_width => SECTION_WIDTH
        )
        port map(
            input    => matching,
            found    => match_found,
            position => match_position
        );

    last_match     <= '1' when next_matching = std_logic_vector(to_unsigned(0, section_width)) else '0';
    no_match_found <= '1' when matching = std_logic_vector(to_unsigned(0, section_width)) else '0';
    
    -----------
    -- Jumps -- 
    -----------
    filter_jump_counter : tree_adder
        generic map(
            input_width => SECTION_WIDTH
        )
        port map(
            input  => filter_input AND NOT(current_mask) AND new_mask,
            output => filter_jump
        );
        
    -- Remaining filter values not matched
    filter_rest_counter : tree_adder
        generic map(
            input_width => SECTION_WIDTH
        )
        port map(
            input  => filter_input AND NOT(new_mask),
            output => filter_rest
        );
    
    -- Matching unit FSM
    convolution_controller_FSM : process(
        fsm_cs,                                                     -- Default
        start_convolution,                                          -- IDLE
        new_section_available,                                      -- WAITING_FOR_SECTION
        match_found, match_position, last_match, no_match_found,    -- PROCESSING_SECTION
        convolution_done, convolution_step_done, match_accepted     -- PROCESSING_SECTION
    )
    begin
        rst_mask <= '0';
        found    <= '0';
        position <= (others => '0');
        last     <= '0';
        no_match <= '0';
        fsm_ns   <= fsm_cs;
        
        case fsm_cs is
            when IDLE =>
                if start_convolution = '1' then
                    fsm_ns <= WAITING_FOR_SECTION;
                end if;
            
            when WAITING_FOR_SECTION =>
                if new_section_available = '1' then
                    rst_mask <= '1';
                    fsm_ns   <= PROCESSING_SECTION;
                end if;
            
            when PROCESSING_SECTION =>
                found    <= match_found;
                position <= (SECTION_WIDTH - 1) - match_position;
                last     <= last_match;
                no_match <= no_match_found;
                
                
                if ((match_accepted = '1' AND last_match = '1') OR no_match_found = '1') AND convolution_done = '1' then
                    fsm_ns <= IDLE;                
                elsif (match_accepted = '1' AND last_match = '1') OR no_match_found = '1' then
                    rst_mask <= '1';
                    
                    -- Should be a very rare case
                    if new_section_available = '0' then
                        fsm_ns <= WAITING_FOR_SECTION;
                    end if;    
                end if;
        end case;        
    end process convolution_controller_FSM;
    
    process(clk)
    begin              
        if clk'event AND clk = '1' then
            if rst = '1' then
                fsm_cs <= IDLE;
            else
                fsm_cs <= fsm_ns;
            end if;
        end if;
    end process;
end matching_unit_arch;