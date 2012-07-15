// Paint application - Demonstrate both TFT and Touch Screen

#include <stdint.h>
#include <TouchScreen.h>
#include <TFT.h>

//Measured ADC values for (0,0) and (210-1,320-1)
//TS_MINX corresponds to ADC value when X = 0
//TS_MINY corresponds to ADC value when Y = 0
//TS_MAXX corresponds to ADC value when X = 240 -1
//TS_MAXY corresponds to ADC value when Y = 320 -1

static unsigned int TS_MINX, TS_MAXX, TS_MINY, TS_MAXY;

//Touch Screen Co-ordinate mapping register
static unsigned int MapX1, MapX2, MapY1, MapY2;

// For better pressure precision, we need to know the resistance
// between X+ and X- Use any multimeter to read it
// The 2.8" TFT Touch shield has 300 ohms across the X plate

/* Usage: TouchScreen ts = TouchScreen(XP, YP, XM, YM, 300); 
   Where, XP = X plus, YP = Y plus, XM = X minus and YM = Y minus */
//init TouchScreen port pins. This would be reinitialized in setup() based on the hardware detected.
TouchScreen ts = TouchScreen(17, A2, A1, 14, 300); 

int color = WHITE;  //Default Paint brush color

int hour = 10;
int minute = 10;
int second = 10;
char ascii_hour[32];
char ascii_minute[32];
char ascii_second[32];

void setup()
{
  Serial.begin(9600);
  
    Tft.init();  //init TFT library
    initTouchScreenParameters(); // initializes Touch Screen parameters based on the detected TFT Touch Schield hardware

   // Serial.begin(9600); //debug

 itoa((int)hour,ascii_hour,10); 

 Tft.drawString("Hour  Minute Second",30,10,1,WHITE);

 //Hour Rectangle 
 Tft.drawRectangle(25, 40, 45, 50,BLUE);
 //Hour + rectangle
 Tft.fillRectangle(35, 20, 22, 20, RED);
 //Hour + symbol
 Tft.drawChar('+',39,24,2,WHITE);
 //Hour

 //Hour - Rectabngle
 Tft.fillRectangle(35, 90, 22, 20, CYAN); 
 //Hour - Symbol
 Tft.drawChar('-',39,94,2,WHITE);


 //Minute Rectangle
 Tft.drawRectangle(80,40, 45, 50, BLUE);
 //Minute + rectangle
 Tft.fillRectangle(90, 20, 22, 20, RED);
 //Minute + symbol
 Tft.drawChar('+',94,24,2,WHITE);
 //Minute

  //Minute - Rectabngle
 Tft.fillRectangle(90, 90, 22, 20, CYAN); 
 //Minute - Symbol
  
 //Minute - Rectabngle
 Tft.fillRectangle(90, 90, 22, 20, CYAN); 
 //Hour - Symbol
 Tft.drawChar('-',94,94,2,WHITE);


 //Second Rectangle
 Tft.drawRectangle(135,40, 45, 50, BLUE);
 //Second + rectangle
 Tft.fillRectangle(145, 20, 22, 20, RED);
 //Second + symbol
 Tft.drawChar('+',149,24,2,WHITE);
 //Second

 //Second - Rectabngle
 Tft.fillRectangle(145, 90, 22, 20, CYAN); 
 //Second - Symbol
 Tft.drawChar('-',149,94,2,WHITE);
 
 //Set Time Box
 Tft.fillRectangle(115,130,80,20, BLUE);
 Tft.drawString("Set Time",125,135,1,WHITE);

 //Tempature Box
 Tft.fillRectangle(20,130,80,20, BLUE);
 Tft.drawString("Tempature",21,135,1,WHITE);

 //Background Color Pallete
 Tft.drawString("Background Color Pallete", 25, 170, 1, WHITE);
 //Tft.fillRectangle(20,160,20,20, MAG);
 Tft.fillRectangle(40,190,20,20, CYAN); 
 Tft.fillRectangle(80,190,20,20, YELLOW);
 Tft.fillRectangle(120,190,20,20,BRIGHT_RED);//Magenta

}

