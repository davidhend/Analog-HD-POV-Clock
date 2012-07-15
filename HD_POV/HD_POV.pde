/**
 hdpov.c - Arduino driver for Hard Drive POV
 Copyright (C) 2008  Giles F. Hall 

 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation, version 2;

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
**/

/**
 ** Author: Giles F. Hall 
 ** Email: <ghall -at- csh (dot) rit (dot) edu>
 **/

#ifndef F_CPU
#define F_CPU           16000000UL  // 16 MHz
#endif

#include                <stdlib.h>
#include                <avr/io.h>
#include                <avr/interrupt.h>
#include                <util/delay.h>
#include                <Wire.h>
#include                "Chronodot.h"

// arduino redefines int, which bugs out stdio.h (needed for sscanf)
// see: http://www.arduino.cc/cgi-bin/yabb2/YaBB.pl?num=1207028702/3
#undef int
#include                <stdio.h>

byte incomingByte;
int ser_hour,ser_minute,ser_second;

int r1 = 1;
int g1 = 0;
int b1 = 1;
int background;

// The number of "pie slices" that make up a single image around the platter
#define DIVISIONS       0xFF

// Red pin, on PORTD
#define RED             3

// Green Pin, on PORTD
#define GRN             4

// Blue pin, on PORTD
#define BLU             5

// Macro used to communicate serial status
#define OK              1

// Number of pages in frame buffer
#define PAGES           2

// Helper macro to build LED values for PORTD
#define RGB(R,G,B)      (R << RED | G << GRN | B << BLU)

// The timers are configured with the prescaler set to 8, which means every
// 8 clock cycles equals on tick on the counter.  This is a constant to help
// convert timer cycles back to real time.
#define FREQ_DIV_8      (F_CPU / 8)

// Defines how many ticks a millisecond equals on our clock
#define MILLITICK       (FREQ_DIV_8 * .001)

// I have found that the sensor in my rig is prone to triggering the interrupt
// immediately after a real signal, likely related to capactive effects.  This
// tricks the system into thinking the platter is suddenly traveling a lot
// faster, and can cause visible glitches.  A 15K RPM drive spins 250 times a
// second, where a single revolution requires 4ms.  4ms is exactly 8000 timer
// cycles on our timer, which means anything half of 8000 is going faster than
// any known HD.  If such a value is captured, it is ignored.
#define SPURIOUS_INT    (2 * MILLITICK)

// Helper macros for frobbing bits
#define bitset(var,bitno) ((var) |= (1 << (bitno)))
#define bitclr(var,bitno) ((var) &= ~(1 << (bitno)))
#define bittst(var,bitno) (var& (1 << (bitno)))

// It is technically possible to change the number of divisions, even
// though this is not currently implemented.  This const serves as a place
// holder for future enhancements.
const unsigned char divisions = DIVISIONS;

// The current slice being drawn
volatile unsigned char current_slice;

// The period of the platter in timer ticks
int period;

// The value of the hidden page
volatile int page_hidden;

// The value of the visible page
volatile int page_visible;

// A flag representing the need for the pages to be flipped
volatile unsigned char page_flip_flag;

// The double buffered frame buffer
unsigned char FrameBuffer[PAGES][DIVISIONS];

/**
 ** FrameBuffer / Page routines
 ** 
 ** The framebuffer is double buffered, which allows you to write updates
 ** to the "hidden" page while the code draws from the "visible" page.
 **
 ** page_flip() makes the hidden page the visible page, and vice-versa.
 **
 ** copy_page() allows you to copy the visible page back to the hidden page, 
 ** so you don't have to redraw the entire frame if you are just making a 
 ** small change.  
 **
 ** clear_page() clears the hidden page.
 **
 ** write_page() writes to the hidden page.
 ** 
 ** See RunStartupDisplay() for a simple example.
 **/

// sit and wait for the page to be flipped
void __inline__ wait_for_page_flip(void)
{
    while (page_flip_flag) {}
}

// request a page flip, and wait for the sensor interrupt to flip the page
void __inline__ flip_page(void)
{
    page_flip_flag = 1;
    wait_for_page_flip();
}

// copy the visible page to the hidden page
void __inline__ copy_page(void)
{
    int x;
    for(x = 0; x < divisions; x++)
    {
        FrameBuffer[page_hidden][x] = FrameBuffer[page_visible][x];
    }
}

// write a value to the hidden page
void __inline__ write_page(unsigned char slice, unsigned char val)
{
    FrameBuffer[page_hidden][slice] = val;
}

// clear the hidden page
void clear_page(void)
{
    int x;
    for(x = 0; x < divisions; x += 1)
    {
        FrameBuffer[page_hidden][x] = 0;
    }
}

