--------------------------------------------------------------------------------
-- Engineer:      Mike Field <hamster@snap.net.nz>
-- Description:   Converts VGA signals into DVID bitstreams.
--
--                'clk' and 'clk_n' should be 5x clk_pixel.
--
--                'blank' should be asserted during the non-display 
--                portions of the frame
--
-- Minor modifications by Ingo Korb:
-- - added a pixel clock enable signal
-- - added optional inversion for all three channels to allow swapped diff pairs
-- Original source from http://hamsterworks.co.nz/mediawiki/index.php/Dvid_test
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
Library UNISIM;
use UNISIM.vcomponents.all;

entity dvid is
    Generic ( -- allow inversion of each differential pair to account for pin swaps
      Invert_Red  : Boolean := false;
      Invert_Green: Boolean := false;
      Invert_Blue : Boolean := false
    );
    Port ( clk         : in  STD_LOGIC;
           clk_n       : in  STD_LOGIC;
           clk_pixel   : in  STD_LOGIC;
           clk_pixel_en: in  boolean;
           red_p       : in  STD_LOGIC_VECTOR (7 downto 0);
           green_p     : in  STD_LOGIC_VECTOR (7 downto 0);
           blue_p      : in  STD_LOGIC_VECTOR (7 downto 0);
           blank       : in  STD_LOGIC;
           hsync       : in  STD_LOGIC;
           vsync       : in  STD_LOGIC;
           red_s       : out STD_LOGIC;
           green_s     : out STD_LOGIC;
           blue_s      : out STD_LOGIC;
           clock_s     : out STD_LOGIC);
end dvid;

architecture Behavioral of dvid is
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

   signal encoded_red, encoded_green, encoded_blue    : std_logic_vector(9 downto 0);
   signal latched_red, latched_green, latched_blue    : std_logic_vector(9 downto 0) := (others => '0');
   signal shift_red,   shift_green,   shift_blue      : std_logic_vector(9 downto 0) := (others => '0');

   signal out_red, out_green, out_blue: std_logic_vector(1 downto 0);

   signal shift_clock   : std_logic_vector(9 downto 0) := "0000011111";

   
   constant c_red       : std_logic_vector(1 downto 0) := (others => '0');
   constant c_green     : std_logic_vector(1 downto 0) := (others => '0');
   signal   c_blue      : std_logic_vector(1 downto 0);

begin   
   c_blue <= vsync & hsync;
   
   TDMS_encoder_red:   TDMS_encoder PORT MAP(clk => clk_pixel, clk_en => clk_pixel_en, data => red_p,   c => c_red,   blank => blank, encoded => encoded_red);
   TDMS_encoder_green: TDMS_encoder PORT MAP(clk => clk_pixel, clk_en => clk_pixel_en, data => green_p, c => c_green, blank => blank, encoded => encoded_green);
   TDMS_encoder_blue:  TDMS_encoder PORT MAP(clk => clk_pixel, clk_en => clk_pixel_en, data => blue_p,  c => c_blue,  blank => blank, encoded => encoded_blue);

   ODDR2_red   : ODDR2 generic map( DDR_ALIGNMENT => "C0", INIT => '0', SRTYPE => "ASYNC") 
      port map (Q => red_s,   D0 => out_red(0),   D1 => out_red(1),   C0 => clk, C1 => clk_n, CE => '1', R => '0', S => '0');

   ODDR2_green : ODDR2 generic map( DDR_ALIGNMENT => "C0", INIT => '0', SRTYPE => "ASYNC") 
      port map (Q => green_s, D0 => out_green(0), D1 => out_green(1), C0 => clk, C1 => clk_n, CE => '1', R => '0', S => '0');

   ODDR2_blue  : ODDR2 generic map( DDR_ALIGNMENT => "C0", INIT => '0', SRTYPE => "ASYNC") 
      port map (Q => blue_s,  D0 => out_blue(0),  D1 => out_blue(1),  C0 => clk, C1 => clk_n, CE => '1', R => '0', S => '0');

   ODDR2_clock : ODDR2 generic map( DDR_ALIGNMENT => "C0", INIT => '0', SRTYPE => "ASYNC") 
      port map (Q => clock_s, D0 => shift_clock(0), D1 => shift_clock(1), C0 => clk, C1 => clk_n, CE => '1', R => '0', S => '0');

   -- add optional inversion of the output bits
   out_red   <= not shift_red(1 downto 0)   when Invert_Red   else shift_red(1 downto 0);
   out_green <= not shift_green(1 downto 0) when Invert_Green else shift_green(1 downto 0);
   out_blue  <= not shift_blue(1 downto 0)  when Invert_Blue  else shift_blue(1 downto 0);

   process(clk_pixel, clk_pixel_en)
   begin
      if rising_edge(clk_pixel) and clk_pixel_en then 
            latched_red   <= encoded_red;
            latched_green <= encoded_green;
            latched_blue  <= encoded_blue;
      end if;
   end process;

   process(clk)
   begin
      if rising_edge(clk) then 
         if shift_clock = "0000011111" then
            shift_red   <= latched_red;
            shift_green <= latched_green;
            shift_blue  <= latched_blue;
         else
            shift_red   <= "00" & shift_red  (9 downto 2);
            shift_green <= "00" & shift_green(9 downto 2);
            shift_blue  <= "00" & shift_blue (9 downto 2);
         end if;
         shift_clock <= shift_clock(1 downto 0) & shift_clock(9 downto 2);
      end if;
   end process;
   
end Behavioral;
