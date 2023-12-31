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
			sdatabit : out std_logic;
			segment: out std_logic_vector (6 downto 0);
			select7seg : out std_logic_vector(3 downto 0);
			s8421 : out std_logic_vector(3 downto 0)
	);
end entity;


architecture tick of ouah is
	
	signal tick_cntr : std_logic_vector(4 downto 0);
	signal tick_cntr_max, rst : std_logic;
	signal usecond_cntr : std_logic_vector(9 downto 0);
	signal usecond_cntr_max : std_logic;
	signal msecond_cntr : std_logic_vector(9 downto 0);
	signal msecond_cntr_max : std_logic;
	signal msecond125 : std_logic; 
	signal second : std_logic_vector(5 downto 0);
	signal ms : std_logic;
	signal syncdcf77 : std_logic;
	signal cnt200 : integer range 0 to 300;
	signal cnt1500 : integer range 0 to 2000;
	signal bcd : std_logic_vector (3 downto 0);
	signal start_frame : std_logic;
	signal databit :std_logic;
	signal selector : unsigned (1 downto 0);
	signal shiftreg, memreg : std_logic_vector(58 downto 0);
	signal digit : std_logic_vector (3 downto 0);

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
-- count off 1000 ms to form 1s
---------------------------
	MILISEC : process(clk, rst)
	begin
		if rst = '1' then
			msecond_cntr <= "0000000000";
			msecond_cntr_max <= '0';
		else
			if clk 'event and clk = '1' then
				if (usecond_cntr_max = '1' and tick_cntr_max = '1') then 
					if msecond_cntr_max = '1' then msecond_cntr <= "0000000000"; else msecond_cntr <= msecond_cntr + 1;end if;
					if msecond_cntr = 998 then msecond_cntr_max <= '1'; else msecond_cntr_max <= '0';end if;
				end if;
			end if;
		end if;
--		second <= msecond_cntr(9);
		msecond125 <= msecond_cntr(3);
--		pinsecond <= second;
	end process;

---------------------------
-- synchro DCF77 with clk
---------------------------
-- this process synchronize dcf77 signal with ms clock
	SYNCDCF : process(clk, rst)
--	SYNCDCF : process(ms, rst)
	begin
		if clk 'event and clk = '1' then
--			if ms 'event and ms = '1' then
				syncdcf77 <= dcf77;
--			end if;
		end if;
		sdcf77 <= syncdcf77;
	end process;
---------------------------
-- detect 0 and 1
---------------------------
-- this process detects 0 or 1 when dcf777 pulse duration is 100 ms or 200 ms respectively
	BITDETECT : process(syncdcf77, ms, rst)
	begin
		if rst = '1' then
			cnt200 <= 0;
			databit <= '0';
		elsif syncdcf77 = '1' then
			if ms'event and ms = '1' then
				cnt200 <= cnt200 + 1;
			end if;
		else
			if cnt200 >= 150 then databit <= '1'; else databit <= '0'; end if;
			cnt200 <= 0;
		end if;
		sdatabit <= databit;
	end process;
	
--	BITDETECT1: process(syncdcf77, ms, rst)
--	begin
--		if rst = '1' then
--			cnt200 <= 0;
--			databit <= '0';
--		else 
--			if ms 'event and ms = '1' then
--				if syncdcf77 = '1' then 
--				if dcf77 = '1' then 
--					cnt200 <= cnt200 + 1 ;
--				else
--					cnt200 <= 0 ;
--				end if;
--			end if;
--			if syncdcf77 'event and syncdcf77 = '0' then	
--				if cnt200 >= 150 then databit <= '1'; else databit <= '0'; end if;
--			end if;
--		end if;
--		sdatabit <= databit;
--	end process;
	
--	BITDETECT2 : process (syncdcf77, rst)
--	begin
--		if rst = '1' then
--			cnt200 <= 0;
--			databit <= '0';
--		else 
--			if ms 'event and ms = '1' then
--			if syncdcf77 'event and syncdcf77 = '0' then
--				if dcf77 = '0' then
--					if cnt200 >= 150 then databit <= '1'; else databit <= '0'; end if;
--				end if;
--			end if;
--		end if;
--		sdatabit <= databit;
--	end process;
	
---------------------------
-- start frame detection
---------------------------
-- this process detects the begining of frame thanks to the fact that bit 59 does not exists
	SFD : process(ms, rst)
	begin
		if rst = '1' then
			start_frame <= '0';
			cnt1500 <= 0;
		else
			if ms 'event and ms = '1' then
				if syncdcf77 = '1' then
--				if dcf77 = '1' then
					cnt1500 <= 0;
				else
					cnt1500 <= cnt1500 + 1;
					if cnt1500 >= 1500 then
						start_frame <= '1'; 
						memreg <= shiftreg;
						s8421 <= shiftreg(24 downto 21);
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
			for i in 58 downto 0 loop
				shiftreg(i) <= '0';
			end loop;
		else
			if syncdcf77 'event and syncdcf77 = '1' then
--			if ms 'event and ms = '1' then
---				if start_minutes = '1' then
--				if start_frame = '1' then
--				if dcf77 = '1' then
					shiftreg(58) <= databit;
					for i in 58 downto 1 loop
						shiftreg(i-1) <= shiftreg(i);
					end loop;
--			end if;
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
-- generate selector
---------------------------
-- generate selector for multiplexer
	GENSELECT : process(msecond125, rst)
	begin
		if rst = '1' then 
			selector <= "00";
		else
			if msecond125 'event and msecond125 = '1' then
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
		case selector is
--			when "00" => bcd(3 downto 0) <=  "0000" + memreg(24 downto 21); select7seg <= "1110";
--			when "01" => bcd(3 downto 0) <=  "0000" + memreg(27 downto 25); select7seg <= "1101";
--			when "10" => bcd(3 downto 0) <=  "0000" + memreg(32 downto 29); select7seg <= "1011";
--			when "11" => bcd(3 downto 0) <=  "0000" + memreg(34 downto 33); select7seg <= "0111";
-- minutes et heures
			when "00" => bcd(3 downto 0) <=  "0000" + memreg(25 downto 22); select7seg <= "1110";
			when "01" => bcd(3 downto 0) <=  "0000" + memreg(28 downto 26); select7seg <= "1101";
			when "10" => bcd(3 downto 0) <=  "0000" + memreg(33 downto 30); select7seg <= "1011";
			when "11" => bcd(3 downto 0) <=  "0000" + memreg(35 downto 34); select7seg <= "0111";
-- jour et mois
--			when "00" => bcd(3 downto 0) <=  "0000" + memreg(40 downto 37); select7seg <= "1110";
--			when "01" => bcd(3 downto 0) <=  "0000" + memreg(42 downto 41); select7seg <= "1101";
--			when "10" => bcd(3 downto 0) <=  "0000" + memreg(49 downto 46); select7seg <= "1011";
--			when "11" => bcd(3 downto 0) <=  "0000" + memreg(50); select7seg <= "0111";
-- jds et ann�e
--			when "00" => bcd(3 downto 0) <=  "0000" + memreg(45 downto 43); select7seg <= "1110";
--			when "01" => bcd(3 downto 0) <=  "0000"; select7seg <= "1101";
--			when "10" => bcd(3 downto 0) <=  "0000" + memreg(54 downto 51); select7seg <= "1011";
--			when "11" => bcd(3 downto 0) <=  "0000" + memreg(55 downto 58); select7seg <= "0111";
--			when others => bcd(3 downto 0) <=  "0000";
		end case ;
	end process ;
	
end architecture;