// called by the interrupt to flip to the next page
void __inline__ flip_to_next_page(void)
{
    if (page_flip_flag)
    {
        page_visible = page_hidden;
        page_hidden = !page_hidden;
        page_flip_flag = 0;
    }
}


/**
 ** Setup
 **/

// Simple test pattern displaying all the available colors, evenly spaced
void InitTestPattern1(void)
{
  int x;
  for(x = 0; x < divisions; x++)
  {
      switch (x / (divisions / 8))
      {
        case 0:
          write_page(x, RGB(0,0,0));
          break;  
        case 1:
          write_page(x, RGB(1,0,0));
          break;
        case 2:
          write_page(x, RGB(0,1,0));
          break;
        case 3:
          write_page(x, RGB(0,0,1));
          break;
        case 4:
          write_page(x, RGB(1,1,0));
          break;  
        case 5:
          write_page(x, RGB(1,0,1));
          break;  
        case 6:
          write_page(x, RGB(0,1,1));
          break;  
        case 7:
        default:
          write_page(x, RGB(1,1,1));
          break;
      }
    }
}

// Simple test pattern displaying all the available drawable slices.
void InitTestPattern2(void)
{
  int x;
  for(x = 0; x < divisions; x++)
  {
      switch (x % 8)
      {
        case 0:
          write_page(x, RGB(0,0,0));
          break;  
        case 1:
          write_page(x, RGB(1,0,0));
          break;
        case 2:
          write_page(x, RGB(0,1,0));
          break;
        case 3:
          write_page(x, RGB(0,0,1));
          break;
        case 4:
          write_page(x, RGB(1,1,0));
          break;  
        case 5:
          write_page(x, RGB(1,0,1));
          break;  
        case 6:
          write_page(x, RGB(0,1,1));
          break;  
        case 7:
          write_page(x, RGB(1,1,1));
          break;
      }
    }
}

Chronodot RTC;
void chronotime(void){
  int h; int m; int s; int hour; int minute; int second; 
  
  DateTime now = RTC.now();
  
  h = now.hour();
  m = now.minute();
  s = now.second();
  
  if (h >= 12){
    h = h - 12; 
  }

  //Serial.println(h);

  hour = (DIVISIONS * (h / 12.0) + (DIVISIONS / 12.0) * (m / 60.0));
  minute = (DIVISIONS * (m / 60.0));
  second = (DIVISIONS * (s / 60.0));
  
  clear_page();
  
  int n;
  for (n = 0; n < DIVISIONS; n++){
    if (n == hour){
      write_page(n-5, RGB(1,0,0));
      write_page(n-4, RGB(1,0,0));
      write_page(n-3, RGB(1,0,0));
      write_page(n-2, RGB(1,0,0));
      write_page(n-1,RGB(1,0,0));   
      write_page(n, RGB(1,0,0));
      write_page(n+1, RGB(1,0,0));
      write_page(n+2, RGB(1,0,0));
      write_page(n+3, RGB(1,0,0));
      write_page(n+4, RGB(1,0,0));
      write_page(n+5, RGB(1,0,0));
} 
    if (n == minute){
      write_page(n-5, RGB(0,1,0));
      write_page(n-4, RGB(0,1,0));
      write_page(n-3, RGB(0,1,0));
      write_page(n-2, RGB(0,1,0));
      write_page(n-1,RGB(0,1,0));   
      write_page(n, RGB(0,1,0));
      write_page(n+1, RGB(0,1,0));
      write_page(n+2, RGB(0,1,0));
      write_page(n+3, RGB(0,1,0));
      write_page(n+4, RGB(0,1,0));
      write_page(n+5, RGB(0,1,0));
    }
    if (n == second){
      write_page(n-5, RGB(0,0,1));
      write_page(n-4, RGB(0,0,1));
      write_page(n-3, RGB(0,0,1));
      write_page(n-2, RGB(0,0,1));
      write_page(n-1,RGB(0,0,1));   
      write_page(n, RGB(0,0,1));
      write_page(n+1, RGB(0,0,1));
      write_page(n+2, RGB(0,0,1));
      write_page(n+3, RGB(0,0,1));
      write_page(n+4, RGB(0,0,1));
      write_page(n+5, RGB(0,0,1));

    } 
  
    int div = (DIVISIONS / 12.0);
    
    for (int x =0; x < 12; x++){
       int slice = int(x * div);
       write_page(slice, RGB(0,1,1)); 
    }
    
  
    if ( n != hour && n != minute && n != second){
      write_page(n, RGB(r1,g1,b1)); 
    }
  }
  flip_page();
  copy_page();
}

