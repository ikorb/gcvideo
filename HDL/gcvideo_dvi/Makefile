# FIXME: Header, make-it-work, etc.

VERSION := 2.1

SRC_COMMON := \
	src/Blanking_Regenerator_Fixed.vhd \
	src/CPUSubsystem.vhd               \
	src/ClockGen.vhd                   \
	src/Deglitcher.vhd                 \
	src/Linedoubler.vhd                \
	src/PadAnalyzer.vhd                \
	src/PadReader.vhd                  \
	src/SPDIF_Encoder.vhd              \
	src/SimpleROM.vhd                  \
	src/TMDS_encoder.vhd               \
	src/TextOSD.vhd                    \
	src/ZPUBusMux.vhd                  \
	src/ZPUDevices.vhd                 \
	src/ZPUIRQController.vhd           \
	src/ZPUVideoInterface.vhd          \
	src/ZPUWatchdog.vhd                \
	src/ZPU_DPRAM.vhd                  \
	src/ZPU_SPI.vhd                    \
	src/audio_spdif.vhd                \
	src/aux_ecc1.vhd                   \
	src/aux_ecc2.vhd                   \
	src/aux_encoder.vhd                \
	src/component_defs.vhd             \
	src/convert_422_to_444.vhd         \
	src/convert_yuv_to_rgb.vhd         \
	src/delayline_bool.vhd             \
	src/delayline_unsigned.vhd         \
	src/dvid.vhd                       \
	src/dvienc_defs.vhd                \
	src/edvi_ucode.vhd                 \
	src/gcdv_decoder.vhd               \
	src/i2s_decoder.vhd                \
	src/infoframe_rom.vhd              \
	src/scanline_generator.vhd         \
	src/video_defs.vhd                 \
	src/zpu_core_flex.vhd              \
	src/zpu_rom.vhd                    \
	src/zpupkg.vhd


SRC_P2XH     := src/toplevel_p2xh.vhd
SRC_SHURIKEN := src/toplevel_shuriken.vhd
BMM          := src/zpu_bootram.bmm
PART         := xc3s200a-vq100-4

PROMFILE     := gcvideo-dvi-$(TARGET)-$(VERSION)-spirom
PROMTYPE     := M25P40
XSVFFILE     := gcvideo-dvi-$(TARGET)-$(VERSION)-$(PROMTYPE).xsvf

MAP_OPTS := -timing -logic_opt on -ol high -xe n -t 1 -register_duplication on -cm balanced -detail -ir off -ignore_keep_hierarchy -pr b -bp -power off
PAR_OPTS := -ol high -xe n -t 1

SRC = $(SRC_COMMON)

ifeq ($(TARGET),p2xh)
  SRC += $(SRC_P2XH)
  UCF := src/pindefs-p2xh.ucf
else ifeq ($(TARGET),shuriken)
  SRC += $(SRC_SHURIKEN)
  UCF := src/pindefs-shuriken.ucf
else
dummy:
	@echo "TARGET variable not specified"
	@echo "Please select a build target using"
	@echo "make TARGET=p2xh or make TARGET=shuriken"
	@false
endif

# Enable verbose compilation with "make V=1"
ifdef V
 Q :=
 E := @:
else
 Q := @
 E := @echo
endif

TOPLEVEL := toplevel_$(TARGET)

all: build/$(XSVFFILE)

build/$(XSVFFILE): build/$(PROMFILE).mcs
	$(E) "---- XSVFGEN  $<"
	$(Q) sed -e "s/%BITFILE%/$(TOPLEVEL).bit/;s/%MCSFILE%/$(PROMFILE).mcs/;s/%PROMTYPE%/$(PROMTYPE)/;s/%XSVFFILE%/$(XSVFFILE)/" scripts/impact-genxsvf.cmd > build/genxsvf.cmd
	$(Q)cd build ; impact -batch genxsvf.cmd

build/$(PROMFILE).mcs: build/$(TOPLEVEL).bit
	$(E) "---- PROMGEN  $<"
	$(Q) sed -e "s/%BITFILE%/$(TOPLEVEL).bit/;s/%OUTFILE%/$(PROMFILE)./" scripts/impact-genprom.cmd > build/genprom.cmd
	$(Q)cd build ; impact -batch genprom.cmd

build/%.bit: build/%.ncd
	$(E) "---- BITGEN   $<"
	$(Q)cd build ; bitgen -f ../scripts/bitgenconfig.ut $(TOPLEVEL).ncd

build/%.ncd: build/%.pcf
	$(E) "---- PAR      $<"
	$(Q)cd build ; par -w $(PAR_OPTS) $(TOPLEVEL)_map.ncd $(TOPLEVEL).ncd $(TOPLEVEL).pcf

build/%.pcf: build/%.ngd
	$(E) "---- MAP      $<"
	$(Q)cd build ; map -p $(PART) $(MAP_OPTS) -o $(TOPLEVEL)_map.ncd $(TOPLEVEL).ngd $(TOPLEVEL).pcf

build/%.ngd: build/%.ngc $(UCF) $(BMM)
	$(E) "---- NGDBUILD $<"
	$(Q)cd build ; ngdbuild -dd _ngo -nt timestamp -uc ../$(UCF) -bm ../$(BMM) -p $(PART) $(TOPLEVEL).ngc $(TOPLEVEL).ngd

build/%.ngc: build/%.xst
	$(E) "---- XST      $<"
	$(Q)cd build ; xst -ifn $(TOPLEVEL).xst -ofn $(TOPLEVEL).syr

build/%.xst: build/%.prj scripts/template.xst src/zpu_bootrom.mif
	$(E) "---- GENXST   $<"
	$(Q)cp scripts/template.xst $@
	$(Q)echo -ifn $(TOPLEVEL).prj >> $@
	$(Q)echo -ofn $(TOPLEVEL)     >> $@
	$(Q)echo -top $(TOPLEVEL)     >> $@

build/%.prj: | build # FIXME: Should somehow depend on the content of the source file list
	$(E) "---- GENPRJ   $@"
	$(Q)scripts/genproject.pl $(SRC) > $@

build:
	$(E) "---- MKDIR    $@"
	$(Q)mkdir -p build/xst/tmp

clean:
	$(E) "---- CLEAN"
	-$(Q)rm -rf build # brute-force cleanup

.PRECIOUS : build/%.prj build/%.xst build/%.ngc build/%.ngd build/%.pcf build/%.ncd build/%.bit build/$(PROMFILE).mcs build/$(XSVFFILE)
