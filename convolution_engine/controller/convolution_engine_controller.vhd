library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity convolution_engine_controller is    
    port(
        clk, rst : in STD_LOGIC;
        -----------------------------
        -- Image storing interface --
        -----------------------------
        new_data   : in  STD_LOGIC;          
        data_input : in  STD_LOGIC_VECTOR(AXIS_BUS_WIDTH - 1 downto 0);
        done       : out STD_LOGIC;
        -------------------
        -- PUs interface --
        -------------------
        compute_convolution : out STD_LOGIC_VECTOR(PUs - 1 downto 0);
        convolution_done    : in  STD_LOGIC_VECTOR(PUs - 1 downto 0);
        -------------------------------
        -- act_ind_manager interface --
        -------------------------------
        store_image_ind   : out STD_LOGIC;
        store_filter_ind  : out STD_LOGIC_VECTOR(PUs - 1 downto 0);
        image_ind_stored  : in  STD_LOGIC;
        filter_ind_stored : in  STD_LOGIC_VECTOR(PUs - 1 downto 0);
        -------------------------------
        -- act_val_manager interface --
        -------------------------------
        store_image_val   : out STD_LOGIC;
        store_filter_val  : out STD_LOGIC_VECTOR(PUs - 1 downto 0);
        image_val_stored  : in  STD_LOGIC;
        filter_val_stored : in  STD_LOGIC_VECTOR(PUs - 1 downto 0)
    );
end convolution_engine_controller;

architecture convolution_engine_controller_arch of convolution_engine_controller is
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
    
    --------------------
    -- Filter storing --
    --------------------
    signal ld_filters_no      : STD_LOGIC;
    signal filters_no         : STD_LOGIC_VECTOR(log_2(MAX_FILTERS) - 1 downto 0);
    signal inc_filter_counter : STD_LOGIC;
    signal rst_filter_counter : STD_LOGIC;
    signal filter_count       : STD_LOGIC_VECTOR(log_2(MAX_FILTERS) - 1 downto 0);
    
    ----------------------
    -- Pipeline counter --
    ----------------------
    signal rst_PU_pipeline : STD_LOGIC;
    signal inc_PU_pipeline : STD_LOGIC;
    signal PU_pipeline     : STD_LOGIC_VECTOR(log_2(PUs) - 1 downto 0);
    
    ----------------------------
    -- Convolution engine FSM --
    ----------------------------
    type tp_state is(
        IDLE,
        STORING_IMAGE_INDICES,
        WAITING_FOR_IMAGE_VALUES,
        STORING_IMAGE_VALUES,
        WAITING_FOR_FILTER_INDICES,
        STORING_FILTER_INDICES,
        WAITING_FOR_FILTER_VALUES,
        STORING_FILTER_VALUES,
        INITIALIZING_PIPELINE,
        COMPUTING_CONVOLUTIONS
    );
                      
    signal fsm_cs, fsm_ns: tp_state;
    signal ones : STD_LOGIC_VECTOR(PUs - 1 downto 0);
    signal PU   : STD_LOGIC_VECTOR(log_2(PUs) - 1 downto 0);
