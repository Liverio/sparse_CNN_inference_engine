library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity sections_buffer_manager is
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
        ind_served  : in  STD_LOGIC;
        act_ind     : in  STD_LOGIC_VECTOR(ACT_IND_WIDTH - 1 downto 0);
        ------------------------------
        -- filter_manager interface --
        ------------------------------
        filter_ind : in STD_LOGIC_VECTOR(FILTER_IND_WIDTH - 1 downto 0);
        ----------------------------
        -- pairing_unit interface --
        ----------------------------
        section_processed : in STD_LOGIC;
        ---------------------------------
        -- address_generator interface --
        ---------------------------------
        act_addr_in : in  STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS / ACT_IND_WIDTH) - 1 downto 0);
        act_addr    : out STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS / SECTION_WIDTH) - 1 downto 0);
        -----------------------------
        -- matching_unit interface --
        -----------------------------
        section_available : out STD_LOGIC;
        filter_section    : out STD_LOGIC_VECTOR(SECTION_WIDTH - 1 downto 0);
        act_section       : out STD_LOGIC_VECTOR(SECTION_WIDTH - 1 downto 0);
        ----------
        -- Misc --
        ----------
        ind_buffer_processed  : out STD_LOGIC;
        convolution_step_done : out STD_LOGIC;
        convolution_done      : out STD_LOGIC
    );
end sections_buffer_manager;

architecture sections_buffer_manager_arch of sections_buffer_manager is
    component sections_buffer
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
    end component;
    
    component sections_buffer_controller
        port(
            clk               : in  STD_LOGIC;
            rst               : in  STD_LOGIC;
            start_convolution : in  STD_LOGIC;
            request_ind_int   : in  STD_LOGIC_VECTOR(2 - 1 downto 0);
            convolution_done  : in  STD_LOGIC;
            request_ind       : out STD_LOGIC
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
    
    ----------------------
    -- Sections buffers --
    ----------------------
    type tp_buffer_array is
        array(0 to 2 - 1) of STD_LOGIC_VECTOR(ACT_IND_WIDTH - 1 downto 0);
    type tp_act_addr_array is
        array(0 to 2 - 1) of STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS / ACT_IND_WIDTH) - 1 downto 0);
    signal filter_buffer             : tp_buffer_array;
    signal act_buffer                : tp_buffer_array;
    signal act_addr_int              : tp_act_addr_array;
    signal ind_granted_int           : STD_LOGIC_VECTOR(2 - 1 downto 0);
    signal ind_served_int            : STD_LOGIC_VECTOR(2 - 1 downto 0);
    signal buffer_processed_int      : STD_LOGIC_VECTOR(2 - 1 downto 0);
    signal request_ind_int           : STD_LOGIC_VECTOR(2 - 1 downto 0);
    signal section_available_int     : STD_LOGIC_VECTOR(2 - 1 downto 0);
    signal convolution_step_done_int : STD_LOGIC_VECTOR(2 - 1 downto 0);
    signal convolution_done_int      : STD_LOGIC_VECTOR(2 - 1 downto 0);
    
    -------------------------
    -- Sections buffer FSM --
    -------------------------
    signal current_buffer_cs,       current_buffer_ns       : STD_LOGIC_VECTOR(1 - 1 downto 0);
    signal buffer_to_be_granted_cs, buffer_to_be_granted_ns : STD_LOGIC_VECTOR(1 - 1 downto 0);
