library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity act_val_read_arbiter is
    port(
        clk : in STD_LOGIC;
        rst : in STD_LOGIC;
        -------------------
        -- PUs interface --
        -------------------
        requests                  : in  tp_request_array;
        requests_valid            : in  tp_request_valid_array;
        request_served_to_pairing : out STD_LOGIC_VECTOR(PUs - 1 downto 0);
        request_to_pairing        : out tp_bank_requests_selected;
        request_served            : out STD_LOGIC_VECTOR(PUs - 1 downto 0);
        request                   : out tp_bank_requests_selected
    );
end act_val_read_arbiter;

architecture act_val_read_arbiter_arch of act_val_read_arbiter is
    component bank_assigner
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
    end component;
    
    component reg
        generic(
            bits       : positive := 128;
            init_value : natural  := 0
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
            clk   : in  STD_LOGIC;
            rst   : in  STD_LOGIC;
            rst_2 : in  STD_LOGIC;
            inc   : in  STD_LOGIC;
            count : out STD_LOGIC_VECTOR(bits - 1 downto 0)
        );
    end component;

    signal master : STD_LOGIC_VECTOR(log_2(PUs) - 1 downto 0);
    
    type tp_free_banks_array is
        array(0 to PUs - 1) of STD_LOGIC_VECTOR(ACT_VAL_BANKS - 1 downto 0);
    signal free_banks_in  : tp_free_banks_array; 
    signal free_banks_out : tp_free_banks_array;
    
    --------------
    -- Pipeline --
    --------------
    -- {unit, stage}
    type tp_request_served_reg is 
        array(0 to PUs - 1, 1 to PUs - 1) of STD_LOGIC_VECTOR(1 - 1 downto 0);
    signal request_served_reg : tp_request_served_reg;
    
    type tp_request_reg is
        array(0 to PUs - 1, 1 to PUs - 1) of STD_LOGIC_VECTOR(log_2(PAIRING_BUFFER_DEPTH) - 1 downto 0);
    signal request_reg : tp_request_reg;
    
    type tp_stage_info is
        array(1 to PUs - 1, 1 to PUs - 1) of STD_LOGIC_VECTOR(1 + log_2(PAIRING_BUFFER_DEPTH) - 1 downto 0);
    signal stage_info : tp_stage_info;

    signal free_banks_out_reg : tp_free_banks_array;
    signal request_served_int : STD_LOGIC_VECTOR(PUs - 1 downto 0);
    signal request_int        : tp_bank_requests_selected;
begin
    bank_assigner_I: for i in 0 to PUs - 1 generate
        first: if i = PUs - 1 generate
            free_banks_in(i) <= (others => '1');
        end generate;

        remaining: if i /= PUs - 1 generate
            free_banks_in(i) <= free_banks_out_reg(i + 1);
        end generate;
        
        --------------
        -- Pipeline --
        --------------
        free_banks_reg: reg generic map(bits => ACT_VAL_BANKS)
            port map(clk, rst, '1', free_banks_out(i), free_banks_out_reg(i));
                
        -- {source_stage, stage}
        stage_regs: for j in 1 to i generate
            current_unit: if j = i generate
                stage_reg: reg generic map(bits => 1 + log_2(PAIRING_BUFFER_DEPTH))
                    port map(clk, rst, '1', request_served_int(i) & request_int(i), stage_info(i, j));
            end generate;
            
            remaining_units: if j /= i generate
                stage_reg: reg generic map(bits => 1 + log_2(PAIRING_BUFFER_DEPTH))
                    port map(clk, rst, '1', stage_info(i, j + 1), stage_info(i, j));
            end generate;

            request_served_reg(i, j) <= stage_info(i, j)(1 + log_2(PAIRING_BUFFER_DEPTH) - 1 downto log_2(PAIRING_BUFFER_DEPTH));
            request_reg(i, j)        <= stage_info(i, j)(    log_2(PAIRING_BUFFER_DEPTH) - 1 downto                           0);
        end generate;
        
        bank_assigner_I: bank_assigner
            port map(
                ----------------------------------------------
                -- Activation values read arbiter interface --
                ----------------------------------------------
                free_banks_in  => free_banks_in(i),
                free_banks_out => free_banks_out(i),
                -------------------
                -- PUs interface --
                -------------------
                requests       => requests(i),
                requests_valid => requests_valid(i),
                request_served => request_served_int(i),
                request        => request_int(i)
            );
        
        not_last: if i /= 0 generate
            request_served(i) <= request_served_reg(i, 1)(0);
            request(i)        <= request_reg(i, 1);
        end generate;
    end generate;

    -------------
    -- Outputs --
    -------------
    -- To pairing
    request_served_to_pairing <= request_served_int;
    request_to_pairing        <= request_int;
    
    -- To read crossbar
    request_served(0) <= request_served_int(0);
    request(0)        <= request_int(0);
end act_val_read_arbiter_arch;