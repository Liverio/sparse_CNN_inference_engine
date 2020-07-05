library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity act_ind_arbiter is
    port(
        clk            : in  STD_LOGIC;
        rst            : in  STD_LOGIC;
        requests       : in  tp_act_ind_requests;
        requests_valid : in  STD_LOGIC_VECTOR(PUs - 1 downto 0);
        -- PUs that were granted
        granted        : out STD_LOGIC_VECTOR(PUs - 1 downto 0);
        served         : out STD_LOGIC_VECTOR(PUs - 1 downto 0);
        -- PU assigned to each bank
        PUs_granted    : out tp_act_ind_PUs_served
    );
end act_ind_arbiter;

architecture act_ind_arbiter_arch of act_ind_arbiter is
    component bank_arbiter
        generic(
            bank_no : natural := 0
        );
        port(
            requests       : in  tp_act_ind_requests;
            requests_valid : in  STD_LOGIC_VECTOR(PUs - 1 downto 0);
            PU_served      : out STD_LOGIC_VECTOR(PUs - 1 downto 0);
            PU_served_no   : out STD_LOGIC_VECTOR(log_2(PUs) - 1 downto 0)
        );
    end component;
    
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
    
    -------------------
    -- Bank arbiters --
    -------------------
    type tp_bank_assigner_decoded_PU is array(0 to ACT_IND_BANKS - 1) of STD_LOGIC_VECTOR(PUs - 1 downto 0);
    signal PU_served : tp_bank_assigner_decoded_PU;
    
    -- PUs granted
    signal granted_int : STD_LOGIC_VECTOR(PUs - 1 downto 0);
begin
    -------------------
    -- Bank arbiters --
    -------------------
    bank_arbiters: for i in 0 to ACT_IND_BANKS - 1 generate
        bank_arbiter_I: bank_arbiter
            generic map(
                bank_no => i
            )
            port map(
                requests       => requests,
                requests_valid => requests_valid,
                PU_served      => PU_served(i),
                PU_served_no   => PUs_granted(i)
            );
    end generate;
    
    -----------------
    -- PUs granted --
    -----------------
    PUs_granted_gen: for i in 0 to PUs - 1 generate
        signal check : STD_LOGIC_VECTOR(ACT_IND_BANKS - 1 downto 0);
    begin
        PU_requests: for j in 0 to ACT_IND_BANKS - 1 generate
            check(j) <= PU_served(j)(i);
        end generate;
        
        granted_int(i) <= '1' when check /= std_logic_vector(to_unsigned(0, ACT_IND_BANKS)) else '0';
    end generate;  

    ---------------------
    -- PU being served --
    ---------------------
    served_reg: reg generic map(bits => PUs)
        port map(clk, rst, '1', granted_int, served);

    granted <= granted_int;
end act_ind_arbiter_arch;