begin
    ----------------------
    -- Sections buffers --
    ----------------------
    sections_buffers_I: for i in 0 to 2 - 1 generate
        sections_buffer_I: sections_buffer
            port map(
                clk => clk,
                rst => rst,
                ------------------------------------------
                -- processing_unit_controller interface --
                ------------------------------------------
                start_convolution        => start_convolution,
                convolution_step_done_in => convolution_step_done_in,
                convolution_done_in      => convolution_done_in,
                -------------------------------
                -- act_ind_arbiter interface --
                -------------------------------
                request_ind => request_ind_int(i),
                ind_granted => ind_granted_int(i),
                act_ind     => act_ind,
                ------------------------------
                -- filter_manager interface --
                ------------------------------
                filter_ind => filter_ind,
                ---------------------------------------
                -- sections_buffer_manager interface --
                ---------------------------------------
                buffer_processed  => buffer_processed_int(i),
                filter_buffer     => filter_buffer(i),
                act_buffer        => act_buffer(i),
                section_available => section_available_int(i),
                ---------------------------------
                -- address_generator interface --
                ---------------------------------
                act_addr_in => act_addr_in,
                act_addr    => act_addr_int(i),
                ----------
                -- Misc --
                ----------
                convolution_step_done => convolution_step_done_int(i),
                convolution_done      => convolution_done_int(i)
        );
    end generate;

    -- Control of which buffer is being granted with a new section
    buffer_to_be_granted_ns <= NOT(buffer_to_be_granted_cs) when ind_granted = '1' else buffer_to_be_granted_cs;
    
    -- A section is inmediately available to be processed by the matching unit
    section_available <= section_available_int(0) OR section_available_int(1);

    control_regs: process(clk)
    begin              
        if clk'event AND clk = '1' then
            if rst = '1' then
                current_buffer_cs <= "0";
                buffer_to_be_granted_cs <= "0";
            else
                current_buffer_cs <= current_buffer_ns;
                buffer_to_be_granted_cs <= buffer_to_be_granted_ns;
            end if;
        end if;
    end process control_regs;

    buffer_larger_than_section: if ACT_IND_WIDTH > SECTION_WIDTH generate
        signal rst_current_section : STD_LOGIC;
        signal inc_current_section : STD_LOGIC;
        signal current_section     : STD_LOGIC_VECTOR(log_2(ACT_IND_WIDTH / SECTION_WIDTH) - 1 downto 0);
    begin
        sections_buffers_control: for i in 0 to 2 - 1 generate
            ind_granted_int(i) <= '1' when ind_granted                       = '1' AND
                                            to_uint(buffer_to_be_granted_cs) = i   else
                                  '0';
            
            buffer_processed_int(i) <= '1' when section_processed          = '1'                               AND
                                                to_uint(current_section)   = ACT_IND_WIDTH / SECTION_WIDTH - 1 AND
                                                to_uint(current_buffer_cs) = i                                 else
                                       '0';
        end generate;
        
        --------------------
        -- Buffer control --
        --------------------
        -- Control of which buffer is being processed
        current_buffer_ns <= NOT(current_buffer_cs) when section_processed        = '1'                               AND
                                                         to_uint(current_section) = ACT_IND_WIDTH / SECTION_WIDTH - 1 else
                             current_buffer_cs;
        
        ---------------------
        -- Section control --
        ---------------------
        section_counter: counter generic map(bits => log_2(ACT_IND_WIDTH / SECTION_WIDTH))
            port map(clk, rst, rst_current_section, inc_current_section, current_section);

        rst_current_section <= '1' when section_processed = '1' AND to_uint(current_section)  = ACT_IND_WIDTH / SECTION_WIDTH - 1 else '0';
        inc_current_section <= '1' when section_processed = '1' AND to_uint(current_section) /= ACT_IND_WIDTH / SECTION_WIDTH - 1 else '0';
        
        -- Outputs
        filter_section       <= vector_slice(filter_buffer(to_uint(current_buffer_cs)), (ACT_IND_WIDTH / SECTION_WIDTH - 1) - to_uint(current_section), SECTION_WIDTH);
        act_section          <= vector_slice(act_buffer(to_uint(current_buffer_cs))   , (ACT_IND_WIDTH / SECTION_WIDTH - 1) - to_uint(current_section), SECTION_WIDTH);
        ind_buffer_processed <= buffer_processed_int(0) OR buffer_processed_int(1);
        act_addr             <= std_logic_vector(to_unsigned(to_uint(act_addr_int(to_uint(current_buffer_cs)) & current_section), log_2(MAX_ACT_ELEMENTS / SECTION_WIDTH)));
    end generate;
    
    buffer_equal_to_section: if ACT_IND_WIDTH = SECTION_WIDTH generate
    begin
        sections_buffers_control: for i in 2 - 1 downto 0 generate
            ind_granted_int(i) <= '1' when ind_granted                      = '1' AND
                                           to_uint(buffer_to_be_granted_cs) = i   else
                                  '0';
            
            buffer_processed_int(i)  <= '1' when section_processed          = '1' AND
                                                 to_uint(current_buffer_cs) = i   else
                                        '0';
        end generate;
        
        --------------------
        -- Buffer control --
        --------------------
        -- Control of which buffer is being processed
        current_buffer_ns <= NOT(current_buffer_cs) when section_processed = '1' else current_buffer_cs;        
        
        ---------------------
        -- Section control --
        ---------------------
        -- Outputs
        filter_section       <= filter_buffer(to_uint(current_buffer_cs));
        act_section          <= act_buffer(to_uint(current_buffer_cs));
        ind_buffer_processed <= buffer_processed_int(0) OR buffer_processed_int(1);
        act_addr             <= act_addr_int(to_uint(current_buffer_cs));
    end generate;    

    --------------------------------
    -- Sections buffer controller --
    --------------------------------
    sections_buffer_controller_I: sections_buffer_controller
        port map(
            clk               => clk,
            rst               => rst,
            start_convolution => start_convolution,
            request_ind_int   => request_ind_int,
            convolution_done  => convolution_done_in,
            request_ind       => request_ind
        );
    
    -------------
    -- Outputs --
    -------------
    convolution_step_done <= convolution_step_done_int(to_uint(current_buffer_cs));
    convolution_done      <= convolution_done_int(to_uint(current_buffer_cs));    
end sections_buffer_manager_arch;