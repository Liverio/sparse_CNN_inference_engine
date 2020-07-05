library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity pairing_unit is
    port(
        clk : in STD_LOGIC;
        rst : in STD_LOGIC;
        ------------------------------------------
        -- processing_unit_controller interface --
        ------------------------------------------
        start_convolution     : in  STD_LOGIC;
        convolution_step_done : out STD_LOGIC;
        convolution_done      : out STD_LOGIC;
        ----------------------------------
        -- act_values_manager interface --
        ----------------------------------
        act_height         : in STD_LOGIC_VECTOR(log_2(MAX_ACT_HEIGHT) - 1 downto 0);
        act_width          : in STD_LOGIC_VECTOR(log_2(MAX_ACT_WIDTH) - 1 downto 0);
        act_x_z_slice_size : in STD_LOGIC_VECTOR(log_2(MAX_ACT_WIDTH * MAX_ACT_DEPTH) - 1 downto 0);
        ------------------------------
        -- filter_manager interface --
        ------------------------------
        filter_height : in STD_LOGIC_VECTOR(log_2(MAX_FILTER_HEIGHT) - 1 downto 0);
        filter_width  : in STD_LOGIC_VECTOR(log_2(MAX_FILTER_WIDTH) - 1 downto 0);
        filter_depth  : in STD_LOGIC_VECTOR(log_2(MAX_FILTER_DEPTH) - 1 downto 0);
        filter_no     : in STD_LOGIC_VECTOR(log_2(MAX_FILTERS) - 1 downto 0);
        filters_no    : in STD_LOGIC_VECTOR(log_2(MAX_FILTERS) - 1 downto 0);
        -------------------------------
        -- act_ind_arbiter interface --
        -------------------------------
        request_ind  : out STD_LOGIC;
        act_ind_addr : out STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS / ACT_IND_WIDTH) - 1 downto 0);
        ind_granted  : in  STD_LOGIC;
        ind_served   : in  STD_LOGIC;
        act_ind      : in  STD_LOGIC_VECTOR(ACT_IND_WIDTH - 1 downto 0);
        ----------------------------------
        -- filter_ind_manager interface --
        ----------------------------------
        filter_ind_addr : out STD_LOGIC_VECTOR(log_2(MAX_FILTER_ELEMENTS / FILTER_IND_WIDTH) - 1 downto 0);
        filter_ind      : in  STD_LOGIC_VECTOR(FILTER_IND_WIDTH - 1 downto 0);
        -----------------------------
        -- pair_selector interface --
        -----------------------------
        filter_addrs : out tp_match_buffer_filter;
        act_addrs    : out tp_match_buffer_act;
        pair_taken   : in  STD_LOGIC_VECTOR(PAIRING_BUFFER_DEPTH - 1 downto 0);
        ---------------------------------------
        -- act_values_read_arbiter interface --
        ---------------------------------------
        pairs_available : out STD_LOGIC_VECTOR(PAIRING_BUFFER_DEPTH - 1 downto 0);
        ---------------------------------
        -- MAC_output_buffer interface --
        ---------------------------------
        new_act_val_addr : out STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS) - 1 downto 0)
    );
end pairing_unit;

