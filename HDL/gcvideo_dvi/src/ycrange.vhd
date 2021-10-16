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
-- ycrange.vhd: Convert internal YCbCr for use with a full-range DAC
--


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.component_defs.all;
use work.video_defs.all;

entity ycrange is
  port (
    Clock      : in  std_logic;
    ClockEnable: in  boolean;

    -- input video
    PixelY     : in  unsigned(7 downto 0);
    PixelCb    : in    signed(7 downto 0);
    PixelCr    : in    signed(7 downto 0);

    -- output video
    OutY       : out unsigned(7 downto 0);
    OutCb      : out unsigned(7 downto 0);
    OutCr      : out unsigned(7 downto 0)
  );
end ycrange;

architecture Behavioral of ycrange is

  -- Y and Cb lookup ROM
  type rom_type is array(0 to 2 * 256 - 1) of std_logic_vector(7 downto 0);

  signal conversion_rom: rom_type := (
    -- rescaling for Y [0, 219] -> [0, 255]
    x"00", x"01", x"02", x"03", x"05", x"06", x"07", x"08", -- 0..31
    x"09", x"0a", x"0c", x"0d", x"0e", x"0f", x"10", x"11",
    x"13", x"14", x"15", x"16", x"17", x"18", x"1a", x"1b",
    x"1c", x"1d", x"1e", x"1f", x"21", x"22", x"23", x"24",

    x"25", x"26", x"28", x"29", x"2a", x"2b", x"2c", x"2d", -- 32..63
    x"2f", x"30", x"31", x"32", x"33", x"34", x"36", x"37",
    x"38", x"39", x"3a", x"3b", x"3d", x"3e", x"3f", x"40",
    x"41", x"42", x"44", x"45", x"46", x"47", x"48", x"49",

    x"4b", x"4c", x"4d", x"4e", x"4f", x"50", x"52", x"53", -- 64..95
    x"54", x"55", x"56", x"57", x"58", x"5a", x"5b", x"5c",
    x"5d", x"5e", x"5f", x"61", x"62", x"63", x"64", x"65",
    x"66", x"68", x"69", x"6a", x"6b", x"6c", x"6d", x"6f",

    x"70", x"71", x"72", x"73", x"74", x"76", x"77", x"78", -- 96..127
    x"79", x"7a", x"7b", x"7d", x"7e", x"7f", x"80", x"81",
    x"82", x"84", x"85", x"86", x"87", x"88", x"89", x"8b",
    x"8c", x"8d", x"8e", x"8f", x"90", x"92", x"93", x"94",

    x"95", x"96", x"97", x"99", x"9a", x"9b", x"9c", x"9d", -- 128..159
    x"9e", x"a0", x"a1", x"a2", x"a3", x"a4", x"a5", x"a7",
    x"a8", x"a9", x"aa", x"ab", x"ac", x"ad", x"af", x"b0",
    x"b1", x"b2", x"b3", x"b4", x"b6", x"b7", x"b8", x"b9",

    x"ba", x"bb", x"bd", x"be", x"bf", x"c0", x"c1", x"c2", -- 160..191
    x"c4", x"c5", x"c6", x"c7", x"c8", x"c9", x"cb", x"cc",
    x"cd", x"ce", x"cf", x"d0", x"d2", x"d3", x"d4", x"d5",
    x"d6", x"d7", x"d9", x"da", x"db", x"dc", x"dd", x"de",

    x"e0", x"e1", x"e2", x"e3", x"e4", x"e5", x"e7", x"e8", -- 192..223
    x"e9", x"ea", x"eb", x"ec", x"ee", x"ef", x"f0", x"f1",
    x"f2", x"f3", x"f5", x"f6", x"f7", x"f8", x"f9", x"fa",
    x"fc", x"fd", x"fe", x"ff", x"ff", x"ff", x"ff", x"ff",

    x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", -- 224..255
    x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff",
    x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff",
    x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff",

    -- rescaling for Cb [-112, 112] -> [0, 255]
    x"80", x"81", x"82", x"83", x"84", x"85", x"86", x"87", -- 0..31
    x"89", x"8a", x"8b", x"8c", x"8d", x"8e", x"8f", x"91",
    x"92", x"93", x"94", x"95", x"96", x"97", x"99", x"9a",
    x"9b", x"9c", x"9d", x"9e", x"9f", x"a0", x"a2", x"a3",

    x"a4", x"a5", x"a6", x"a7", x"a8", x"aa", x"ab", x"ac", -- 32..63
    x"ad", x"ae", x"af", x"b0", x"b2", x"b3", x"b4", x"b5",
    x"b6", x"b7", x"b8", x"b9", x"bb", x"bc", x"bd", x"be",
    x"bf", x"c0", x"c1", x"c3", x"c4", x"c5", x"c6", x"c7",

    x"c8", x"c9", x"cb", x"cc", x"cd", x"ce", x"cf", x"d0", -- 64..95
    x"d1", x"d2", x"d4", x"d5", x"d6", x"d7", x"d8", x"d9",
    x"da", x"dc", x"dd", x"de", x"df", x"e0", x"e1", x"e2",
    x"e4", x"e5", x"e6", x"e7", x"e8", x"e9", x"ea", x"eb",

    x"ed", x"ee", x"ef", x"f0", x"f1", x"f2", x"f3", x"f5", -- 96..127
    x"f6", x"f7", x"f8", x"f9", x"fa", x"fb", x"fd", x"fe",
    x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff",
    x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff", x"ff",

    x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", -- 128..159
    x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00",
    x"00", x"01", x"02", x"04", x"05", x"06", x"07", x"08",
    x"09", x"0a", x"0c", x"0d", x"0e", x"0f", x"10", x"11",

    x"12", x"14", x"15", x"16", x"17", x"18", x"19", x"1a", -- 160..191
    x"1b", x"1d", x"1e", x"1f", x"20", x"21", x"22", x"23",
    x"25", x"26", x"27", x"28", x"29", x"2a", x"2b", x"2d",
    x"2e", x"2f", x"30", x"31", x"32", x"33", x"34", x"36",

    x"37", x"38", x"39", x"3a", x"3b", x"3c", x"3e", x"3f", -- 192..223
    x"40", x"41", x"42", x"43", x"44", x"46", x"47", x"48",
    x"49", x"4a", x"4b", x"4c", x"4d", x"4f", x"50", x"51",
    x"52", x"53", x"54", x"55", x"57", x"58", x"59", x"5a",

    x"5b", x"5c", x"5d", x"5f", x"60", x"61", x"62", x"63", -- 224..255
    x"64", x"65", x"66", x"68", x"69", x"6a", x"6b", x"6c",
    x"6d", x"6e", x"70", x"71", x"72", x"73", x"74", x"75",
    x"76", x"78", x"79", x"7a", x"7b", x"7c", x"7d", x"7e"
    );

  signal y_addr : unsigned(8 downto 0);
  signal cb_addr: unsigned(8 downto 0);

  signal cr_mult: signed(17 downto 0);

begin

  process(Clock, ClockEnable)
  begin
    if rising_edge(Clock) and ClockEnable then
      y_addr  <= "0" & PixelY;
      cb_addr <= "1" & unsigned(PixelCb);

      cr_mult <= PixelCr * to_signed(291, 10);

      OutY  <= unsigned(conversion_rom(to_integer(y_addr)));
      OutCb <= unsigned(conversion_rom(to_integer(cb_addr)));
      OutCr <= unsigned(cr_mult(15 downto 8)) xor x"80";
    end if;
  end process;

end Behavioral;
