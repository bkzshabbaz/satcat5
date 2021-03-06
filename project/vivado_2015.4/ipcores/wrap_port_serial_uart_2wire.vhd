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
-- Port-type wrapper for "port_serial_uart_2wire"
--
-- Xilinx IP-cores can only use simple std_logic and std_logic_vector types.
-- This shim provides that conversion.
--

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;
use     work.common_functions.all;
use     work.switch_types.all;

entity wrap_port_serial_uart_2wire is
    generic (
    CLKREF_HZ   : positive;         -- Reference clock rate (Hz)
    BAUD_HZ     : positive);        -- Input and output rate (bps)
    port (
    -- External 2-wire interface.
    uart_txd    : out std_logic;
    uart_rxd    : in  std_logic;

    -- Network port
    sw_rx_clk   : out std_logic;
    sw_rx_data  : out std_logic_vector(7 downto 0);
    sw_rx_last  : out std_logic;
    sw_rx_write : out std_logic;
    sw_rx_error : out std_logic;
    sw_rx_reset : out std_logic;
    sw_tx_clk   : out std_logic;
    sw_tx_data  : in  std_logic_vector(7 downto 0);
    sw_tx_last  : in  std_logic;
    sw_tx_valid : in  std_logic;
    sw_tx_ready : out std_logic;
    sw_tx_error : out std_logic;
    sw_tx_reset : out std_logic;

    -- Clock and reset
    refclk      : in  std_logic;    -- Reference clock
    reset_p     : in  std_logic);   -- Reset / shutdown
end wrap_port_serial_uart_2wire;

architecture wrap_port_serial_uart_2wire of wrap_port_serial_uart_2wire is

signal rx_data  : port_rx_m2s;
signal tx_data  : port_tx_m2s;
signal tx_ctrl  : port_tx_s2m;

begin

-- Convert port signals.
sw_rx_clk       <= rx_data.clk;
sw_rx_data      <= rx_data.data;
sw_rx_last      <= rx_data.last;
sw_rx_write     <= rx_data.write;
sw_rx_error     <= rx_data.rxerr;
sw_rx_reset     <= rx_data.reset_p;
sw_tx_clk       <= tx_ctrl.clk;
sw_tx_ready     <= tx_ctrl.ready;
sw_tx_error     <= tx_ctrl.txerr;
sw_tx_reset     <= tx_ctrl.reset_p;
tx_data.data    <= sw_tx_data;
tx_data.last    <= sw_tx_last;
tx_data.valid   <= sw_tx_valid;

-- Unit being wrapped.
u_wrap : entity work.port_serial_uart_2wire
    generic map(
    CLKREF_HZ   => CLKREF_HZ,
    BAUD_HZ     => BAUD_HZ)
    port map(
    uart_txd    => uart_txd,
    uart_rxd    => uart_rxd,
    rx_data     => rx_data,
    tx_data     => tx_data,
    tx_ctrl     => tx_ctrl,
    refclk      => refclk,
    reset_p     => reset_p);

end wrap_port_serial_uart_2wire;
