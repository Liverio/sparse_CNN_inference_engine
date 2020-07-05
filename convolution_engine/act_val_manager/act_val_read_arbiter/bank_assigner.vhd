library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity bank_assigner is
    port(
        ----------------------------------------------
        -- Activation values read arbiter interface --
        ----------------------------------------------
        free_banks_in  : in  STD_LOGIC_VECTOR(ACT_VAL_BANKS - 1 downto 0);
        free_banks_out : out STD_LOGIC_VECTOR(ACT_VAL_BANKS - 1 downto 0);
        -------------------
        -- PUs interface --
        -------------------
        requests       : in  tp_request_set;
        requests_valid : in  STD_LOGIC_VECTOR(PAIRING_BUFFER_DEPTH - 1 downto 0);
        request_served : out STD_LOGIC;
        request        : out STD_LOGIC_VECTOR(log_2(PAIRING_BUFFER_DEPTH) - 1 downto 0)
    );
end bank_assigner;

architecture bank_assigner_arch of bank_assigner is
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
    
    ----------------------
    -- Request selector --
    ----------------------
    signal request_served_int : STD_LOGIC;
    signal request_int        : STD_LOGIC_VECTOR(log_2(PAIRING_BUFFER_DEPTH) - 1 downto 0);
    signal request_feasible   : STD_LOGIC_VECTOR(PAIRING_BUFFER_DEPTH - 1 downto 0);
    
    -------------------------------
    -- Bank availability updater --
    -------------------------------
    signal mask: STD_LOGIC_VECTOR(ACT_VAL_BANKS - 1 downto 0);
begin
    -------------------------------------------------------------
    -- Select the first valid request that targets a free bank --
    -------------------------------------------------------------
    request_feasibility: for i in 0 to PAIRING_BUFFER_DEPTH - 1 generate
        request_feasible(i) <= free_banks_in(to_uint(requests(i))) AND requests_valid(i);
    end generate;

    priority_encoder_I: priority_encoder
        generic map(
            PAIRING_BUFFER_DEPTH
        )
        port map(
            input    => request_feasible,
            found    => request_served_int,
            position => request_int
        );
    
    --------------------------------------------------
    -- Update banks available after the assignation --
    --------------------------------------------------    
    mask_I: for i in 0 to ACT_VAL_BANKS - 1 generate
        -- Generate the mask to mark the bank assigned as not available 
        mask(i) <= '0' when i = to_uint(requests(to_uint(request_int))) else '1';
        
        -- New banks availability
        free_banks_out(i) <= free_banks_in(i) AND mask(i) when request_served_int = '1' else
                             free_banks_in(i);
    end generate;
    
    -------------
    -- Outputs --
    -------------
    request_served <= request_served_int;
    request        <= request_int;
end bank_assigner_arch;