library ieee;
use ieee.std_logic_1164.all;

package gonogo_types is
	constant NBITS : integer := 12;
	constant RAZ_NBITS : std_logic_vector(NBITS-1 downto 0) := "000000000000";
end package;

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all; 
use ieee.numeric_std.all;
-- use work.gonogo_types.all;

entity ouah is
	port(	clk, pb0 : in std_logic;
			dcf77 : in std_logic;
			pinms : out std_logic;
			sdcf77 : out std_logic;
			sframe : out std_logic;
--			sdatabit : out std_logic;
			segment: out std_logic_vector (6 downto 0);
--			select7seg : out std_logic_vector(11 downto 0);
			select7seg : out std_logic_vector(7 downto 0);
			ledday : out std_logic_vector (6 downto 0)
--			s8421 : out std_logic_vector(3 downto 0)
	);
end entity;


architecture tick of ouah is
	
	signal tick_cntr : std_logic_vector(4 downto 0);
	signal tick_cntr_max, rst : std_logic;
	signal usecond_cntr : std_logic_vector(9 downto 0);
	signal usecond_cntr_max : std_logic;
--	signal msecond_cntr : std_logic_vector(14 downto 0);
--	signal msecond_cntr_max : std_logic;
--	signal msecond125 : std_logic; 
--	signal second : std_logic_vector(5 downto 0);
	signal ms : std_logic;
	signal syncdcf77 : std_logic;
	signal cnt200 : integer range 0 to 300;
	signal cnt1500 : integer range 0 to 604800;
	signal bcd : std_logic_vector (3 downto 0);
	signal start_frame : std_logic;
	signal databit :std_logic;
--	signal selector :  std_logic_vector (3 downto 0);
	signal selector :  unsigned (2 downto 0);
	signal selector_max : std_logic;
	signal shiftreg, memreg : std_logic_vector(57 downto 0);
--	signal digit : std_logic_vector (3 downto 0);
	signal dow : std_logic_vector (2 downto 0);
--	signal dm2y : std_logic;
	signal eof : integer range 0 to 100;

	constant n: natural := shiftreg'length;

---------------------------
-- reset
---------------------------
begin
	RESET : process(pb0)
	begin
		if pb0 = '1' then rst <='0'; else rst <= '1'; end if;
	end process;

---------------------------
-- tick counter
---------------------------
	TICK : process(clk, rst)
	begin
		if rst = '1' then
			tick_cntr <= "00000";
			tick_cntr_max <= '0';
		else
			if clk 'event and clk = '1' then 
				if tick_cntr_max = '1' then tick_cntr <= "00000"; else tick_cntr <= tick_cntr + 1;end if;
				if tick_cntr = 10 then tick_cntr_max <= '1'; else tick_cntr_max <= '0';end if;
			end if;
		end if;
	end process;

---------------------------
-- count off 1000 us to form 1ms
---------------------------
-- this process provides a 1000 Hz clock on signal named ms 
	MICROSEC : process(clk, rst)
	begin
		if rst = '1' then
			usecond_cntr <= "0000000000";
			usecond_cntr_max <= '0';
		else
			if clk 'event and clk = '1' then 
				if tick_cntr_max = '1'then
					if usecond_cntr_max = '1' then usecond_cntr <= "0000000000"; else usecond_cntr <= usecond_cntr + 1;end if;
					if usecond_cntr = 998 then usecond_cntr_max <= '1'; else usecond_cntr_max <= '0';end if;
				end if;
			end if;
		end if;
		ms <= usecond_cntr(9);
		pinms <= usecond_cntr(9);
	end process;

---------------------------
-- count off 1000 ms to form 15s
---------------------------
--	MILISEC : process(clk, rst)
--	begin
--		if rst = '1' then
--			msecond_cntr <= "000000000000000";
--			msecond_cntr_max <= '0';
--			dm2y <= '1';
--		else
--			if clk 'event and clk = '1' then
--				if (usecond_cntr_max = '1' and tick_cntr_max = '1') then 
--					if msecond_cntr_max = '1' then msecond_cntr <= "000000000000000"; dm2y <= not dm2y; else msecond_cntr <= msecond_cntr + 1;end if;
--					if msecond_cntr = 998 then msecond_cntr_max <= '1'; else msecond_cntr_max <= '0';end if;
--					if msecond_cntr = 14998 then 
--						msecond_cntr_max <= '1'; 
--						dm2y <= not dm2y;
--					else msecond_cntr_max <= '0';end if;
--				end if;
--			end if;
--		end if;
--		msecond125 <= msecond_cntr(3);
--	end process;

