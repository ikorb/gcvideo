setMode -pff
addConfigDevice  -name "%OUTFILE%" -path "."
setSubmode -pffspi
setAttribute -configdevice -attr multibootBpiType -value ""
addDesign -version 0 -name "0"
addDeviceChain -index 0
setAttribute -configdevice -attr compressed  -value "FALSE"
setAttribute -configdevice -attr autoSize    -value "FALSE"
setAttribute -configdevice -attr fileFormat  -value "mcs"
setAttribute -configdevice -attr fillValue   -value "FF"
setAttribute -configdevice -attr swapBit     -value "FALSE"
setAttribute -configdevice -attr dir         -value "UP"
setAttribute -configdevice -attr multiboot   -value "FALSE"
setAttribute -configdevice -attr spiSelected -value "TRUE"
addPromDevice -p 1 -size 512 -name 512K
setAttribute -design -attr name -value "0000"
addDevice -p 1 -file "%BITFILE%"
generate
setCurrentDesign -version 0
exit
