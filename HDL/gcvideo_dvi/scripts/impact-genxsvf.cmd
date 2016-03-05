setMode -bs
addDevice -p 1 -file "%BITFILE%"
attachflash -position 1 -spi "%PROMTYPE%"
assignfiletoattachedflash -position 1 -file "%MCSFILE%"
setCable -port xsvf -file "%XSVFFILE%"
Program -p 1 -dataWidth 1 -spionly -e -v -loadfpga 
exit
