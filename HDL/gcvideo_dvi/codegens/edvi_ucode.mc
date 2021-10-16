// -*- mcasm -*-
//
// GCVideo DVI HDL
// Copyright (C) 2014-2021, Ingo Korb <ingo@akana.de>
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice,
//    this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
// THE POSSIBILITY OF SUCH DAMAGE.
//
// edvi_ucode.mc: Sequencer tables for enhanced DVI encoder
//

cond SEQUENCE:2;

#define SEQ_BLANK_TO_VIDEO 00
#define SEQ_ONE_PACKET     01
#define SEQ_TWO_PACKETS    10
#define SEQ_DVI            11 // blanking/TMDS state for startup and pure DVI

cond uaddr:7;

field  Enc_Mode        = XX_________; // lags by one pixel
signal ENC_TMDS        = 00.........;
signal ENC_TERC        = 01.........;
signal ENC_GuardV      = 10.........;
signal ENC_GuardD      = 11.........;

field  C2C0_Value      = __XX_______;
signal C2C0_Idle       = ..00.......; // 0000
signal C2C0_Video_Pre  = ..01.......; // 0001
signal C2C0_Data_Pre   = ..11.......; // 0101

field  BT4_Mode        = ____X______;
signal BT4_Send_1      = ....0......;
signal BT4_Send_Header = ....1......;

signal ShiftPacket     = .....1.....;
signal HeaderSendECC   = ......1....;
signal DataSendECC     = .......1...;
signal nFirstPacketBit = ........1..;
signal ShiftSecondPkt  = .........1.;
signal Done            = ..........1; // must be asserted one pixel early

start SEQUENCE=SEQ_BLANK_TO_VIDEO;
  // video preamble
  ENC_TMDS, C2C0_Video_Pre, BT4_Send_1, HeaderSendECC, DataSendECC, nFirstPacketBit;
  hold;
  hold;
  hold;

  hold;
  hold;
  hold;
  hold;

  // video guardband
  hold, -C2C0_Video_Pre, C2C0_Idle;
  hold, -ENC_TMDS, ENC_GuardV;

  // active video
  hold, Done;
  hold, -ENC_GuardV, ENC_TMDS, -Done;


start SEQUENCE=SEQ_ONE_PACKET;
  // data preamble
  ENC_TMDS, C2C0_Data_Pre, BT4_Send_1, HeaderSendECC, DataSendECC, nFirstPacketBit;
  hold;
  hold;
  hold;

  hold;
  hold;
  hold;
  hold;

  // guard band
  hold; // sic! (encmode lagging)
  hold, -ENC_TMDS, ENC_GuardD, ShiftPacket, -HeaderSendECC, -DataSendECC;

  //// data
  // bits 0-3
  hold, BT4_Send_Header, -nFirstPacketBit;
  hold, -ENC_GuardD, ENC_TERC, nFirstPacketBit;
  hold;
  hold;
  // bits 4-7
  hold;
  hold;
  hold;
  hold;
  // bits 8-11
  hold;
  hold;
  hold;
  hold;
  // bits 12-15
  hold;
  hold;
  hold;
  hold;
  // bits 16-19
  hold;
  hold;
  hold;
  hold;
  // bits 20-23
  hold;
  hold;
  hold;
  hold, HeaderSendECC;
  // bits 24-27
  hold;
  hold;
  hold;
  hold, DataSendECC;
  // bits 28-31
  hold;
  hold;
  hold;
  ENC_TERC, C2C0_Idle, BT4_Send_Header, HeaderSendECC, DataSendECC, nFirstPacketBit;

  // guardband
  hold, -BT4_Send_Header, BT4_Send_1;
  hold, -ENC_TERC, ENC_GuardD;

  // blanking
  hold,  Done;
  hold, -Done, -ENC_GuardD, ENC_TMDS;


start SEQUENCE=SEQ_TWO_PACKETS;
  // data preamble
  ENC_TMDS, C2C0_Data_Pre, BT4_Send_1, HeaderSendECC, DataSendECC, nFirstPacketBit;
  hold;
  hold;
  hold;

  hold;
  hold;
  hold;
  hold;

  // guard band
  hold; // sic! (encmode lagging)
  hold, -ENC_TMDS, ENC_GuardD, ShiftPacket, -HeaderSendECC, -DataSendECC;

  //// data of packet 1
  // bits 0-3
  hold, BT4_Send_Header, -nFirstPacketBit;
  hold, -ENC_GuardD, ENC_TERC, nFirstPacketBit;
  hold, ShiftSecondPkt;
  hold;
  // bits 4-7
  hold;
  hold;
  hold;
  hold;
  // bits 8-11
  hold;
  hold;
  hold;
  hold;
  // bits 12-15
  hold;
  hold;
  hold;
  hold;
  // bits 16-19
  hold;
  hold;
  hold;
  hold;
  // bits 20-23
  hold;
  hold;
  hold;
  hold, HeaderSendECC;
  // bits 24-27
  hold;
  hold;
  hold;
  hold, DataSendECC;
  // bits 28-31
  hold;
  hold;
  hold, -ShiftSecondPkt;
  hold, -HeaderSendECC, -DataSendECC;

  //// data of packet 2
  // bits 0-3
  hold;
  hold;
  hold;
  hold;
  // bits 4-7
  hold;
  hold;
  hold;
  hold;
  // bits 8-11
  hold;
  hold;
  hold;
  hold;
  // bits 12-15
  hold;
  hold;
  hold;
  hold;
  // bits 16-19
  hold;
  hold;
  hold;
  hold;
  // bits 20-23
  hold;
  hold;
  hold;
  hold, HeaderSendECC;
  // bits 24-27
  hold;
  hold;
  hold;
  hold, DataSendECC;
  // bits 28-31
  hold;
  hold;
  hold;
  ENC_TERC, C2C0_Idle, BT4_Send_Header, HeaderSendECC, DataSendECC, nFirstPacketBit;

  // guardband
  hold, -BT4_Send_Header, BT4_Send_1;
  hold, -ENC_TERC, ENC_GuardD;

  // blanking
  hold,  Done;
  hold, -Done, -ENC_GuardD, ENC_TMDS;


start SEQUENCE=SEQ_DVI;
  // standard TMDS according to plain DVI spec
  ENC_TMDS, C2C0_Idle, BT4_Send_1, HeaderSendECC, DataSendECC, nFirstPacketBit;
  hold;
  hold;
  hold;
