#include <math.h>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <time.h>
#include <string.h>

#include <wiringPi.h>

#define DCF77_PIN	22



int header[] = {
   1,		//start minutes (always at 1)
   1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
   0, 		// toggle winter/summer
   1,0,         // CET/CEST
   0,		// seconde intercalaire
   1		// start timme coding (always at 1)
};

const int w_minutes[] = {40, 20, 10, 8, 4, 2, 1};
const int w_hours[] = {20, 10, 8, 4, 2, 1};
const int w_day_of_month[] = {20, 10, 8, 4, 2, 1};
const int w_day_of_week[] = {4, 2, 1};
const int w_month[] = {10, 8, 4, 2, 1};
const int w_year[] = {80, 40, 20, 10, 8, 4, 2, 1};

int parity = 0;

void send_one(void)
{
   digitalWrite(DCF77_PIN, HIGH);
   delay(200);
   digitalWrite(DCF77_PIN, LOW);
   delay(800);
   printf("1");  fflush(stdout);
}

void send_zero(void)
{
   digitalWrite(DCF77_PIN, HIGH);
   delay(100);
   digitalWrite(DCF77_PIN, LOW);
   delay(900);
   printf("0");  fflush(stdout);
}

void send_nothing(void)
{
   digitalWrite(DCF77_PIN, LOW);
   delay(1000);
   printf("X");  fflush(stdout);
}

void send_header(void)
{

   for (int i = 0; i< sizeof(header)/sizeof(int); i++){
      if (header[i] == 0)
         send_zero();
      else
         send_one();
   }
}


void send_dec2bcd(const int *t, int size, int data)
{
   int i = 0, bcd;
   char tmp[9];
   size /= sizeof(int);
   do {
      bcd = data / t[i];
      if (bcd == 1) {
         tmp[i] = '1';
         parity++;
      }
      else 
         tmp[i] = '0';
      data = data  % t[i];
   } while (++i < size);
   do {
      if(tmp[i-1] == '1') send_one(); else send_zero();
   } while (--i > 0);
}

void send_parity(void)
{
   printf("|");
   if ((parity % 2) == 0)
      send_one();
   else 
      send_zero();
   parity = 0;
}

int main (int argc, char** argv)
{
   time_t dcftime; 
   struct tm dcfdate;
   struct tm *pdate = &dcfdate;
   int dow; // day of week following dcf77 standard (1=monday, 7=sunday)
   //int reversed;

   // initilization of wiringpi gpio library
   wiringPiSetupGpio() ;
   pinMode(DCF77_PIN, OUTPUT);
   digitalWrite(DCF77_PIN, LOW);
   for(;;) {
   // get date and time of the next minute
   dcftime = time(NULL)+60; 
   pdate = localtime(&dcftime);
   printf("Le:%02d/%02d/%02d à heure:%02d:%02d CET/CEST=%d\n",  pdate->tm_mday,  pdate->tm_mon+1,  pdate->tm_year-100, pdate->tm_hour, pdate->tm_min, pdate->tm_isdst);
  // CET/CEST
   if(pdate->tm_isdst == 0){
      header[17] = 0;
      header[18] = 1;
   }
   else{
      header[17] = 1;
      header[18] = 0;
   }
 
  // send header
   send_header();
   printf("|"); fflush(stdout);
   // minutes
   send_dec2bcd(w_minutes, sizeof(w_minutes), pdate->tm_min);
   send_parity();
   printf("|"); fflush(stdout);
   // hours
   send_dec2bcd(w_hours, sizeof(w_hours), pdate->tm_hour);
   send_parity();
   printf("|"); fflush(stdout);
   // day of month
   send_dec2bcd(w_day_of_month, sizeof(w_day_of_month), pdate->tm_mday);
   printf("|"); fflush(stdout);
   // day of week
   dow = pdate->tm_wday == 0 ? 7 :  pdate->tm_wday;
   send_dec2bcd(w_day_of_week, sizeof(w_day_of_week), dow);
   printf("|"); fflush(stdout);
   // send month number
   send_dec2bcd(w_month, sizeof(w_month), pdate->tm_mon+1);
   printf("|"); fflush(stdout);
   // year
   send_dec2bcd(w_year, sizeof(w_year), pdate->tm_year-100);
   send_parity();
   printf("|"); fflush(stdout);
   // send end of frame
   send_nothing();
   printf ("\n");
   }
   return 0;
}