void tempature(void)
{

 DateTime now = RTC.now();
 
 int temp;
 temp = now.tempF();
 
 clear_page();
 
 int k;
 for (k =0; k < temp; k++){
  if (k < 25){
   write_page(k, RGB(0,0,1));
  } 
  if (k > 25 && k < 50){
   write_page(k, RGB(0,1,0));
  } 
  if (k > 50 && k < 75){
   write_page(k, RGB(1,1,0));
  } 
  if (k > 75 && k < 100){
   write_page(k, RGB(1,0,0)); 
  }
  if (k > 100  && k < 125){
    write_page(k, RGB(1,0,1));
  }
   
 }
 flip_page();
 copy_page();
  
}


// Go through all pages of the frame buffer, and set them to 0
void init_pages(void)
{
    int page;
    int x;
    for(page = 0; page < PAGES; page += 1)
    {
        for(x = 0; x < divisions; x += 1)
        {
            FrameBuffer[page][x] = 0;
        }
    }
    page_hidden = 0;
    page_flip_flag = 0;
}

// Configure the Serial Port, LED Pins, Timers, and Hardware Interrupt
void SetupHardware(void)
{
  // setup serial
  Serial.begin(9600);

  Wire.begin(9600);
  Serial.println("Initializing Chronodot.");
  RTC.begin();
  
  if (! RTC.isrunning()) {
    Serial.println("RTC is NOT running.");
    RTC.adjust(DateTime(__DATE__,__TIME__));
  }

  //RTC.adjust(DateTime(__DATE__,__TIME__));  //Un-comment to set time to comile time then re-commentf

  Serial.print("[");
  // setup output
  pinMode(RED, OUTPUT);
  pinMode(GRN, OUTPUT);
  pinMode(BLU, OUTPUT);
  Serial.print("L");

  // disable global interrupts
  cli();

  // setup timer0 - 8bit
  // resonsible for timing the LEDs
  TCCR0A = 0;
  TCCR0B = 0;  
  // select CTC mode
  bitset(TCCR0A, WGM01);
  // select prescaler clk / 8
  bitset(TCCR0B, CS01);
  // enable compare interrupt
  bitset(TIMSK0, OCIE0A);
  Serial.print("0");
  
  // setup timer1 - 16bit
  // responsible for timing the rotation of the platter
  TCCR1B = 0;
  TCCR1A = 0;
  // select prescaler clk / 8
  bitset(TCCR1B, CS11);
  // reset timer
  TCNT1 = 0;
  // enable overflow interrupt
  bitset(TIMSK1, TOIE1);
  Serial.print("1");

  // configure the platter interrupt PIN
  // int0, on any change
  EICRA = _BV(ISC00);
  //EICRA = _BV(ISC01);
  // Enable the hardware interrupt.
  EIMSK |= _BV(INT0);
  Serial.print("G");

  // set the rotational period to 0
  period = 0;
  
  // init pages
  init_pages();

  // enable global interrupts
  sei();

  Serial.println("]");
  Serial.flush();
}


/**
 ** Serial Output
 **/

// Report the status of the system, plus important variables over the serial
// port
void report_status_to_serial(void)
{
  unsigned int rpm = 0;
  if (period)
  {
      rpm = (int)(((float)FREQ_DIV_8) / ((float)period) * 60.0);
  }
  Serial.print("Revolutions / Minute: ");
  Serial.println(rpm, DEC);
  Serial.print("Ticks / Revolution: ");
  Serial.println(period, DEC);
  Serial.print("OCR0A: ");
  Serial.println(OCR0A, DEC);
  Serial.print("Divisons: ");
  Serial.println(divisions, DEC);
  Serial.print("Current Page: ");
  Serial.println((!(page_hidden)), DEC);
  Serial.print("Red: 0x");
  Serial.println(_BV(RED), HEX);
  Serial.print("Green: 0x");
  Serial.println(_BV(GRN), HEX);
  Serial.print("Blue: 0x");
  Serial.println(_BV(BLU), HEX);
}

// Read the entire visible page to the serial port, printing
// each byte as a hexadecimal character
void read_page_to_serial(int page)
{
    int slice;

    for(slice = 0; slice < divisions; slice++)
    {
        Serial.print("0x");
        Serial.println(FrameBuffer[page][slice], HEX);
        Serial.flush();
    }
}

/**
 ** Serial Input
 **/

// Sit and spin until there is serial data available
void __inline__ wait_for_serial_input()
{
    while (Serial.available() < 1) {}
}

// read a single byte from the serial port, encoded in hex
int read_byte(void)
{
    int ret;
    char rstr[2];

    wait_for_serial_input();
    rstr[0] = Serial.read();
    wait_for_serial_input();
    rstr[1] = Serial.read();
    sscanf(rstr, "%x", &ret);
    return ret;
}

// read an entire page from the serial port and write it to the framebuffer
int write_page_from_serial(void)
{
    int val;
    int slice;
    int retval = OK;

    for(slice = 0; slice < divisions; slice++)
    {
        val = read_byte();
        write_page(slice, val);
    }

    return retval;
}

/**
 ** Setup
 **/