---------------------------
-- synchro DCF77 with clk
---------------------------
-- this process synchronize dcf77 signal with ms clock
	SYNCDCF : process(clk, rst)
	begin
		if clk 'event and clk = '1' then
			if ms = '1' then
				syncdcf77 <= dcf77;
			end if;
		end if;
		sdcf77 <= syncdcf77;
	end process;
---------------------------
-- detect 0 and 1
---------------------------
-- this process detects 0 or 1 when dcf777 pulse duration is 100 ms or 200 ms respectively
	BITDETECT1: process(syncdcf77, ms, rst)
	begin
		if rst = '1' then
			cnt200 <= 0;
--			databit <= '0';
		else 
			if ms 'event and ms = '1' then
				if syncdcf77 = '1' then 
					cnt200 <= cnt200 + 1 ;
				else
					cnt200 <= 0 ;
				end if;
			end if;
--			if syncdcf77 'event and syncdcf77 = '0' then	
--				if cnt200 >= 150 then databit <= '1'; else databit <= '0'; end if;
--			end if;
		end if;
--		sdatabit <= databit;
	end process;
	
	BITDETECT2 : process (syncdcf77, rst)
	begin
		if rst = '1' then
--			cnt200 <= 0;
			databit <= '0';
		else 
			if syncdcf77 'event and syncdcf77 = '0' then	
				if cnt200 >= 150 then databit <= '1'; else databit <= '0'; end if;
			end if;
		end if;
--		sdatabit <= databit;
	end process;
	
---------------------------
-- start frame detection
---------------------------
-- this process detects the begining of frame thanks to the fact that bit 59 does not exists
	SFD : process(syncdcf77, ms, rst)
	begin
		if rst = '1' then
			start_frame <= '0';
			cnt1500 <= 0;
		else 
			if ms 'event and ms = '1' then
				if syncdcf77 = '1' then
					cnt1500 <= 0;
				else
					cnt1500 <= cnt1500 + 1;
					if cnt1500 >= 1500 and cnt1500 < 2100 then
						start_frame <= '1'; 
						memreg <= shiftreg;
						dow <= shiftreg(44 downto 42);
					elsif cnt1500 >= 2100 then
						start_frame <= '0';
					end if;
				end if;
			end if;
		end if;
		sframe <= start_frame;
	end process;

---------------------------
-- get dcf data into shift register
---------------------------
-- bla bla
	DATA2SHIFT : process(syncdcf77, rst)
	begin
		if rst = '1' then
			for i in 57 downto 0 loop
				shiftreg(i) <= '0';
			end loop;
		else
			if syncdcf77 'event and syncdcf77 = '1' then
--				if start_frame = '1' then
					shiftreg(57) <= databit;
					for i in 57 downto 1 loop
						shiftreg(i-1) <= shiftreg(i);
					end loop;
--				end if;
			end if;
		end if;
	end process;

	
---------------------------
-- bcd to 7 segment decoder
---------------------------
-- A3 A2 A1 A0 => a b c d e f g
	DBCD27SEG : process(bcd)
	begin
		case bcd is
			when "0000"=>segment<="1111110";
			when "0001"=>segment<="0110000";
			when "0010"=>segment<="1101101";
			when "0011"=>segment<="1111001";
			when "0100"=>segment<="0110011";
			when "0101"=>segment<="1011011";
			when "0110"=>segment<="1011111";
			when "0111"=>segment<="1110000";
			when "1000"=>segment<="1111111";
			when "1001"=>segment<="1111011";
			when others =>segment<="0000001";
		end case;
	end process;	
	
---------------------------
-- bcd to 1 by 8 decoder
---------------------------
-- A3 A2 A1 A0 => a b c d e f g
	BCD2BY8 : process(rst,dow)
	begin
		if rst = '1' then
			ledday <= "1111111";
		else
			case dow is
				when "001"=>ledday<="0000001"; -- monday
				when "010"=>ledday<="0000010";
				when "011"=>ledday<="0000100";
				when "100"=>ledday<="0001000";
				when "101"=>ledday<="0010000";
				when "110"=>ledday<="0100000";
				when "111"=>ledday<="1000000"; -- sunday
				when others =>ledday<="0000000";
			end case;
		end if;
	end process;	
	---------------------------
