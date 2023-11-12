/**
 * Copyright (c) 2022 Raspberry Pi (Trading) Ltd.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

//ajout simulateur dcf77

#include <time.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

#include "hardware/rtc.h"
#include "hardware/gpio.h"
#include "hardware/structs/timer.h"
#include "pico/stdlib.h"
#include "pico/util/datetime.h"
#include "pico/cyw43_arch.h"


#include "lwip/dns.h"
#include "lwip/pbuf.h"
#include "lwip/udp.h"

typedef struct NTP_T_ {
    ip_addr_t ntp_server_address;
    bool dns_request_sent;
    struct udp_pcb *ntp_pcb;
    absolute_time_t ntp_test_time;
    alarm_id_t ntp_resend_alarm;
} NTP_T;

#define NTP_SERVER "pool.ntp.org"
#define NTP_MSG_LEN 48
#define NTP_PORT 123
#define NTP_DELTA 2208988800 // seconds between 1 Jan 1900 and 1 Jan 1970
#define NTP_TEST_TIME (30 * 1000)
#define NTP_RESEND_TIME (10 * 1000)

#define GPIO_DCF77 28
#define HIGH 1
#define LOW 0
// overide SSID and PASSWORD definition in CMakeLists.txt
//#define WIFI_SSID "XXXXXXXX"
//#define WIFI_PASSWORD "XXXXXXXX"
// Time zone for Paris (must be replaced by yours)
#define TIME_ZONE "CET-1CEST-2,M3.5.0/2,M10.5.0/3"


// Sstruct for rtc
static datetime_t t = {
    .year  = 0,
    .month = 0,
    .day   = 0,
    .dotw  = 0, // 0 is Sunday, so 5 is Friday
    .hour  = 0,
    .min   = 0,
    .sec   = 0
};

static int cet_cest_flag = 0; // >0 means CEST, 0 means CET
static int header[] = {
   1,		//start minutes (always at 1)
   1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
   0, 		// toggle winter/summer
   1,0,         // CET/CEST
   0,		// seconde intercalaire
   1		// start timme coding (always at 1)
};
static int parity = 0;
const int w_minutes[] = {40, 20, 10, 8, 4, 2, 1};
const int w_hours[] = {20, 10, 8, 4, 2, 1};
const int w_day_of_month[] = {20, 10, 8, 4, 2, 1};
const int w_day_of_week[] = {4, 2, 1};
const int w_month[] = {10, 8, 4, 2, 1};
const int w_year[] = {80, 40, 20, 10, 8, 4, 2, 1};


void send_one(void)
{
   cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, HIGH);
   gpio_put(GPIO_DCF77, HIGH);
   busy_wait_ms(200);
   cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, LOW);
   gpio_put(GPIO_DCF77, LOW);
   busy_wait_ms(800);
   printf("1");  fflush(stdout);
}

void send_zero(void)
{
   cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, HIGH);
   gpio_put(GPIO_DCF77, HIGH);
   busy_wait_ms(100);
   cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, LOW);
   gpio_put(GPIO_DCF77, LOW);
    busy_wait_ms(900);
   printf("0");  fflush(stdout);
}

void send_nothing(void)
{
   cyw43_arch_gpio_put(CYW43_WL_GPIO_LED_PIN, LOW);
   gpio_put(GPIO_DCF77, LOW);
   busy_wait_ms(1000);
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

int send_dcf77_frame (void)
{

   //const uint LED_PIN = PICO_DEFAULT_LED_PIN;  time_t dcftime; 
   //struct tm dcfdate;
   //struct tm *pdate = &dcfdate;
   int dow; // day of week following dcf77 standard (1=monday, 7=sunday)
   //int reversed;

   // initilization gpio library
   //gpio_init(LED_PIN);
   //gpio_set_dir(LED_PIN, GPIO_OUT);

   for(;;) {
   // get date and time from the rtc
   //dcftime = time(NULL)+60; 
   //pdate = localtime(&dcftime);
   rtc_get_datetime(&t);
   if (t.dotw == 0) t.dotw = 7;
   printf("Le:%02d/%02d/%02d à heure:%02d:%02d %s\n", 
        t.day,  t.month,  t.year-100, t.hour, t.min, cet_cest_flag >0 ? "CEST" : "CET");
  // CET/CEST
   if(cet_cest_flag > 0){
      header[17] = 1;
      header[18] = 0;
   }
   else{
      header[17] = 0;
      header[18] = 1;
   }
 
  // send header
   send_header();
   printf("|"); fflush(stdout);
   // minutes
   send_dec2bcd(w_minutes, sizeof(w_minutes), t.min);
   send_parity();
   printf("|"); fflush(stdout);
   // hours
   send_dec2bcd(w_hours, sizeof(w_hours), t.hour);
   send_parity();
   printf("|"); fflush(stdout);
   // day of month
   send_dec2bcd(w_day_of_month, sizeof(w_day_of_month), t.day);
   printf("|"); fflush(stdout);
   // day of week
   dow = t.dotw == 0 ? 7 :  t.dotw;
   send_dec2bcd(w_day_of_week, sizeof(w_day_of_week), dow);
   printf("|"); fflush(stdout);
   // send month number
   send_dec2bcd(w_month, sizeof(w_month), t.month);
   printf("|"); fflush(stdout);
   // year
   send_dec2bcd(w_year, sizeof(w_year), t.year-100);
   send_parity();
   printf("|"); fflush(stdout);
   // send end of frame
   send_nothing();
   printf ("\n");
   }
   return 0;
}


// Called with results of operation
static void ntp_result(NTP_T* state, int status, time_t *result) {
    if (status == 0 && result) {
        // add 60 sec as dcf77 provide time of the next minute
        *result += 60;
        //struct tm *utc = gmtime(result);
        struct tm *utc = localtime(result);
        printf("got ntp response: %02d/%02d/%04d %02d:%02d:%02d DoW=%02d %s\n", utc->tm_mday, utc->tm_mon + 1, utc->tm_year + 1900,
               utc->tm_hour, utc->tm_min, utc->tm_sec, utc->tm_wday, utc->tm_isdst > 0 ? "CSET" : "CET");
        //printf("got ntp response: %02d/%02d/%04d %02d:%02d:%02d DoW=%02d CET/CEST = %d\n", utc->tm_mday, utc->tm_mon + 1, utc->tm_year + 1900,
        //       utc->tm_hour, utc->tm_min, utc->tm_sec, utc->tm_wday, utc->tm_isdst);
        // map struct tm into datetime
        t.year = utc->tm_year;
        t.month = utc->tm_mon+1,
        t.day = utc->tm_mday;
        //t.hour = (utc->tm_hour + (utc->tm_isdst > 0 ? 2 : 1)) % 24;
        t.hour = utc->tm_hour;
        t.min = utc->tm_min;
        t.sec = utc->tm_sec;
        t.dotw = utc->tm_wday;
    //    if (t.dotw == 0) t.dotw = 7;
        //remember CET/CEST
        cet_cest_flag = utc->tm_isdst; //1 is CEST; 0 is CET
        rtc_set_datetime(&t);
        busy_wait_us(64);
        //sleep_us(64);
        send_dcf77_frame();
 
    }

    if (state->ntp_resend_alarm > 0) {
        cancel_alarm(state->ntp_resend_alarm);
        state->ntp_resend_alarm = 0;
    }
    state->ntp_test_time = make_timeout_time_ms(NTP_TEST_TIME);
    state->dns_request_sent = false;
}

static int64_t ntp_failed_handler(alarm_id_t id, void *user_data);

// Make an NTP request
static void ntp_request(NTP_T *state) {
    // cyw43_arch_lwip_begin/end should be used around calls into lwIP to ensure correct locking.
    // You can omit them if you are in a callback from lwIP. Note that when using pico_cyw_arch_poll
    // these calls are a no-op and can be omitted, but it is a good practice to use them in
    // case you switch the cyw43_arch type later.
    cyw43_arch_lwip_begin();
    struct pbuf *p = pbuf_alloc(PBUF_TRANSPORT, NTP_MSG_LEN, PBUF_RAM);
    uint8_t *req = (uint8_t *) p->payload;
    memset(req, 0, NTP_MSG_LEN);
    req[0] = 0x1b;
    udp_sendto(state->ntp_pcb, p, &state->ntp_server_address, NTP_PORT);
    pbuf_free(p);
    cyw43_arch_lwip_end();
}

static int64_t ntp_failed_handler(alarm_id_t id, void *user_data)
{
    NTP_T* state = (NTP_T*)user_data;
    printf("ntp request failed\n");
    ntp_result(state, -1, NULL);
    return 0;
}

// Call back with a DNS result
static void ntp_dns_found(const char *hostname, const ip_addr_t *ipaddr, void *arg) {
    NTP_T *state = (NTP_T*)arg;
    if (ipaddr) {
        state->ntp_server_address = *ipaddr;
        printf("ntp address %s\n", ipaddr_ntoa(ipaddr));
        ntp_request(state);
    } else {
        printf("ntp dns request failed\n");
        ntp_result(state, -1, NULL);
    }
}

// NTP data received
static void ntp_recv(void *arg, struct udp_pcb *pcb, struct pbuf *p, const ip_addr_t *addr, u16_t port) {
    NTP_T *state = (NTP_T*)arg;
    uint8_t mode = pbuf_get_at(p, 0) & 0x7;
    uint8_t stratum = pbuf_get_at(p, 1);

    // Check the result
    if (ip_addr_cmp(addr, &state->ntp_server_address) && port == NTP_PORT && p->tot_len == NTP_MSG_LEN &&
        mode == 0x4 && stratum != 0) {
        uint8_t seconds_buf[4] = {0};
        pbuf_copy_partial(p, seconds_buf, sizeof(seconds_buf), 40);
        uint32_t seconds_since_1900 = seconds_buf[0] << 24 | seconds_buf[1] << 16 | seconds_buf[2] << 8 | seconds_buf[3];
        uint32_t seconds_since_1970 = seconds_since_1900 - NTP_DELTA;
        time_t epoch = seconds_since_1970;
        ntp_result(state, 0, &epoch);
    } else {
        printf("invalid ntp response\n");
        ntp_result(state, -1, NULL);
    }
    pbuf_free(p);
}

// Perform initialisation
static NTP_T* ntp_init(void) {
    NTP_T *state = calloc(1, sizeof(NTP_T));
    if (!state) {
        printf("failed to allocate state\n");
        return NULL;
    }
    state->ntp_pcb = udp_new_ip_type(IPADDR_TYPE_ANY);
    if (!state->ntp_pcb) {
        printf("failed to create pcb\n");
        free(state);
        return NULL;
    }
    udp_recv(state->ntp_pcb, ntp_recv, state);
    return state;
}

// Runs ntp test forever
void run_ntp_test(void) {
    NTP_T *state = ntp_init();
    if (!state)
        return;
    while(true) {
        if (absolute_time_diff_us(get_absolute_time(), state->ntp_test_time) < 0 && !state->dns_request_sent) {
            // Set alarm in case udp requests are lost
            state->ntp_resend_alarm = add_alarm_in_ms(NTP_RESEND_TIME, ntp_failed_handler, state, true);

            // cyw43_arch_lwip_begin/end should be used around calls into lwIP to ensure correct locking.
            // You can omit them if you are in a callback from lwIP. Note that when using pico_cyw_arch_poll
            // these calls are a no-op and can be omitted, but it is a good practice to use them in
            // case you switch the cyw43_arch type later.
            cyw43_arch_lwip_begin();
            int err = dns_gethostbyname(NTP_SERVER, &state->ntp_server_address, ntp_dns_found, state);
            cyw43_arch_lwip_end();

            state->dns_request_sent = true;
            if (err == ERR_OK) {
                ntp_request(state); // Cached result
            } else if (err != ERR_INPROGRESS) { // ERR_INPROGRESS means expect a callback
                printf("dns request failed\n");
                ntp_result(state, -1, NULL);
            }
        }
#if PICO_CYW43_ARCH_POLL
        // if you are using pico_cyw43_arch_poll, then you must poll periodically from your
        // main loop (not from a timer interrupt) to check for Wi-Fi driver or lwIP work that needs to be done.
        cyw43_arch_poll();
        // you can poll as often as you like, however if you have nothing else to do you can
        // choose to sleep until either a specified time, or cyw43_arch_poll() has work to do:
        cyw43_arch_wait_for_work_until(state->dns_request_sent ? at_the_end_of_time : state->ntp_test_time);
#else
        // if you are not using pico_cyw43_arch_poll, then WiFI driver and lwIP work
        // is done via interrupt in the background. This sleep is just an example of some (blocking)
        // work you might be doing.
        //sleep_ms(1000);
        busy_wait_ms(1000);
#endif
    }
    free(state);
}

int main() {

    int connected_flag = 0;

    stdio_init_all();


    // Wait 5 seconds to leave me time to open putty
    busy_wait_ms(5000);

 
    // Set environment variable timezone TZ
    //  if(setenv("TZ", "CET-1CEST,M3.5.0,M10.5.0/3", 1) == -1)
    // note : TZ will automatically used when calling localtime() function
    if(setenv("TZ", TIME_ZONE, 1) == -1) 
         printf("Unable to initialize TZ");
    printf("TZ=%s\n", getenv("TZ"));

    // intitialize real time clock which will used to maintain date and time
    rtc_init();

    //general init
    if (cyw43_arch_init()) {
        printf("failed to initialise\n");
        return 1;
    }

    // intialize GPIO_DCF77 and set it as output
    gpio_init(GPIO_DCF77);
    gpio_set_dir(GPIO_DCF77, GPIO_OUT);
 
    cyw43_arch_enable_sta_mode();

    //connect to local wifi network
    while(!connected_flag)
        if (cyw43_arch_wifi_connect_timeout_ms(WIFI_SSID, WIFI_PASSWORD, CYW43_AUTH_WPA2_AES_PSK, 10000)) {
            printf("failed to connect\n");
    //        return 1;
        }
        else {
            printf("successfully connected\n");
            connected_flag = 1;
        }
    
  
    run_ntp_test();
    cyw43_arch_deinit();
   return 0;
}