// Simple animation to demonstrate the system is working
void RunStartupDisplay(void)
{
    int color;
    int slice;

    clear_page();
    flip_page();

    for (color = 0; color < 4; color++)
    {
        for (slice = 0; slice < divisions; slice += 2)
        {
            switch(color)
            {
                case 0:
                    /* red */
                    write_page(slice, _BV(RED));
                    write_page(slice+1, _BV(RED));
                    break;
                case 1:
                    /* green */
                    write_page(slice, _BV(GRN));
                    write_page(slice+1, _BV(GRN));
                    break;
                case 2:
                    /* blue */
                    write_page(slice, _BV(BLU));
                    write_page(slice+1, _BV(BLU));
                    break;
                case 3:
                    /* black */
                    write_page(slice, 0);
                    write_page(slice+1, 0);
                    break;
            }
            flip_page();
            copy_page();
        }
    }

    clear_page();
    flip_page();
}

void set_time()
{
   Wire.beginTransmission(104);
   Wire.send(0);
   Wire.send(decToBcd(ser_second));
   Wire.send(decToBcd(ser_minute));
   Wire.send(decToBcd(ser_hour));
   Wire.endTransmission();
}

byte decToBcd(byte val)
{
  return ( (val/10*16) + (val%10) );
}

byte bcdToDec(byte val)
{
  return ( (val/16*10) + (val%16) );
}

// Top level setup, called by the Arduino core
void setup(void)
{
    SetupHardware();
    RunStartupDisplay();
}

/**
 ** Main Loop
 **/

// Top level loop, call by the Arduino core
void loop(void)
{
    int cmd;
    int slice, value;
    int okval = OK;
    int i; int j;
    
    if (Serial.available()) {
    incomingByte = Serial.read();
    Serial.print(int(incomingByte));
    

    if ((int(incomingByte) == 240)) {
      background = Serial.read();
      r1 = 0; g1 = 1; b1 = 1;
         
    }

    if ((int(incomingByte) == 241)) {
      background = Serial.read();
      r1 = 1; g1 = 1; b1 = 0;
    }

    if ((int(incomingByte) == 242)) {
      background = Serial.read();
      r1 = 1; g1 = 0; b1 = 1;
    }

    if ((int(incomingByte) == 252)) {
      ser_hour = Serial.read();
      Serial.println("Set hour: ");
      Serial.println(ser_hour);
      // following line sets the RTC time
      set_time();
    }
    
    if ((int(incomingByte) == 253)) {
      ser_minute = Serial.read();
      Serial.println("Set minute: ");
      Serial.println(ser_minute);
      // following line sets the RTC time
      set_time();
    }    
    
    if ((int(incomingByte) == 254)) {
      ser_second = Serial.read();
      Serial.println("Set second: ");
      Serial.println(ser_second);
      // following line sets the RTC time
      set_time();
    }
    
    if ((int(incomingByte) == 255)) {
      for (j =0; j < 360; j++)
      {
       tempature(); 
      }
    }

  }else{
      chronotime();
   }
  
 }

/**
 ** Interrupts
 **
 ** The interrupts provide the accurate timing needed for this project.
 ** 
 **/

// This interrupt is called on every pulse of the sensor, which represents
// one full rotation of the platter.  It is responsible for timing the
// revolution, and for initiating the first draw instance.
ISR(INT0_vect)
{
  // Capture the 16bit count on timer1, this represents one revolution
  period = TCNT1;
  // If the period is shorter than our threshold, don't do anything
  if(period < SPURIOUS_INT)
  {
    return;
  }
  // Reset timer1 so it can clock the next revolution
  TCNT1 = 0;
  // Reset timer0 so it can start to accurately paint the slot 
  TCNT0 = 0;
  // If there is a page flip request, flip to the next page
  flip_to_next_page();
  // Write out the first slice to the LEDs to PORTD
  PORTD = FrameBuffer[page_visible][0];
  // Divide the time of single platter rotation by the number of drawable
  // divisions
  OCR0A = (period / divisions);
  // Set our current slice to 1, since we just drew slice 0
  current_slice = 1;
}

// This interrupt is called every time timer0 counts up to the 8bit value
// stored in the register "ORC0A", which is configured in INT0 interrupt.
// It is responsible for drawing out all the slices of the frame buffer
// during the exact moment the slot is in its proper rotational position.
// Using a 7200RPM drive with 255 divisions, this interrupt is called 
// 31,200 times a second.
ISR(TIMER0_COMPA_vect) {
  // Write out the LED value to the Frame Buffer
  PORTD = FrameBuffer[page_visible][current_slice];
  // Increment current slice, making sure to wrap it if it
  // has accidently gotten too large
  current_slice = ((current_slice + 1) % divisions);
}

// If the platter spin time overflows timer1, this is called
ISR(TIMER1_OVF_vect) {
}
