library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity addr_generator is
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
        act_x_z_slice_size : in  STD_LOGIC_VECTOR(log_2(MAX_ACT_WIDTH * MAX_ACT_DEPTH) - 1 downto 0);
        filter_depth       : in  STD_LOGIC_VECTOR(log_2(MAX_FILTER_DEPTH) - 1 downto 0);
        act_ind_addr       : out STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS / ACT_IND_WIDTH) - 1 downto 0);
        act_val_addr       : out STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS) - 1 downto 0);
        new_act_val_addr   : out STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS) - 1 downto 0);
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
end addr_generator;

architecture addr_generator_arch of addr_generator is
    component filter_addrs_generator
        port(
            clk                       : in  STD_LOGIC;
            rst                       : in  STD_LOGIC;
            convolution_step_done     : in  STD_LOGIC;
            ind_granted               : in  STD_LOGIC;         
            match_processed           : in  STD_LOGIC;
            last_match                : in  STD_LOGIC;
            no_match                  : in  STD_LOGIC;
            filter_jump               : in  STD_LOGIC_VECTOR(log_2(SECTION_WIDTH + 1) - 1 downto 0);
            filter_rest               : in  STD_LOGIC_VECTOR(log_2(SECTION_WIDTH + 1) - 1 downto 0);
            ind_convolution_step_done : in  STD_LOGIC;
            filter_ind_addr           : out STD_LOGIC_VECTOR(log_2(MAX_FILTER_ELEMENTS / FILTER_IND_WIDTH) - 1 downto 0);
            filter_val_addr           : out STD_LOGIC_VECTOR(log_2(MAX_FILTER_ELEMENTS) - 1 downto 0)
        );
    end component;
    
    component act_addrs_generator
        port(
            clk                       : in  STD_LOGIC;
            rst                       : in  STD_LOGIC;
            start_convolution         : in  STD_LOGIC;
            convolution_step_done     : in  STD_LOGIC;
            act_x_z_slice_size        : in  STD_LOGIC_VECTOR(log_2(MAX_ACT_WIDTH * MAX_ACT_DEPTH) - 1 downto 0);
            filter_depth              : in  STD_LOGIC_VECTOR(log_2(MAX_FILTER_DEPTH) - 1 downto 0);
            act_base                  : in  STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS / SECTION_WIDTH) - 1 downto 0);
            act_section_offset        : in  STD_LOGIC_VECTOR(log_2(SECTION_WIDTH) - 1 downto 0);
            filter_no                 : in  STD_LOGIC_VECTOR(log_2(MAX_FILTERS) - 1 downto 0);
            filters_no                : in  STD_LOGIC_VECTOR(log_2(MAX_FILTERS) - 1 downto 0);
            ind_filter_inc_x          : in  STD_LOGIC;
            ind_filter_inc_y          : in  STD_LOGIC;
            ind_filter_inc_z          : in  STD_LOGIC;
            ind_act_inc_x             : in  STD_LOGIC;
            ind_act_inc_y             : in  STD_LOGIC;
            ind_convolution_step_done : in  STD_LOGIC;
            act_ind_addr              : out STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS / ACT_IND_WIDTH) - 1 downto 0);
            act_val_addr              : out STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS) - 1 downto 0);
            new_act_val_addr          : out STD_LOGIC_VECTOR(log_2(MAX_ACT_ELEMENTS) - 1 downto 0)
        );
    end component;
begin
    filter_addrs_generator_I: filter_addrs_generator
        port map(
            clk                       => clk,
            rst                       => rst,
            convolution_step_done     => convolution_step_done,
            ind_granted               => ind_granted,                 
            match_processed           => match_processed,
            last_match                => last_match,
            no_match                  => no_match,
            filter_jump               => filter_jump,
            filter_rest               => filter_rest,
            ind_convolution_step_done => ind_convolution_step_done,
            filter_ind_addr           => filter_ind_addr,
            filter_val_addr           => filter_val_addr
        );

    act_addrs_generator_I: act_addrs_generator
        port map(
            clk                       => clk,
            rst                       => rst,
            start_convolution         => start_convolution,
            convolution_step_done     => convolution_step_done,
            act_x_z_slice_size        => act_x_z_slice_size,
            filter_depth              => filter_depth,
            act_base                  => act_base,
            act_section_offset        => act_section_offset,
            filter_no                 => filter_no,
            filters_no                => filters_no,
            ind_filter_inc_x          => ind_filter_inc_x,
            ind_filter_inc_y          => ind_filter_inc_y,
            ind_filter_inc_z          => ind_filter_inc_z,
            ind_act_inc_x             => ind_act_inc_x,
            ind_act_inc_y             => ind_act_inc_y,
            ind_convolution_step_done => ind_convolution_step_done,
            act_ind_addr              => act_ind_addr,
            act_val_addr              => act_val_addr,
            new_act_val_addr          => new_act_val_addr
        );   
end addr_generator_arch;