architecture pairing_unit_arch of pairing_unit is
    component sections_buffer_manager
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
    end component;
    
    component matching_unit
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
    end component;
    
    component addr_generator
        port(
            clk : in STD_LOGIC;
            rst : in STD_LOGIC;
            ------------------------------------------
            -- processing_unit_controller interface --
            ------------------------------------------
            start_convolution     : in STD_LOGIC;
            convolution_step_done : in STD_LOGIC;
            -------------------------------
            -- act_ind_arbiter interface --
            -------------------------------
            ind_granted : in STD_LOGIC;
            ---------------------------------------
            -- sections_buffer_manager interface --
            ---------------------------------------
            ind_buffer_processed : in STD_LOGIC;
            act_base             : in STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS / SECTION_WIDTH) - 1 downto 0);
            -----------------------------
            -- matching_unit interface --
            -----------------------------
            section_processed  : in STD_LOGIC;
            match_processed    : in STD_LOGIC;
            last_match         : in STD_LOGIC;
            no_match           : in STD_LOGIC;
            filter_jump        : in STD_LOGIC_VECTOR(log_2(SECTION_WIDTH + 1) - 1 downto 0);
            filter_rest        : in STD_LOGIC_VECTOR(log_2(SECTION_WIDTH + 1) - 1 downto 0);
            act_section_offset : in STD_LOGIC_VECTOR(log_2(SECTION_WIDTH) - 1 downto 0);
            ---------------------------
            -- act_manager interface --
            ---------------------------
            act_x_z_slice_size  : in  STD_LOGIC_VECTOR(log_2(MAX_ACT_WIDTH * MAX_ACT_DEPTH) - 1 downto 0);
            filter_depth        : in  STD_LOGIC_VECTOR(log_2(MAX_FILTER_DEPTH) - 1 downto 0);
            act_ind_addr        : out STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS / ACT_IND_WIDTH) - 1 downto 0);
            act_val_addr        : out STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS) - 1 downto 0);
            new_act_val_addr    : out STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS) - 1 downto 0);
            --------------------------------------
            -- convolution_controller interface --
            --------------------------------------
            ind_filter_inc_x          : in STD_LOGIC;
            ind_filter_inc_y          : in STD_LOGIC;
            ind_filter_inc_z          : in STD_LOGIC;
            ind_act_inc_x             : in STD_LOGIC;
            ind_act_inc_y             : in STD_LOGIC;
            ind_convolution_step_done : in STD_LOGIC;
            ------------------------------
            -- filter_manager interface --
            ------------------------------
            filter_no       : in  STD_LOGIC_VECTOR(log_2(MAX_FILTERS) - 1 downto 0);
            filters_no      : in  STD_LOGIC_VECTOR(log_2(MAX_FILTERS) - 1 downto 0);
            filter_ind_addr : out STD_LOGIC_VECTOR(log_2(MAX_FILTER_ELEMENTS / FILTER_IND_WIDTH) - 1 downto 0);
            filter_val_addr : out STD_LOGIC_VECTOR(log_2(MAX_FILTER_ELEMENTS) - 1 downto 0)
        );
    end component;
    
    component match_buffer
        port(
            clk : in std_logic;
            rst : in std_logic;
            -----------------------------
            -- matching_unit interface --
            -----------------------------
            new_pair_ready : in STD_LOGIC;
            ------------------------------
            -- addr_generator interface --
            ------------------------------
            filter_addr      : in  STD_LOGIC_VECTOR(log_2(MAX_FILTER_ELEMENTS) - 1 downto 0);
            act_addr         : in  STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS) - 1 downto 0);
            new_act_addr     : in  STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS) - 1 downto 0);
            new_act_addr_out : out STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS) - 1 downto 0);
            -----------------------------
            -- pair_selector interface --
            -----------------------------
            pair_taken   : in  STD_LOGIC_VECTOR(PAIRING_BUFFER_DEPTH - 1 downto 0);
            filter_addrs : out tp_match_buffer_filter;
            act_addrs    : out tp_match_buffer_act;
            ----------
            -- Misc --
            ----------
            last_pair_step        : in  STD_LOGIC;
            last_pair             : in  STD_LOGIC;
            buffer_full           : out STD_LOGIC;
            convolution_step_done : out STD_LOGIC;
            convolution_done      : out STD_LOGIC;
            ---------------------------------------
            -- act_values_read_arbiter interface --
            ---------------------------------------
            pairs : out STD_LOGIC_VECTOR(PAIRING_BUFFER_DEPTH - 1 downto 0)
        );
    end component;
    
    component convolution_controller
        port(
            clk : in STD_LOGIC;
            rst : in STD_LOGIC;
            ----------------------------------
            -- act_values_manager interface --
            ----------------------------------
            act_height    : in STD_LOGIC_VECTOR(log_2(MAX_ACT_HEIGHT) - 1 downto 0);
            act_width     : in STD_LOGIC_VECTOR(log_2(MAX_ACT_WIDTH) - 1 downto 0);
            ------------------------------
            -- filter_manager interface --
            ------------------------------
            filter_height : in STD_LOGIC_VECTOR(log_2(MAX_FILTER_HEIGHT) - 1 downto 0);
            filter_width  : in STD_LOGIC_VECTOR(log_2(MAX_FILTER_WIDTH) - 1 downto 0);
            filter_depth  : in STD_LOGIC_VECTOR(log_2(MAX_FILTER_DEPTH) - 1 downto 0);
            -------------------------------
            -- act_ind_arbiter interface --
            -------------------------------
            ind_granted : in STD_LOGIC;
            ---------------------------------
            -- address_generator interface --
            ---------------------------------
            filter_inc_x : out STD_LOGIC;
            filter_inc_y : out STD_LOGIC;
            filter_inc_z : out STD_LOGIC;
            act_inc_x    : out STD_LOGIC;
            act_inc_y    : out STD_LOGIC;
            ----------
            -- Misc --
            ----------
            convolution_step_done : out STD_LOGIC;
            convolution_done      : out STD_LOGIC
        );
    end component;    
    
    -- Sections buffer
    signal filter_section               : STD_LOGIC_VECTOR(SECTION_WIDTH - 1 downto 0);
    signal act_section                  : STD_LOGIC_VECTOR(SECTION_WIDTH - 1 downto 0);
    signal section_available            : STD_LOGIC;
    signal ind_buffer_processed         : STD_LOGIC;    
    signal convolution_step_done_buffer : STD_LOGIC;
    signal convolution_done_buffer      : STD_LOGIC;
    
    -- Matching unit
    signal match_found    : STD_LOGIC;
    signal no_match       : STD_LOGIC;
    signal match_position : STD_LOGIC_VECTOR(log_2(SECTION_WIDTH) - 1 downto 0);
    signal last_match     : STD_LOGIC;
    signal filter_jump    : STD_LOGIC_VECTOR(log_2(SECTION_WIDTH + 1) - 1 downto 0);
    signal filter_rest    : STD_LOGIC_VECTOR(log_2(SECTION_WIDTH + 1) - 1 downto 0);
    
    -- Address generator
    signal act_base              : STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS / SECTION_WIDTH) - 1 downto 0);
    signal act_ind_addr_int      : STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS / ACT_IND_WIDTH) - 1 downto 0);
    signal filter_val_addr       : STD_LOGIC_VECTOR(log_2(MAX_FILTER_ELEMENTS) - 1 downto 0);
    signal act_val_addr          : STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS) - 1 downto 0);
    signal next_new_act_val_addr : STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS) - 1 downto 0);
    
    -- Match buffer
    signal match_buffer_full : STD_LOGIC;
    
    -- Convolution controller
    signal filter_inc_x              : STD_LOGIC;
    signal filter_inc_y              : STD_LOGIC;
    signal filter_inc_z              : STD_LOGIC;
    signal act_inc_x                 : STD_LOGIC;
    signal act_inc_y                 : STD_LOGIC;
    signal convolution_step_done_int : STD_LOGIC;
    signal convolution_done_int      : STD_LOGIC;
    signal ind_filter_inc_x          : STD_LOGIC;
    signal ind_filter_inc_y          : STD_LOGIC;
    signal ind_filter_inc_z          : STD_LOGIC;
    signal ind_act_inc_x             : STD_LOGIC;
    signal ind_act_inc_y             : STD_LOGIC;
    signal ind_convolution_step_done : STD_LOGIC;
    signal ind_convolution_done      : STD_LOGIC;
    
    -- Common
    signal section_processed    : STD_LOGIC;
    signal match_buffer_flushed : STD_LOGIC;
