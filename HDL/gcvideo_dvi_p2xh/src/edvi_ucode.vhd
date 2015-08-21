-- auto-generated from edvi_ucode.mcout and template-ucode.vhd on Tue Aug 18 12:21:19 2015
----------------------------------------------------------------------------------
-- GCVideo DVI HDL
-- Copyright (C) 2014-2015, Ingo Korb <ingo@akana.de>
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
-- edvi_ucode.vhd: Sequencer tables for enhanced DVI encoder
--   (auto-generated from edvi_ucode.mc)
--
----------------------------------------------------------------------------------

library IEEE;

use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

use work.dvienc_defs.all;

---- Note: type definitions must be moved to a package
-- type BT4_Mode_t is (BT4_Send_1, BT4_Send_Header);
-- type Enc_Mode_t is (ENC_GuardD, ENC_GuardV, ENC_TERC, ENC_TMDS);

entity edvi_ucode is
  port (
    Clock: in std_logic;
    ClockEnable: in boolean;
    Address: in natural range 0 to 511;
    BT4_Mode: out BT4_Mode_t;
    C2C0_Value: out std_logic_vector(1 downto 0);
    Enc_Mode: out Enc_Mode_t;
    ShiftPacket: out boolean;
    HeaderSendECC: out boolean;
    DataSendECC: out boolean;
    nFirstPacketBit: out boolean;
    ShiftSecondPkt: out boolean;
    Done: out boolean
  );
end edvi_ucode;

architecture Behavioral of edvi_ucode is
  signal data: std_logic_vector(10 downto 0);
begin

process(data)
begin
  case data(6 downto 6) is
    when "0" => BT4_Mode <= BT4_Send_1;
    when "1" => BT4_Mode <= BT4_Send_Header;
    when others => null;
  end case;

  C2C0_Value <= data(8 downto 7);

  case data(10 downto 9) is
    when "00" => Enc_Mode <= ENC_TMDS;
    when "01" => Enc_Mode <= ENC_TERC;
    when "10" => Enc_Mode <= ENC_GuardV;
    when "11" => Enc_Mode <= ENC_GuardD;
    when others => null;
  end case;

  ShiftPacket <= (data(5) = '1');

  HeaderSendECC <= (data(4) = '1');

  DataSendECC <= (data(3) = '1');

  nFirstPacketBit <= (data(2) = '1');

  ShiftSecondPkt <= (data(1) = '1');

  Done <= (data(0) = '1');

end process;