begin
    --------------------
    -- Filter storing --
    --------------------
    filters_no_reg: reg generic map(bits => log_2(MAX_FILTERS), init_value => 0)
        port map(clk, rst, ld_filters_no, data_input(log_2(MAX_FILTERS) - 1 downto 0), filters_no);

    filter_counter: counter generic map(bits => log_2(MAX_FILTERS))
        port map(clk, rst, rst_filter_counter, inc_filter_counter, filter_count);
    
    -- Procesing unit where to store the current filter
    PU <= filter_count(log_2(PUs) - 1 downto 0);
    
    -- Initialization of the pipeline of the act_val_read_arbiter
    pipeline_stage: counter generic map(bits => log_2(PUs))
        port map(clk, rst, rst_PU_pipeline, inc_PU_pipeline, PU_pipeline);
    
    ----------------------------
    -- convolution_engine_FSM --
    ----------------------------
    ones <= (others => '1');
    convolution_engine_FSM: process(
        fsm_cs,                                         -- Default
        new_data,                                       -- IDLE
        image_ind_stored,                               -- STORING_IMAGE_INDICES                                    
        image_val_stored,                               -- STORING_IMAGE_VALUES
        PU,                                             -- WAITING_FOR_FILTER_INDICES
        filter_ind_stored, filter_count, filters_no,    -- STORING_FILTER_INDICES
        filter_val_stored, PU_pipeline,                 -- STORING_FILTER_VALUES
        convolution_done, ones)                         -- COMPUTING_CONVOLUTIONS
    begin        
        ld_filters_no       <= '0';
        inc_filter_counter  <= '0';
        rst_filter_counter  <= '0';
        rst_PU_pipeline     <= '0';
        inc_PU_pipeline     <= '0';
        store_image_ind     <= '0';
        store_image_val     <= '0';
        store_filter_ind    <= (others => '0');
        store_filter_val    <= (others => '0');
        compute_convolution <= (others => '0');
        done                <= '0';
        fsm_ns              <= fsm_cs;
          
        case fsm_cs is
            when IDLE =>
                done <= '1';
                
                if new_data = '1' then
                    store_image_ind <= '1';
                    fsm_ns          <= STORING_IMAGE_INDICES;                                
                end if;                                        
                
            ----------------------------------------
            -- Receiving image indices and values --
            ----------------------------------------
            when STORING_IMAGE_INDICES =>
                if image_ind_stored = '1' then                    
                    fsm_ns <= WAITING_FOR_IMAGE_VALUES;                                
                end if;
            
            when WAITING_FOR_IMAGE_VALUES =>
                if new_data = '1' then
                    store_image_val <= '1';
                    fsm_ns          <= STORING_IMAGE_VALUES;                                
                end if;
                
            when STORING_IMAGE_VALUES =>
                if image_val_stored = '1' then                    
                    fsm_ns <= WAITING_FOR_FILTER_INDICES;                                
                end if;
                
            ----------------------------------------
            -- Receiving image indices and values --
            ----------------------------------------
            when WAITING_FOR_FILTER_INDICES =>
                if new_data = '1' then
                    ld_filters_no                 <= '1';
                    store_filter_ind(to_uint(PU)) <= '1';                    
                    fsm_ns                        <= STORING_FILTER_INDICES;                                
                end if;
                
            when STORING_FILTER_INDICES =>
                if filter_ind_stored(to_uint(PU)) = '1' then
                    -- All filter indices stored
                    if to_uint(filter_count) = to_uint(filters_no) - 1 then
                        rst_filter_counter <= '1';                        
                        fsm_ns             <= WAITING_FOR_FILTER_VALUES;
                    else
                        inc_filter_counter <= '1';
                        fsm_ns             <= WAITING_FOR_FILTER_INDICES;
                    end if;
                end if;
            
            when WAITING_FOR_FILTER_VALUES =>
                if new_data = '1' then
                    store_filter_val(to_uint(PU)) <= '1';                    
                    fsm_ns                        <= STORING_FILTER_VALUES;
                end if;
            
            when STORING_FILTER_VALUES =>
                if filter_val_stored(to_uint(PU)) = '1' then                    
                    -- All filter values stored
                    if to_uint(filter_count) = to_uint(filters_no) - 1 then
                        rst_filter_counter                                    <= '1'; 
                        compute_convolution((PUs - 1) - to_uint(PU_pipeline)) <= '1';

                        if (PUs - 1) - to_uint(PU_pipeline) > 0 then
                            inc_PU_pipeline <= '1';    
                            fsm_ns          <= INITIALIZING_PIPELINE;
                        else
                            fsm_ns          <= COMPUTING_CONVOLUTIONS;
                        end if;
                    else
                        inc_filter_counter <= '1';
                        fsm_ns             <= WAITING_FOR_FILTER_VALUES;
                    end if;
                end if;
                    
            ----------------
            -- Processing --
            ----------------
            when INITIALIZING_PIPELINE =>
                compute_convolution((PUs - 1) - to_uint(PU_pipeline)) <= '1';
                
                if (PUs - 1) - to_uint(PU_pipeline) > 0 then
                    inc_PU_pipeline <= '1';
                else
                    rst_PU_pipeline <= '1';
                    fsm_ns          <= COMPUTING_CONVOLUTIONS;
                end if;
                
            when COMPUTING_CONVOLUTIONS =>
                if convolution_done = ones then
                    fsm_ns <= IDLE;
                end if;
        end case;
    end process convolution_engine_FSM;

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
end convolution_engine_controller_arch;