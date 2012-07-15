#include "Servo.h"

Servo myservo;

int val;
int analogpin = 3; //Potentiometer on pin 3
int servoPin =9; //ESC on pin 9
int armValue = 20; //"Zero Position" for arming ESC. As some wont arm with a "0" value from arduino
void arm()
{
  myservo.write(armValue); //Arming sequence sending a minimum or "joystick 0" for 2 seconds to simulate radio gear on
  delay(6000);  //Delay for ESC to activate (may need to change)
}

void setup() 
{
  Serial.begin(9600);
  myservo.attach(servoPin);
  arm();
}

void loop()
{
  int val = analogRead(analogpin); //Read potentiometer value
  val = map(val, 0, 1023, armValue, 180); //Map potentiometer value to servo position
  myservo.write(val); //Send servo value to ESC
  Serial.println(val); //Print value to Serial
  delay(100);
}