void loop()
{

 
  if(hour > 12){
    Tft.fillRectangle(26,41,44,49,BLACK);
    hour = 1;
  }
  if(minute >= 60){
    Tft.fillRectangle(81,41,44,49,BLACK);
    minute = 1;
  }
  if(second >= 60){
    Tft.fillRectangle(136,41,44,49,BLACK);
    second = 1;
  }
  
  if (hour < 0){
    Tft.fillRectangle(26,41,44,49,BLACK);
    hour = 12;
  }
  if (minute < 0){
    Tft.fillRectangle(81,41,44,49,BLACK);
    minute = 59;
  }
  if (second < 0){
    Tft.fillRectangle(136,41,44,49,BLACK);
    second = 59;
   }
  
  
  // Serial.println(Tft.IC_CODE,HEX); //debug

    // a point object holds x y and z coordinates.
    Point p = ts.getPoint();

    // we have some minimum pressure we consider 'valid'
    // pressure of 0 means no pressing!

    if (p.z > ts.pressureThreshhold) {

    //map the ADC value read to into pixel co-ordinates

    p.x = map(p.x, TS_MINX, TS_MAXX, MapX1, MapX2);
    p.y = map(p.y, TS_MINY, TS_MAXY, MapY1, MapY2);


    if(p.x >= 35 && p.x < 57 && p.y >= 20 && p.y < 40)
    {
      hour = hour + 1;
      Tft.fillRectangle(26,41,44,49,BLACK);
      delay(50);
  }
    
    if(p.x >= 35 && p.x < 57 && p.y >= 90 && p.y < 110)
    {
      hour = hour - 1;
      Tft.fillRectangle(26,41,44,49,BLACK);
      delay(50);
    }    

    if(p.x >= 90 && p.x < 112 && p.y >= 20 && p.y < 40)
    {
      minute = minute + 1;
      Tft.fillRectangle(81,41,44,49,BLACK);
      delay(50);
    }
    
    if(p.x >= 90 && p.x < 112 && p.y >= 90 && p.y < 110)
    {
      minute = minute - 1;
      Tft.fillRectangle(81,41,44,49,BLACK);
      delay(50);
    }    

    if(p.x >= 145 && p.x < 167 && p.y >= 20 && p.y < 40)
    {
      second = second + 1;
      Tft.fillRectangle(136,41,44,49,BLACK);
      delay(50);
    }
    
    if(p.x >= 145 && p.x < 167 && p.y >= 90 && p.y < 110)
    {
      second = second - 1;
      Tft.fillRectangle(136,41,44,49,BLACK);
      delay(50);
    }    

    if(p.x >= 115 && p.x < 195 && p.y >= 130 && p.y < 150)
    {
      Tft.fillRectangle(10,245,60,40,BLACK);
      Serial.print(252, BYTE); //Sync byte
      Serial.print(hour, BYTE);
      Serial.print(253, BYTE); //Sync byte
      Serial.print(minute, BYTE);
      Serial.print(254, BYTE); //Sync byte     
      Serial.print(second, BYTE);
      delay(150);      
      Tft.drawString("Time Set To:",10,250,1,WHITE);
      Tft.drawString(ascii_hour,10,265,1,WHITE);
      Tft.drawString(":",25,265,1,WHITE);
      Tft.drawString(ascii_minute,30,265,1,WHITE);
      Tft.drawString(":",45,265,1,WHITE);
      Tft.drawString(ascii_second,50,265,1,WHITE);
      
    }    

    if(p.x >= 20 && p.x < 130 && p.y >= 100 && p.y < 150)
    {
      Serial.print(255, BYTE); //Sync byte     
      delay(50);
    }

    if(p.x >= 40 && p.x < 60 && p.y >= 190 && p.y < 210)
    {
      //Cyan Background Color Swap
      Serial.print(240, BYTE); //Command byte
      delay(50);
    }
  
    if(p.x >= 80 && p.x < 100 && p.y >= 190 && p.y < 210)
    {
      //Yellow Background Color Swap
      Serial.print(241, BYTE); //Command byte 
      delay(50);    
    }
    
    if(p.x >= 120 && p.x < 140 && p.y >= 190 && p.y < 210)
    {
      //Magenta Background Color Swap
      Serial.print(242, BYTE); //Command byte
      delay(50);    
    }
    
    
    }

 itoa((int)hour,ascii_hour,10);
 itoa((int)minute,ascii_minute,10);
 itoa((int)second,ascii_second,10);
 

 Tft.drawString(ascii_hour,35,60,2,WHITE);
 Tft.drawString(ascii_minute,90,60,2,WHITE);
 Tft.drawString(ascii_second,145,60,2,WHITE);

}

void initTouchScreenParameters()
{
    //This function initializes Touch Screen parameters based on the detected TFT Touch Schield hardware

    if(Tft.IC_CODE == 0x5408) //SPFD5408A TFT driver based Touchscreen hardware detected
    {
#if defined(__AVR_ATmega1280__) || defined(__AVR_ATmega2560__)
        ts = TouchScreen(54, A1, A2, 57, 300); //init TouchScreen port pins
#else 
        ts = TouchScreen(14, A1, A2, 17, 300); //init TouchScreen port pins
#endif
        //Touchscreen parameters for this hardware
        TS_MINX = 120;
        TS_MAXX = 910;
        TS_MINY = 120;
        TS_MAXY = 950;

        MapX1 = 239;
        MapX2 = 0;
        MapY1 = 0;
        MapY2 = 319;
    }
    else //ST7781R TFT driver based Touchscreen hardware detected
    {
#if defined(__AVR_ATmega1280__) || defined(__AVR_ATmega2560__)
        ts = TouchScreen(57, A2, A1, 54, 300); //init TouchScreen port pins
#else 
        ts = TouchScreen(17, A2, A1, 14, 300); //init TouchScreen port pins
#endif 

        //Touchscreen parameters for this hardware
        TS_MINX = 140;
        TS_MAXX = 900;
        TS_MINY = 120;
        TS_MAXY = 940;

        MapX1 = 239;
        MapX2 = 0;
        MapY1 = 319;
        MapY2 = 0;
    }
}