process(Clock, ClockEnable)
begin
  if rising_edge(Clock) and ClockEnable then
    case address is
      when 0 => data <= "00010011100";
      when 1 => data <= "00010011100";
      when 2 => data <= "00010011100";
      when 3 => data <= "00010011100";
      when 4 => data <= "00010011100";
      when 5 => data <= "00010011100";
      when 6 => data <= "00010011100";
      when 7 => data <= "00010011100";
      when 8 => data <= "00000011100";
      when 9 => data <= "10000011100";
      when 10 => data <= "10000011101";
      when 11 => data <= "00000011100";
      when 12 => data <= "00000000000";
      when 13 => data <= "00000000000";
      when 14 => data <= "00000000000";
      when 15 => data <= "00000000000";
      when 16 => data <= "00000000000";
      when 17 => data <= "00000000000";
      when 18 => data <= "00000000000";
      when 19 => data <= "00000000000";
      when 20 => data <= "00000000000";
      when 21 => data <= "00000000000";
      when 22 => data <= "00000000000";
      when 23 => data <= "00000000000";
      when 24 => data <= "00000000000";
      when 25 => data <= "00000000000";
      when 26 => data <= "00000000000";
      when 27 => data <= "00000000000";
      when 28 => data <= "00000000000";
      when 29 => data <= "00000000000";
      when 30 => data <= "00000000000";
      when 31 => data <= "00000000000";
      when 32 => data <= "00000000000";
      when 33 => data <= "00000000000";
      when 34 => data <= "00000000000";
      when 35 => data <= "00000000000";
      when 36 => data <= "00000000000";
      when 37 => data <= "00000000000";
      when 38 => data <= "00000000000";
      when 39 => data <= "00000000000";
      when 40 => data <= "00000000000";
      when 41 => data <= "00000000000";
      when 42 => data <= "00000000000";
      when 43 => data <= "00000000000";
      when 44 => data <= "00000000000";
      when 45 => data <= "00000000000";
      when 46 => data <= "00000000000";
      when 47 => data <= "00000000000";
      when 48 => data <= "00000000000";
      when 49 => data <= "00000000000";
      when 50 => data <= "00000000000";
      when 51 => data <= "00000000000";
      when 52 => data <= "00000000000";
      when 53 => data <= "00000000000";
      when 54 => data <= "00000000000";
      when 55 => data <= "00000000000";
      when 56 => data <= "00000000000";
      when 57 => data <= "00000000000";
      when 58 => data <= "00000000000";
      when 59 => data <= "00000000000";
      when 60 => data <= "00000000000";
      when 61 => data <= "00000000000";
      when 62 => data <= "00000000000";
      when 63 => data <= "00000000000";
      when 64 => data <= "00000000000";
      when 65 => data <= "00000000000";
      when 66 => data <= "00000000000";
      when 67 => data <= "00000000000";
      when 68 => data <= "00000000000";
      when 69 => data <= "00000000000";
      when 70 => data <= "00000000000";
      when 71 => data <= "00000000000";
      when 72 => data <= "00000000000";
      when 73 => data <= "00000000000";
      when 74 => data <= "00000000000";
      when 75 => data <= "00000000000";
      when 76 => data <= "00000000000";
      when 77 => data <= "00000000000";
      when 78 => data <= "00000000000";
      when 79 => data <= "00000000000";
      when 80 => data <= "00000000000";
      when 81 => data <= "00000000000";
      when 82 => data <= "00000000000";
      when 83 => data <= "00000000000";
      when 84 => data <= "00000000000";
      when 85 => data <= "00000000000";
      when 86 => data <= "00000000000";
      when 87 => data <= "00000000000";
      when 88 => data <= "00000000000";
      when 89 => data <= "00000000000";
      when 90 => data <= "00000000000";
      when 91 => data <= "00000000000";
      when 92 => data <= "00000000000";
      when 93 => data <= "00000000000";
      when 94 => data <= "00000000000";
      when 95 => data <= "00000000000";
      when 96 => data <= "00000000000";
      when 97 => data <= "00000000000";
      when 98 => data <= "00000000000";
      when 99 => data <= "00000000000";
      when 100 => data <= "00000000000";
      when 101 => data <= "00000000000";
      when 102 => data <= "00000000000";
      when 103 => data <= "00000000000";
      when 104 => data <= "00000000000";
      when 105 => data <= "00000000000";
      when 106 => data <= "00000000000";
      when 107 => data <= "00000000000";
      when 108 => data <= "00000000000";
      when 109 => data <= "00000000000";
      when 110 => data <= "00000000000";
      when 111 => data <= "00000000000";
      when 112 => data <= "00000000000";
      when 113 => data <= "00000000000";
      when 114 => data <= "00000000000";
      when 115 => data <= "00000000000";
      when 116 => data <= "00000000000";
      when 117 => data <= "00000000000";
      when 118 => data <= "00000000000";
      when 119 => data <= "00000000000";
      when 120 => data <= "00000000000";
      when 121 => data <= "00000000000";
      when 122 => data <= "00000000000";
      when 123 => data <= "00000000000";
      when 124 => data <= "00000000000";
      when 125 => data <= "00000000000";
      when 126 => data <= "00000000000";
      when 127 => data <= "00000000000";
      when 128 => data <= "00110011100";
      when 129 => data <= "00110011100";
      when 130 => data <= "00110011100";
      when 131 => data <= "00110011100";
      when 132 => data <= "00110011100";
      when 133 => data <= "00110011100";
      when 134 => data <= "00110011100";
      when 135 => data <= "00110011100";
      when 136 => data <= "00110011100";
      when 137 => data <= "11110100100";
      when 138 => data <= "11111100000";
      when 139 => data <= "01111100100";
      when 140 => data <= "01111100100";
      when 141 => data <= "01111100100";
      when 142 => data <= "01111100100";
      when 143 => data <= "01111100100";
      when 144 => data <= "01111100100";
      when 145 => data <= "01111100100";
      when 146 => data <= "01111100100";
      when 147 => data <= "01111100100";
      when 148 => data <= "01111100100";
      when 149 => data <= "01111100100";
      when 150 => data <= "01111100100";
      when 151 => data <= "01111100100";
      when 152 => data <= "01111100100";
      when 153 => data <= "01111100100";
      when 154 => data <= "01111100100";
      when 155 => data <= "01111100100";
      when 156 => data <= "01111100100";
      when 157 => data <= "01111100100";
      when 158 => data <= "01111100100";
      when 159 => data <= "01111100100";
      when 160 => data <= "01111100100";
      when 161 => data <= "01111110100";
      when 162 => data <= "01111110100";
      when 163 => data <= "01111110100";
      when 164 => data <= "01111110100";
      when 165 => data <= "01111111100";
      when 166 => data <= "01111111100";
      when 167 => data <= "01111111100";
      when 168 => data <= "01111111100";
      when 169 => data <= "01001011100";
      when 170 => data <= "01000011100";
      when 171 => data <= "11000011100";
      when 172 => data <= "11000011101";
      when 173 => data <= "00000011100";
      when 174 => data <= "00000000000";
      when 175 => data <= "00000000000";
      when 176 => data <= "00000000000";
      when 177 => data <= "00000000000";
      when 178 => data <= "00000000000";
      when 179 => data <= "00000000000";
      when 180 => data <= "00000000000";
      when 181 => data <= "00000000000";
      when 182 => data <= "00000000000";
      when 183 => data <= "00000000000";
      when 184 => data <= "00000000000";
      when 185 => data <= "00000000000";
      when 186 => data <= "00000000000";
      when 187 => data <= "00000000000";
      when 188 => data <= "00000000000";
      when 189 => data <= "00000000000";
      when 190 => data <= "00000000000";
      when 191 => data <= "00000000000";
      when 192 => data <= "00000000000";
      when 193 => data <= "00000000000";
      when 194 => data <= "00000000000";
      when 195 => data <= "00000000000";
      when 196 => data <= "00000000000";
      when 197 => data <= "00000000000";
      when 198 => data <= "00000000000";
      when 199 => data <= "00000000000";
      when 200 => data <= "00000000000";
      when 201 => data <= "00000000000";
      when 202 => data <= "00000000000";
      when 203 => data <= "00000000000";
      when 204 => data <= "00000000000";
      when 205 => data <= "00000000000";
      when 206 => data <= "00000000000";
      when 207 => data <= "00000000000";
      when 208 => data <= "00000000000";
      when 209 => data <= "00000000000";
      when 210 => data <= "00000000000";
      when 211 => data <= "00000000000";
      when 212 => data <= "00000000000";
      when 213 => data <= "00000000000";
      when 214 => data <= "00000000000";
      when 215 => data <= "00000000000";
      when 216 => data <= "00000000000";
      when 217 => data <= "00000000000";
      when 218 => data <= "00000000000";
      when 219 => data <= "00000000000";
      when 220 => data <= "00000000000";
      when 221 => data <= "00000000000";
      when 222 => data <= "00000000000";
      when 223 => data <= "00000000000";
      when 224 => data <= "00000000000";
      when 225 => data <= "00000000000";
      when 226 => data <= "00000000000";
      when 227 => data <= "00000000000";
      when 228 => data <= "00000000000";
      when 229 => data <= "00000000000";
      when 230 => data <= "00000000000";
      when 231 => data <= "00000000000";
      when 232 => data <= "00000000000";
      when 233 => data <= "00000000000";
      when 234 => data <= "00000000000";
      when 235 => data <= "00000000000";
      when 236 => data <= "00000000000";
      when 237 => data <= "00000000000";
      when 238 => data <= "00000000000";
      when 239 => data <= "00000000000";
      when 240 => data <= "00000000000";
      when 241 => data <= "00000000000";
      when 242 => data <= "00000000000";
      when 243 => data <= "00000000000";
      when 244 => data <= "00000000000";
      when 245 => data <= "00000000000";
      when 246 => data <= "00000000000";
      when 247 => data <= "00000000000";
      when 248 => data <= "00000000000";
      when 249 => data <= "00000000000";
      when 250 => data <= "00000000000";
      when 251 => data <= "00000000000";
      when 252 => data <= "00000000000";
      when 253 => data <= "00000000000";
      when 254 => data <= "00000000000";
      when 255 => data <= "00000000000";
      when 256 => data <= "00110011100";
      when 257 => data <= "00110011100";
      when 258 => data <= "00110011100";
      when 259 => data <= "00110011100";
      when 260 => data <= "00110011100";
      when 261 => data <= "00110011100";
      when 262 => data <= "00110011100";
      when 263 => data <= "00110011100";
      when 264 => data <= "00110011100";
      when 265 => data <= "11110100100";
      when 266 => data <= "11111100000";
      when 267 => data <= "01111100100";
      when 268 => data <= "01111100110";
      when 269 => data <= "01111100110";
      when 270 => data <= "01111100110";
      when 271 => data <= "01111100110";
      when 272 => data <= "01111100110";
      when 273 => data <= "01111100110";
      when 274 => data <= "01111100110";
      when 275 => data <= "01111100110";
      when 276 => data <= "01111100110";
      when 277 => data <= "01111100110";
      when 278 => data <= "01111100110";
      when 279 => data <= "01111100110";
      when 280 => data <= "01111100110";
      when 281 => data <= "01111100110";
      when 282 => data <= "01111100110";
      when 283 => data <= "01111100110";
      when 284 => data <= "01111100110";
      when 285 => data <= "01111100110";
      when 286 => data <= "01111100110";
      when 287 => data <= "01111100110";
      when 288 => data <= "01111100110";
      when 289 => data <= "01111110110";
      when 290 => data <= "01111110110";
      when 291 => data <= "01111110110";
      when 292 => data <= "01111110110";
      when 293 => data <= "01111111110";
      when 294 => data <= "01111111110";
      when 295 => data <= "01111111110";
      when 296 => data <= "01111111100";
      when 297 => data <= "01111100100";
      when 298 => data <= "01111100100";
      when 299 => data <= "01111100100";
      when 300 => data <= "01111100100";
      when 301 => data <= "01111100100";
      when 302 => data <= "01111100100";
      when 303 => data <= "01111100100";
      when 304 => data <= "01111100100";
      when 305 => data <= "01111100100";
      when 306 => data <= "01111100100";
      when 307 => data <= "01111100100";
      when 308 => data <= "01111100100";
      when 309 => data <= "01111100100";
      when 310 => data <= "01111100100";
      when 311 => data <= "01111100100";
      when 312 => data <= "01111100100";
      when 313 => data <= "01111100100";
      when 314 => data <= "01111100100";
      when 315 => data <= "01111100100";
      when 316 => data <= "01111100100";
      when 317 => data <= "01111100100";
      when 318 => data <= "01111100100";
      when 319 => data <= "01111100100";
      when 320 => data <= "01111100100";
      when 321 => data <= "01111110100";
      when 322 => data <= "01111110100";
      when 323 => data <= "01111110100";
      when 324 => data <= "01111110100";
      when 325 => data <= "01111111100";
      when 326 => data <= "01111111100";
      when 327 => data <= "01111111100";
      when 328 => data <= "01111111100";
      when 329 => data <= "01001011100";
      when 330 => data <= "01000011100";
      when 331 => data <= "11000011100";
      when 332 => data <= "11000011101";
      when 333 => data <= "00000011100";
      when 334 => data <= "00000000000";
      when 335 => data <= "00000000000";
      when 336 => data <= "00000000000";
      when 337 => data <= "00000000000";
      when 338 => data <= "00000000000";
      when 339 => data <= "00000000000";
      when 340 => data <= "00000000000";
      when 341 => data <= "00000000000";
      when 342 => data <= "00000000000";
      when 343 => data <= "00000000000";
      when 344 => data <= "00000000000";
      when 345 => data <= "00000000000";
      when 346 => data <= "00000000000";
      when 347 => data <= "00000000000";
      when 348 => data <= "00000000000";
      when 349 => data <= "00000000000";
      when 350 => data <= "00000000000";
      when 351 => data <= "00000000000";
      when 352 => data <= "00000000000";
      when 353 => data <= "00000000000";
      when 354 => data <= "00000000000";
      when 355 => data <= "00000000000";
      when 356 => data <= "00000000000";
      when 357 => data <= "00000000000";
      when 358 => data <= "00000000000";
      when 359 => data <= "00000000000";
      when 360 => data <= "00000000000";
      when 361 => data <= "00000000000";
      when 362 => data <= "00000000000";
      when 363 => data <= "00000000000";
      when 364 => data <= "00000000000";
      when 365 => data <= "00000000000";
      when 366 => data <= "00000000000";
      when 367 => data <= "00000000000";
      when 368 => data <= "00000000000";
      when 369 => data <= "00000000000";
      when 370 => data <= "00000000000";
      when 371 => data <= "00000000000";
      when 372 => data <= "00000000000";
      when 373 => data <= "00000000000";
      when 374 => data <= "00000000000";
      when 375 => data <= "00000000000";
      when 376 => data <= "00000000000";
      when 377 => data <= "00000000000";
      when 378 => data <= "00000000000";
      when 379 => data <= "00000000000";
      when 380 => data <= "00000000000";
      when 381 => data <= "00000000000";
      when 382 => data <= "00000000000";
      when 383 => data <= "00000000000";
      when 384 => data <= "00000011100";
      when 385 => data <= "00000011100";
      when 386 => data <= "00000011100";
      when 387 => data <= "00000011100";
      when 388 => data <= "00000000000";
      when 389 => data <= "00000000000";
      when 390 => data <= "00000000000";
      when 391 => data <= "00000000000";
      when 392 => data <= "00000000000";
      when 393 => data <= "00000000000";
      when 394 => data <= "00000000000";
      when 395 => data <= "00000000000";
      when 396 => data <= "00000000000";
      when 397 => data <= "00000000000";
      when 398 => data <= "00000000000";
      when 399 => data <= "00000000000";
      when 400 => data <= "00000000000";
      when 401 => data <= "00000000000";
      when 402 => data <= "00000000000";
      when 403 => data <= "00000000000";
      when 404 => data <= "00000000000";
      when 405 => data <= "00000000000";
      when 406 => data <= "00000000000";
      when 407 => data <= "00000000000";
      when 408 => data <= "00000000000";
      when 409 => data <= "00000000000";
      when 410 => data <= "00000000000";
      when 411 => data <= "00000000000";
      when 412 => data <= "00000000000";
      when 413 => data <= "00000000000";
      when 414 => data <= "00000000000";
      when 415 => data <= "00000000000";
      when 416 => data <= "00000000000";
      when 417 => data <= "00000000000";
      when 418 => data <= "00000000000";
      when 419 => data <= "00000000000";
      when 420 => data <= "00000000000";
      when 421 => data <= "00000000000";
      when 422 => data <= "00000000000";
      when 423 => data <= "00000000000";
      when 424 => data <= "00000000000";
      when 425 => data <= "00000000000";
      when 426 => data <= "00000000000";
      when 427 => data <= "00000000000";
      when 428 => data <= "00000000000";
      when 429 => data <= "00000000000";
      when 430 => data <= "00000000000";
      when 431 => data <= "00000000000";
      when 432 => data <= "00000000000";
      when 433 => data <= "00000000000";
      when 434 => data <= "00000000000";
      when 435 => data <= "00000000000";
      when 436 => data <= "00000000000";
      when 437 => data <= "00000000000";
      when 438 => data <= "00000000000";
      when 439 => data <= "00000000000";
      when 440 => data <= "00000000000";
      when 441 => data <= "00000000000";
      when 442 => data <= "00000000000";
      when 443 => data <= "00000000000";
      when 444 => data <= "00000000000";
      when 445 => data <= "00000000000";
      when 446 => data <= "00000000000";
      when 447 => data <= "00000000000";
      when 448 => data <= "00000000000";
      when 449 => data <= "00000000000";
      when 450 => data <= "00000000000";
      when 451 => data <= "00000000000";
      when 452 => data <= "00000000000";
      when 453 => data <= "00000000000";
      when 454 => data <= "00000000000";
      when 455 => data <= "00000000000";
      when 456 => data <= "00000000000";
      when 457 => data <= "00000000000";
      when 458 => data <= "00000000000";
      when 459 => data <= "00000000000";
      when 460 => data <= "00000000000";
      when 461 => data <= "00000000000";
      when 462 => data <= "00000000000";
      when 463 => data <= "00000000000";
      when 464 => data <= "00000000000";
      when 465 => data <= "00000000000";
      when 466 => data <= "00000000000";
      when 467 => data <= "00000000000";
      when 468 => data <= "00000000000";
      when 469 => data <= "00000000000";
      when 470 => data <= "00000000000";
      when 471 => data <= "00000000000";
      when 472 => data <= "00000000000";
      when 473 => data <= "00000000000";
      when 474 => data <= "00000000000";
      when 475 => data <= "00000000000";
      when 476 => data <= "00000000000";
      when 477 => data <= "00000000000";
      when 478 => data <= "00000000000";
      when 479 => data <= "00000000000";
      when 480 => data <= "00000000000";
      when 481 => data <= "00000000000";
      when 482 => data <= "00000000000";
      when 483 => data <= "00000000000";
      when 484 => data <= "00000000000";
      when 485 => data <= "00000000000";
      when 486 => data <= "00000000000";
      when 487 => data <= "00000000000";
      when 488 => data <= "00000000000";
      when 489 => data <= "00000000000";
      when 490 => data <= "00000000000";
      when 491 => data <= "00000000000";
      when 492 => data <= "00000000000";
      when 493 => data <= "00000000000";
      when 494 => data <= "00000000000";
      when 495 => data <= "00000000000";
      when 496 => data <= "00000000000";
      when 497 => data <= "00000000000";
      when 498 => data <= "00000000000";
      when 499 => data <= "00000000000";
      when 500 => data <= "00000000000";
      when 501 => data <= "00000000000";
      when 502 => data <= "00000000000";
      when 503 => data <= "00000000000";
      when 504 => data <= "00000000000";
      when 505 => data <= "00000000000";
      when 506 => data <= "00000000000";
      when 507 => data <= "00000000000";
      when 508 => data <= "00000000000";
      when 509 => data <= "00000000000";
      when 510 => data <= "00000000000";
      when 511 => data <= "00000000000";
      when others => null;
    end case;
  end if;
end process;

end Behavioral;