begin
    section_processed <= (last_match AND NOT(match_buffer_full)) OR no_match;
    
    ----------------------------
    -- Section buffer manager --
    ----------------------------
    sections_buffer_manager_I : sections_buffer_manager
        port map(
            clk => clk,
            rst => rst,
            ------------------------------------------
            -- processing_unit_controller interface --
            ------------------------------------------
            start_convolution        => start_convolution,
            convolution_step_done_in => convolution_step_done_int,
            convolution_done_in      => convolution_done_int,
            -------------------------------
            -- act_ind_arbiter interface --
            -------------------------------
            request_ind => request_ind,
            ind_granted => ind_granted,
            ind_served  => ind_served,
            act_ind     => act_ind,
            ------------------------------
            -- filter_manager interface --
            ------------------------------
            filter_ind => filter_ind,
            ----------------------------
            -- pairing_unit interface --
            ----------------------------
            section_processed => section_processed,
            ---------------------------------
            -- address_generator interface --
            ---------------------------------
            act_addr_in => act_ind_addr_int,
            act_addr    => act_base,
            -----------------------------
            -- matching_unit interface --
            -----------------------------
            section_available => section_available,
            filter_section    => filter_section,
            act_section       => act_section,
            ----------
            -- Misc --
            ----------
            ind_buffer_processed  => ind_buffer_processed,    
            convolution_step_done => convolution_step_done_buffer,
            convolution_done      => convolution_done_buffer
        );        

    -------------------
    -- Matching unit --
    -------------------
    matching_unit_I : matching_unit
        port map(
            clk => clk,
            rst => rst,
            ------------------------------------------
            -- processing_unit_controller interface --
            ------------------------------------------
            start_convolution     => start_convolution,
            convolution_step_done => convolution_step_done_buffer AND ind_buffer_processed,
            convolution_done      => convolution_done_buffer      AND ind_buffer_processed,
            ---------------------------------------
            -- sections_buffer_manager interface --
            ---------------------------------------
            new_section_available => section_available,
            filter_input          => filter_section,
            act_input             => act_section,
            ----------------------------
            -- match_buffer interface --
            ----------------------------
            match_accepted => NOT(match_buffer_full),
            found          => match_found,
            no_match       => no_match,
            position       => match_position,
            ---------------------------------
            -- address_generator interface --
            ---------------------------------
            last        => last_match,
            filter_jump => filter_jump,
            filter_rest => filter_rest
        );
 
    -----------------------
    -- Address generator --
    -----------------------
    addr_generator_I: addr_generator
        port map(---- INPUTS ----
            clk => clk,
            rst => rst,
            ------------------------------------------
            -- processing_unit_controller interface --
            ------------------------------------------
            start_convolution     => start_convolution,
            convolution_step_done => convolution_step_done_buffer AND ind_buffer_processed,
            -------------------------------
            -- act_ind_arbiter interface --
            -------------------------------
            ind_granted          => ind_granted,
            ---------------------------------------
            -- sections_buffer_manager interface --
            ---------------------------------------
            ind_buffer_processed => ind_buffer_processed,
            act_base             => act_base,
            -----------------------------
            -- matching_unit interface --
            -----------------------------
            section_processed  => section_processed,
            match_processed    => match_found AND NOT(match_buffer_full),
            last_match         => last_match,
            no_match           => no_match,
            filter_jump        => filter_jump,
            filter_rest        => filter_rest,
            act_section_offset => match_position,
            ---------------------------
            -- act_manager interface --
            ---------------------------
            act_x_z_slice_size  => act_x_z_slice_size,
            filter_depth        => filter_depth,
            act_ind_addr        => act_ind_addr_int,
            act_val_addr        => act_val_addr,
            new_act_val_addr    => next_new_act_val_addr,
            --------------------------------------
            -- convolution_controller interface --
            --------------------------------------
            ind_filter_inc_x          => filter_inc_x,
            ind_filter_inc_y          => filter_inc_y,
            ind_filter_inc_z          => filter_inc_z,
            ind_act_inc_x             => act_inc_x,
            ind_act_inc_y             => act_inc_y,
            ind_convolution_step_done => convolution_step_done_int,                 
            ------------------------------
            -- filter_manager interface --
            ------------------------------
            filter_no          => filter_no,
            filters_no         => filters_no,
            filter_ind_addr    => filter_ind_addr,
            filter_val_addr    => filter_val_addr
        );
    
    act_ind_addr <= act_ind_addr_int;
    
    ------------------
    -- Match buffer --
    ------------------
    match_buffer_I : match_buffer
        port map(
            clk => clk,
            rst => rst,
            -----------------------------
            -- matching_unit interface --
            -----------------------------
            new_pair_ready => match_found,
            ------------------------------
            -- addr_generator interface --
            ------------------------------
            filter_addr      => filter_val_addr,
            act_addr         => act_val_addr,
            new_act_addr     => next_new_act_val_addr,
            new_act_addr_out => new_act_val_addr,
            -----------------------------
            -- pair_selector interface --
            -----------------------------
            pair_taken   => pair_taken,
            filter_addrs => filter_addrs,
            act_addrs    => act_addrs,
            ----------
            -- Misc --
            ----------
            last_pair_step        => convolution_step_done_buffer AND ind_buffer_processed,
            last_pair             => convolution_done_buffer      AND ind_buffer_processed,
            buffer_full           => match_buffer_full,
            convolution_step_done => match_buffer_flushed,
            convolution_done      => convolution_done,
            ---------------------------------------
            -- act_values_read_arbiter interface --
            ---------------------------------------
            pairs => pairs_available
        );
     
    ----------------------------
    -- Convolution controller --
    ----------------------------
    convolution_controller_I : convolution_controller
        port map(
            clk => clk,
            rst => rst,
            ----------------------------------
            -- act_values_manager interface --
            ----------------------------------
            act_height => act_height,
            act_width  => act_width,
            ------------------------------
            -- filter_manager interface --
            ------------------------------
            filter_height => filter_height,
            filter_width  => filter_width,
            filter_depth  => filter_depth,
            -------------------------------
            -- act_ind_arbiter interface --
            -------------------------------
            ind_granted => ind_granted,
            ---------------------------------
            -- address_generator interface --
            ---------------------------------
            filter_inc_x => filter_inc_x,
            filter_inc_y => filter_inc_y,
            filter_inc_z => filter_inc_z,                 
            act_inc_x    => act_inc_x,
            act_inc_y    => act_inc_y,
            ----------
            -- Misc --
            ----------
            convolution_step_done => convolution_step_done_int,
            convolution_done      => convolution_done_int
        );

    -- Outputs
    convolution_step_done <= match_buffer_flushed;
end pairing_unit_arch;