--------------------------------------------------------------------------
-- Copyright 2019 The Aerospace Corporation
--
-- This file is part of SatCat5.
--
-- SatCat5 is free software: you can redistribute it and/or modify it under
-- the terms of the GNU Lesser General Public License as published by the
-- Free Software Foundation, either version 3 of the License, or (at your
-- option) any later version.
--
-- SatCat5 is distributed in the hope that it will be useful, but WITHOUT
-- ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
-- FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
-- License for more details.
--
-- You should have received a copy of the GNU Lesser General Public License
-- along with SatCat5.  If not, see <https://www.gnu.org/licenses/>.
--------------------------------------------------------------------------
--
-- Fixed-delay buffer for use with packet FIFO
--
-- This block implements a fixed-delay buffer for data and byte-count
-- fields, suitable for use at the input to the packet FIFO.  Shifting
-- the data in this fashion allows maximum utilization of the MAC-lookup
-- pipeline, while still ensuring that port-routing information is ready
-- prior to the end of the packet.
--

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
use     work.common_functions.all;

entity packet_delay is
    generic (
    INPUT_BYTES     : integer;          -- Width of input port
    DELAY_COUNT     : integer);         -- Fixed delay, in clocks
    port (
    -- Input port (no flow control).
    in_data         : in  std_logic_vector(8*INPUT_BYTES-1 downto 0);
    in_bcount       : in  integer range 0 to INPUT_BYTES-1;
    in_last         : in  std_logic;
    in_write        : in  std_logic;

    -- Output port (no flow control).
    out_data        : out std_logic_vector(8*INPUT_BYTES-1 downto 0);
    out_bcount      : out integer range 0 to INPUT_BYTES-1;
    out_last        : out std_logic;
    out_write       : out std_logic;

    -- System clock and optional reset.
    io_clk          : in  std_logic;
    reset_p         : in  std_logic := '0');
end packet_delay;

architecture packet_delay of packet_delay is

constant ADDR_MAX : integer := max(0, DELAY_COUNT-2);
subtype addr_t is integer range 0 to ADDR_MAX;
subtype word_t is std_logic_vector(8*INPUT_BYTES-1 downto 0);
subtype bcount_t is integer range 0 to INPUT_BYTES-1;
type word_array is array(natural range <>) of word_t;
type count_array is array(natural range <>) of bcount_t;

signal rw_addr      : addr_t := 0;
signal out_en       : std_logic := '0';
signal tmp_data     : word_t := (others => '0');
signal tmp_bcount   : bcount_t := INPUT_BYTES-1;
signal tmp_last     : std_logic := '0';
signal tmp_write    : std_logic := '0';

begin

-- Drive the final output signals.
out_data    <= tmp_data;
out_bcount  <= tmp_bcount;
out_last    <= tmp_last;
out_write   <= tmp_write;

-- Special case if delay is zero:
gen_null : if (DELAY_COUNT < 1) generate
    tmp_data    <= in_data;
    tmp_bcount  <= in_bcount;
    tmp_last    <= in_last;
    tmp_write   <= in_write;
end generate;

-- Small delays use a shift-register interface:
gen_sreg : if (1 <= DELAY_COUNT and DELAY_COUNT < 16) generate
    -- To save resources, only the "out_write" buffer is resettable.
    p_write : process(io_clk)
        variable sreg : std_logic_vector(DELAY_COUNT downto 1) := (others => '0');
    begin
        if rising_edge(io_clk) then
            if (reset_p = '1') then
                sreg := (others => '0');
            else
                sreg := sreg(DELAY_COUNT-1 downto 1) & in_write;
            end if;
            tmp_write <= sreg(DELAY_COUNT);
        end if;
    end process;

    p_other : process(io_clk)
        variable sreg_data  : word_array(DELAY_COUNT downto 1) := (others => (others => '0'));
        variable sreg_count : count_array(DELAY_COUNT downto 1) := (others => INPUT_BYTES-1);
        variable sreg_last  : std_logic_vector(DELAY_COUNT downto 1) := (others => '0');
    begin
        if rising_edge(io_clk) then
            sreg_data  := sreg_data (DELAY_COUNT-1 downto 1) & in_data;
            sreg_count := sreg_count(DELAY_COUNT-1 downto 1) & in_bcount;
            sreg_last  := sreg_last (DELAY_COUNT-1 downto 1) & in_last;

            tmp_data   <= sreg_data (DELAY_COUNT);
            tmp_bcount <= sreg_count(DELAY_COUNT);
            tmp_last   <= sreg_last (DELAY_COUNT);
        end if;
    end process;
end generate;

-- Larger delays use inferred block-RAM.
gen_bram : if (DELAY_COUNT >= 16) generate
    -- Counter state machine:
    p_addr : process(io_clk)
    begin
        if rising_edge(io_clk) then
            -- Permanently set "out_en" N cycles after reset.
            if (reset_p = '1') then
                out_en <= '0';
            elsif (rw_addr = ADDR_MAX) then
                out_en <= '1';
            end if;

            -- Combined read/write address increments every clock cycle.
            if (reset_p = '1' or rw_addr = ADDR_MAX) then
                rw_addr <= 0;
            else
                rw_addr <= rw_addr + 1;
            end if;
        end if;
    end process;

    -- Inferred block-RAM or distributed RAM:
    p_bram : process(io_clk)
        variable ram_data   : word_array(0 to ADDR_MAX) := (others => (others => '0'));
        variable ram_bcount : count_array(0 to ADDR_MAX) := (others => INPUT_BYTES-1);
        variable ram_last   : std_logic_vector(0 to ADDR_MAX) := (others => '0');
        variable ram_write  : std_logic_vector(0 to ADDR_MAX) := (others => '0');
    begin
        if rising_edge(io_clk) then
            -- Read before write.
            tmp_data    <= ram_data(rw_addr);
            tmp_bcount  <= ram_bcount(rw_addr);
            tmp_last    <= ram_last(rw_addr);
            tmp_write   <= ram_write(rw_addr) and out_en;

            ram_data(rw_addr)   := in_data;
            ram_bcount(rw_addr) := in_bcount;
            ram_last(rw_addr)   := in_last;
            ram_write(rw_addr)  := in_write;
        end if;
    end process;
end generate;

end packet_delay;