-- generate selector
---------------------------
-- generate selector for multiplexer
--	GENSELECT : process(msecond125, rst)
--	GENSELECT : process(ms, rst)
--	begin
--		if rst = '1' then 
--			selector <= "0000";
--			selector_max <= '0';
--		else
--			if ms 'event and ms = '1' then
--				selector <= selector + 1;
--				if selector = "1011" then selector <= "0000"; end if;
--				if selector_max = '1' then selector <= "0000"; else selector <= selector + 1;end if;
--				if selector = 10 then selector_max <= '1'; else selector_max <= '0';end if;
--			end if;
--		end if;
--	end process;
	
	GENSELECT : process(ms, rst)
	begin
		if rst = '1' then 
			selector <= "000";
		else
			if ms 'event and ms = '1' then
				selector <= selector + 1;
			end if;
		end if;
	end process;

	
---------------------------
-- multiplex
---------------------------
-- 
	MULTIPLEX : process(selector)
	begin
--	if ms'event and ms = '1' then
		if start_frame = '1' then
--			if dm2y = '1' then
				case selector is
--	minutes et heures
					when "000" => bcd(3 downto 0) <=  "0000" + memreg(24 downto 21); select7seg <= "11111110"; -- unités minutes
					when "001" => bcd(3 downto 0) <=  "0000" + memreg(27 downto 25); select7seg <= "11111101"; -- dizaines minutes 
					when "010" => bcd(3 downto 0) <=  "0000" + memreg(32 downto 29); select7seg <= "11111011"; -- unités heures
					when "011" => bcd(3 downto 0) <=  "0000" + memreg(34 downto 33); select7seg <= "11110111"; -- dizaines heures
-- jour et mois	
					when "100" => bcd(3 downto 0) <=  "0000" + memreg(39 downto 36); select7seg <= "11101111"; -- unités jours
					when "101" => bcd(3 downto 0) <=  "0000" + memreg(41 downto 40); select7seg <= "11011111"; -- dizaines jours
					when "110" => bcd(3 downto 0) <=  "0000" + memreg(48 downto 45); select7seg <= "10111111"; -- unités mois
					when "111"  => bcd(3 downto 0) <=  "0000" + memreg(49); 		 select7seg <= "01111111"; -- dizaine mois
				end case;
--			else
--				case selector is
--	minutes et heures
--					when "000" => bcd(3 downto 0) <=  "0000" + memreg(24 downto 21); select7seg <= "11111110"; -- unités minutes
--					when "001" => bcd(3 downto 0) <=  "0000" + memreg(27 downto 25); select7seg <= "11111101"; -- dizaines minutes 
--					when "010" => bcd(3 downto 0) <=  "0000" + memreg(32 downto 29); select7seg <= "11111011"; -- unités heures
--					when "011" => bcd(3 downto 0) <=  "0000" + memreg(34 downto 33); select7seg <= "11110111"; -- dizaines heures
-- année
--					when "100" => bcd(3 downto 0) <=  "0000" + memreg(53 downto 50); select7seg <= "111011111"; -- unité an
--					when "101" => bcd(3 downto 0) <=  "0000" + memreg(57 downto 54); select7seg <= "110111111"; -- dizaine an
--					when "110" => bcd(3 downto 0) <=  "0000"; 						 select7seg <= "101111111"; -- centaine an (toujouts 0)
--					when "111" => bcd(3 downto 0) <=  "0010" ; 						 select7seg <= "011111111"; -- milliers an (toujours 2)
--					when others => bcd(3 downto 0)<=  "0000";
--				end case;
--			end if; 
		else
			case selector is
				when "000" => bcd(3 downto 0) <= "0100"; select7seg <= "11111110";
				when "001" => bcd(3 downto 0) <= "0011"; select7seg <= "11111101";
				when "010" => bcd(3 downto 0) <= "0010"; select7seg <= "11111011";
				when "011" => bcd(3 downto 0) <= "0001"; select7seg <= "11110111";
				when "100" => bcd(3 downto 0) <= "0110"; select7seg <= "11101111";
				when "101" => bcd(3 downto 0) <= "0101"; select7seg <= "11011111";
				when "110" => bcd(3 downto 0) <= "1000"; select7seg <= "10111111";
				when "111" => bcd(3 downto 0) <= "0111"; select7seg <= "01111111";
			end case;
		end if;
--	end if;
	end process ;
	
end architecture;
