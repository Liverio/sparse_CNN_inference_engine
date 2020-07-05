library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.types.all;

entity act_ind_read_crossbar is
    port(
        clk : in STD_LOGIC;
        rst : in STD_LOGIC;
        ------------------------------------
        -- act_ind_read_arbiter interface --
        ------------------------------------
        PUs_granted : in tp_act_ind_PUs_served;
        -------------------
        -- PUs interface --
        -------------------
        PU_requests_addrs : in  tp_act_ind_requests;
        act_ind_read      : out tp_act_ind_read;
        ------------------------------
        -- act_ind memory interface --
        ------------------------------
        act_ind           : in  tp_act_ind_mem_output;
        act_mem_ind_addrs : out tp_act_ind_requests_served
    );
end act_ind_read_crossbar;

architecture act_ind_read_crossbar_arch of act_ind_read_crossbar is
    component reg
        generic(bits       : positive := 128;
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
    
    -- Addresses latches
    signal PU_requests_addrs_latched : tp_act_ind_requests;
begin
    ------------------------------------------------------
    -- Muxes to address the banks of the act_ind_memory --
    ------------------------------------------------------
    act_ind_mem_addr_muxes: for i in 0 to ACT_IND_BANKS - 1 generate
        act_mem_ind_addrs(i) <= PU_requests_addrs(to_uint(PUs_granted(i)));
    end generate;

    ---------------------------
    -- Muxes to feed the PUs --
    ---------------------------
    PUs_ind_read_muxes: for i in 0 to PUs - 1 generate
        type tp_PU_bank_requested is array(0 to PUs - 1) of STD_LOGIC_VECTOR(log_2(ACT_IND_BANKS) - 1 downto 0);
        signal PU_bank_requested : tp_PU_bank_requested;
    begin
        -- Latch addresses to select bank when reading
        addr_reg: reg generic map(bits => log_2(ACT_IND_BRAMS_PER_BANK) + addr_width(ACT_IND_WIDTH) + log_2(ACT_IND_BANKS))
            port map(clk, rst, '1', PU_requests_addrs(i), PU_requests_addrs_latched(i));
        
        PU_bank_requested(i) <= PU_requests_addrs_latched(i)(log_2(ACT_IND_BANKS) - 1 downto 0); 
        act_ind_read(i)      <= act_ind(to_uint(PU_bank_requested(i)));
    end generate;
end act_ind_read_crossbar_arch;