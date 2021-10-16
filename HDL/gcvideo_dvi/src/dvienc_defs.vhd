----------------------------------------------------------------------------------
-- GCVideo DVI HDL
-- Copyright (C) 2014-2021, Ingo Korb <ingo@akana.de>
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- 1. Redistributions of source code must retain the above copyright notice,
--    this list of conditions and the following disclaimer.
-- 2. Redistributions in binary form must reproduce the above copyright notice,
--    this list of conditions and the following disclaimer in the documentation
--    and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
-- IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
-- ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
-- LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
-- CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
-- SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
-- INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
-- CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
-- ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
-- THE POSSIBILITY OF SUCH DAMAGE.
--
-- dvienc_defs.vhd: Component definitions for the DVI encoder
--
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.ALL;

package dvienc_defs is

  COMPONENT TDMS_encoder
  PORT(
    clk     : IN  std_logic;
    clk_en  : IN  boolean;
    data    : IN  std_logic_vector(7 downto 0);
    c       : IN  std_logic_vector(1 downto 0);
    blank   : IN  std_logic;
    encoded : OUT std_logic_vector(9 downto 0)
    );
  END COMPONENT;

  component aux_encoder is
    port (
      Clock      : in  std_logic;
      ClockEnable: in  boolean;
      Data       : in  std_logic_vector(3 downto 0);
      EncData    : out std_logic_vector(9 downto 0)
    );
  end component;

  component aux_ecc1 is
    port (
      Clock      : in  std_logic;
      ClockEnable: in  boolean;
      DataIn     : in  std_logic;
      DataOut    : out std_logic;
      SendECC    : in  boolean
    );
  end component;

  component aux_ecc2 is
    port (
      Clock      : in  std_logic;
      ClockEnable: in  boolean;
      DataIn     : in  std_logic_vector(1 downto 0);
      DataOut    : out std_logic_vector(1 downto 0);
      SendECC    : in  boolean
    );
  end component;

  type BT4_Mode_t is (BT4_Send_1, BT4_Send_Header);
  type Enc_Mode_t is (ENC_TMDS, ENC_TERC, ENC_GuardV, ENC_GuardD);

  constant UCode_Addr_Blank2Vid : natural := 0;
  constant UCode_Addr_OnePacket : natural := 128;
  constant UCode_Addr_TwoPackets: natural := 256;
  constant UCode_Addr_TMDS      : natural := 384;

  component edvi_ucode is
    port (
      Clock          : in  std_logic;
      ClockEnable    : in  boolean;
      Address        : in  natural range 0 to 511;
      BT4_Mode       : out BT4_Mode_t;
      C2C0_Value     : out std_logic_vector(1 downto 0);
      Enc_Mode       : out Enc_Mode_t;
      ShiftPacket    : out boolean;
      HeaderSendECC  : out boolean;
      DataSendECC    : out boolean;
      nFirstPacketBit: out boolean;
      ShiftSecondPkt : out boolean;
      Done           : out boolean
    );
  end component;

end dvienc_defs;

package body dvienc_defs is
end dvienc_defs;
