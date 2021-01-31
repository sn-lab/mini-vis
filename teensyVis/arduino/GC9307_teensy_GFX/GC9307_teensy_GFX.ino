#include <Adafruit_GFX.h>    // Core graphics library from Adafruit, slightly modified
#include "Adafruit_GC9307.h" // Driver for GC9307-based display (modified from Adafruit_ST7789)
#include <SPI.h>             // SPI library for communication to the display
#include <EEPROM.h>          // EEPROM library (for seldom-used on-board data storage)
#include "logo_bitmap.h"     // hex bitmap of Cornell Engineering and SN-lab logos

#define TFT_CS  10 // chip-select pin
#define TFT_RST 14 // reset pin
#define TFT_DC  6 // data/command pin
#define TRIG_OUT 0 // start-trigger output pin
#define TRIG_IN 1 //start-trigger input 

//initialize program basics
int width = 240; // width of display in pixels
int height = 210; // height of display in pixels
float pi = 3.14159;
int demoEPPA = 0; // eeprom address for stored demo byte
byte demo; // 1=run demo, 0=ignore demo

//initialize default pattern parameters
uint8_t commandID = 0;
uint8_t readDelay = 100; //duration (in ms) between checking for new incoming serial data
uint8_t centerPosition[2] = {0, 0}; //[x, y] center coordinate of pattern relative to display center
uint8_t numGratings = 2; //number of repeated dark/bright bars in grating
uint8_t barWidth = 40; //width of each dark/bright bar (in pixels) of grating
uint8_t colorBytes[3][3] = {{0, 0, 30},{0, 0, 0},{0, 0, 15}};
uint8_t angleBytes[2] = {0, 0}; //angle of pattern, separated into halves for 0-360 deg (1 byte only allows 0-255)
uint8_t temporalFrequencyDHz = 10; //speed of gratings/flickers (in deci-Hertz)
uint8_t patternType = 1; //1=square-wave grating, 2=sine-wave grating, 3=flicker
uint8_t preDelayDs = 0; //delay (in s) to wait after start command until pattern is drawn
uint8_t durationDs = 1; //duration (in deci-seconds) to draw pattern
float benchmarkHz; //maximum temporal frequency a pattern can be displayed (calculated later)
unsigned long numPatternsDisplayed = 0;
unsigned long startTime = 0;

//initialize other common variables
int i, r, c, e, startCommand = 0, wait4Trigger = 0;
byte * bytes4x;
unsigned long startMs, endMs, startUs, endUs;
float durUs;
uint16_t backgroundColor, prevBackgroundColor;
  
//instantiate display with driver for GC9307-based display
Adafruit_GC9307 tft = Adafruit_GC9307(TFT_CS, TFT_DC, TFT_RST);

void setup(void) {
  Serial.begin(9600);
  Serial.println(F("GC9307 Display Test"));
  tft.init(width, height); //initialize the display
  tft.setSPISpeed(96000000); //set this to be as fast as the display can handle
  Serial.println(F("Initialized"));
  
  //check EEPROM storage for demo byte, write 1 to it if it hasn't been set yet
  demo = EEPROM.read(demoEPPA);
  if (demo!=0 || demo!=1) {
    demo = 1;
    EEPROM.write(demoEPPA, demo);
    delay(10);
  }

  pinMode(TRIG_IN, INPUT);
  pinMode(TRIG_OUT, OUTPUT);
  digitalWrite(TRIG_OUT, LOW);
}

void loop() { //main program loop
  if (demo==1) {runDemo();} //self-explanatory, right?

  //wait for incoming instructions over serial connection
  wait4Serial(readDelay, 1); //wait for (at least) 1 available byte
  
  //read incoming command and data over serial
  commandID = readSerialMessage(); //read incoming message ID byte (specifies what data is coming next)
  if (commandID!=0) {
    switch (commandID) {
      case 101: //command to set all parameters
        wait4Serial(readDelay, 20); //wait for 20 available bytes
        
        readDelay = readSerialMessage(); //byte 1
        for (r=0;r<3;r++) {
          for (c=0;c<3;c++) {
            colorBytes[r][c] = readSerialMessage(); //bytes 2-10
          }
        }
        barWidth = readSerialMessage(); //byte 11
        numGratings = readSerialMessage(); //byte 12
        angleBytes[0] = readSerialMessage(); //byte 13
        angleBytes[1] = readSerialMessage(); //byte 14
        temporalFrequencyDHz = readSerialMessage(); //byte 15
        centerPosition[0] = readSerialMessage(); //byte 16
        centerPosition[1] = readSerialMessage(); //byte 17
        durationDs = readSerialMessage(); //byte 18 
        preDelayDs = readSerialMessage(); //byte 19
        patternType = readSerialMessage(); //byte 20

        //fill screen with background color, if changed
        backgroundColor = colorBytes[2][2]; //add blue value to lowest 5 bits
        backgroundColor = backgroundColor<<6; //shift blue over by 6 bits, leaving lower 6 bits empty now
        backgroundColor |= colorBytes[2][1]; //add green value to lowest 6 bits
        backgroundColor = backgroundColor<<5; //shift blue/green over by 5 bits, leaving lowest 5 empty
        backgroundColor |= colorBytes[2][0]; //add red value to lowest 5 bits
        if (backgroundColor!=prevBackgroundColor) {
          tft.fillScreen(backgroundColor);
          prevBackgroundColor = backgroundColor;
        }
        
      case 106: //start pattern
        startCommand = 1;
        break;  

      case 116: //start on input trigger
        startCommand = 1;
        wait4Trigger = 1;
        break;
        
      case 126: //demo on
        demo = 1;
        if (demo!=EEPROM.read(demoEPPA)) {
          EEPROM.write(demoEPPA, demo);
          delay(10);
        }
        break;

      case 127: //demo off
        demo = 0;
        if (demo!=EEPROM.read(demoEPPA)) {
          EEPROM.write(demoEPPA, demo);
          delay(10);
        }
        break;
        
      default: //give error message if command ID not recognized
        Serial.write(225); //ID that command was not recognized
        Serial.write(commandID);
        break;
    }
  }
  //display pattern (if start command was received)
  if (startCommand==1) {
    //display pattern
    startTime = millis();
    drawPattern(patternType, centerPosition, numGratings, barWidth, angleBytes, temporalFrequencyDHz, colorBytes, preDelayDs, durationDs, wait4Trigger, startTime, benchmarkHz);
    
    //send data about previously displayed pattern back over serial
    numPatternsDisplayed++;
    Serial.write(201); //byte 1: host-side command ID for incoming data
    serialWriteLong(numPatternsDisplayed); //bytes 2-5: number of patterns displayed so far
    serialWriteLong(startTime); //bytes 6-9: pattern start timestamp
    Serial.write(readDelay); //byte 10
    for (r=0;r<3;r++) {
      for (c=0;c<3;c++) {
        Serial.write(colorBytes[r][c]); //bytes 11-19
      }
    }
    Serial.write(barWidth); //byte 20
    Serial.write(numGratings); //byte 21
    Serial.write(angleBytes,2); //bytes 22-23
    Serial.write(temporalFrequencyDHz); //byte 24
    Serial.write(centerPosition,2); //bytes 25-26
    Serial.write(durationDs); //byte 27
    Serial.write(preDelayDs); //byte 28
    Serial.write(patternType); //byte 29

    startCommand = 0; //reset startCommand to 0 to wait for next pattern
    wait4Trigger = 0; //reset wait-for-input-trigger option
  }
}


//wait for desired amount of available serial data bytes
void wait4Serial(uint8_t wait, int num2wait4) {
  int bytesavail = Serial.available();
  while (bytesavail<num2wait4) {
    delay(wait);
    bytesavail = Serial.available();
  }
}


//read serial message
uint8_t readSerialMessage() {
  int msg16 = Serial.read();
  uint8_t msg = 0;
  if (msg16!=-1) {
    msg = msg16;
  }
  return msg;
}

void serialWriteLong(unsigned long UL) {
  bytes4x = (byte *) &UL;
  Serial.write(bytes4x,4); //send 1 unsigned long as 4 bytes
}

void serialWriteFloat(float F) {
  bytes4x = (byte *) &F;
  Serial.write(bytes4x,4); //send 1 float as 4 bytes
}

float deg2rad(uint16_t deg) {
  return (deg*pi/180); //convert degrees to radians
}

void drawPattern(uint8_t type, uint8_t pos[2], uint8_t numrepeats, uint8_t barW, 
        uint8_t aBytes[2], uint8_t freq, uint8_t color[3][3], uint8_t pre, 
        uint8_t dur, int wait4Trig, unsigned long &startT, float &bmark) {
  //get location of every pixel (x0[],y0[]) which creates an 
  //orthogonally-connected line primitive closest to the "bottom line"
  //method: iterate by walking 1 pixel at a time, orthogonally only, first by 
  //using the direction with the greater overall change (dx or dy) then by 
  //minimizing the error to the true line. 
  
  int angle = aBytes[0] + aBytes[1];
  double radius = sqrt(2*sq(barW*numrepeats))-0.5;
  int blx = round(pos[0]+120.5+radius*cos(deg2rad((-angle+225+360)%360))); //bottom-left corner x-coord
  int tlx = round(pos[0]+120.5+radius*cos(deg2rad((-angle+135+360)%360))); //top-left corner x-coord
  int brx = round(pos[0]+120.5+radius*cos(deg2rad((-angle+315+360)%360))); //bottom-right corner x-coord

  int bly = round(pos[1]+90.5+radius*sin(deg2rad((-angle+225+360)%360))); //bottom-left corner y-coord
  int tly = round(pos[1]+90.5+radius*sin(deg2rad((-angle+135+360)%360))); //top-left corner y-coord
  int bry = round(pos[1]+90.5+radius*sin(deg2rad((-angle+315+360)%360))); //bottom-right corner y-coord

  int primary[500], secondary[500], x0[500], x1[500], y0[500], y1[500];
  int primaryDelta, secondaryDelta;
  int Lidx, Cidx;
  int dx = brx-blx;
  int dy = bry-bly;
  if (abs(dx)>abs(dy)) {
    primary[0] = blx;
    secondary[0] = bly;
    primaryDelta = dx;
    secondaryDelta = dy;
  } else {
    primary[0] = bly;
    secondary[0] = blx;
    primaryDelta = dy;
    secondaryDelta = dx;
  }
  int primaryDirection = round(primaryDelta/(abs(primaryDelta)+0.0001));
  int secondaryDirection = round(secondaryDelta/(abs(secondaryDelta)+0.0001));
  float slope = abs(float(secondaryDelta)/float(primaryDelta)); //1 if equal, 0 if none
  int numLines = 1;
  int numSecondaryLines = 0;
  for (i=1;i<=abs(primaryDelta);i++) {
    //add next pixel by moving the primary direction
    primary[numLines] = primary[numLines-1] + primaryDirection;
    secondary[numLines] = secondary[numLines-1];
    numLines++;
    
    //check for additional pixel to add in the secondary direction
    if ((round(slope*i)-numSecondaryLines)==1) {
      primary[numLines] = primary[numLines-1];
      secondary[numLines] = secondary[numLines-1] + secondaryDirection;
      numLines++;
      numSecondaryLines++;
    }
  }
  
  int txDelta = tlx-blx;
  int tyDelta = tly-bly;
  for (i=0; i<numLines; i++) {
    if (abs(dx)>abs(dy)) {
      x0[i] = primary[i];
      x1[i] = primary[i]+txDelta;
      y0[i] = secondary[i];
      y1[i] = secondary[i]+tyDelta;
    } else {
      x0[i] = secondary[i];
      x1[i] = secondary[i]+txDelta;
      y0[i] = primary[i];
      y1[i] = primary[i]+tyDelta;
    }
  }
  int numBar1Columns = ceil(float(numLines)/float(2*numrepeats));
  int numBar2Columns = floor(float(numLines)/float(2*numrepeats));
  
  //convert RGB to 16-bit color values (red = 5 bits, green = 6, blue = 5)
  uint16_t colorMap[3] = {0, 0, 0};
  for (i=0;i<3;i++) {
    colorMap[i] = color[i][2]; //add blue value to lowest 5 bits
    colorMap[i] = colorMap[i]<<6; //shift blue over by 6 bits, leaving lower 6 bits empty now
    colorMap[i] |= color[i][1]; //add green value to lowest 6 bits
    colorMap[i] = colorMap[i]<<5; //shift blue/green over by 5 bits, leaving lowest 5 empty
    colorMap[i] |= color[i][0]; //add red value to lowest 5 bits
  }
      
  //initialize more variables
  unsigned long shiftPeriodUs;
  unsigned long flickerPeriodUs;
  int colorVec[500], prevColorVec[500];
  int edges[2*numrepeats];
  int colorRGB[3];
  int abortPattern = 0;
  float a;
  
  //ready to display pattern
  while (wait4Trig==1) {
    if (Serial.available()>0) { //if incoming commands are detected, abort current pattern
      abortPattern = 0;
      wait4Trig = 0;
    }
    if (digitalRead(TRIG_IN)==HIGH) { //if input trigger signal goes high
      wait4Trig = 0;
    }
    delay(1); // check inputs every 1 ms
  }
  if (abortPattern==1) { //if current pattern is aborted, "return" out of drawPattern()
    return;
  }
  
  startT = millis(); 
  digitalWrite(TRIG_OUT, HIGH);

  //wait if predelay is specified
  if ((millis()-startMs)<(pre*100)) {
    delay((startMs+(pre*100))-(millis()-startMs));
  }
  switch (type){
    case 1: //draw square-wave gratings, updating only the lines that change color
      shiftPeriodUs = (1000000/(float(freq)/10))/(float(numLines)/float(numrepeats));
      startMs = millis();
      
      //get "column" indices of edges (for square-wave gratings)
      for (i=0;i<numrepeats;i++) {
        edges[2*i] = numBar1Columns+((numBar1Columns+numBar2Columns)*i)-1;
        edges[(2*i)+1] = (numBar1Columns+numBar2Columns)*(i+1)-1;
      }
      for (i=0;i<numLines;i++) {
        if ((i%(numBar1Columns+numBar2Columns))<numBar1Columns) {
          colorVec[i] = 1;
        } else {
          colorVec[i] = 0;
        }
      }
  
      //draw full grating pattern in its starting position
      c = 0;
      startUs = micros();
      for (i=0; i<numLines; i++) {
        tft.drawLine(x0[i], y0[i], x1[i], y1[i], colorMap[colorVec[i]]); 
      }
      endUs = micros();
      durUs = endUs-startUs;
      bmark = (1000000/durUs)/2;
      //draw advancing/receding edges only to save time (everything else stays the same)
      c=0;
      Cidx = 0;
      while ((millis()-startMs)<(dur*100)) {
        startUs = micros();
        for (i=0; i<2*numrepeats; i++) {
          e = edges[i];
          Lidx = (e+c)%numLines; //line index
          Cidx = 1-Cidx; //to alternate between color[0] and color[1]
          tft.drawLine(x0[Lidx], y0[Lidx], x1[Lidx], y1[Lidx], colorMap[Cidx]); 
        }
        c++;     
        endUs = micros();
        durUs = endUs-startUs;
        if (durUs<shiftPeriodUs) {
          if ((shiftPeriodUs-durUs)>16380) {
            delay((shiftPeriodUs-durUs)/1000);
          } else {
            delayMicroseconds(shiftPeriodUs-durUs);
          }
        }
      }
      break;
    
    case 2: //draw sine-wave gratings - updating every line, every time
      //based on number of lines, calculate colorVec as approximate sine wave
      shiftPeriodUs = (1000000/(float(freq)/10))/(2*(float(numLines)/float(numrepeats)));

      //get color values for each column (for sine-wave gratings)
      a = 360/float(numBar1Columns+numBar2Columns);
      for (i=0;i<numLines;i++) {
        for (c=0;c<3;c++) {
          colorRGB[c] = round(((color[0][c] - color[1][c])*((sin(deg2rad(float(i)*a))+1)/2)) + color[1][c]);
        }
        colorVec[i] = colorRGB[2]; //add blue value to lowest 5 bits
        colorVec[i] = colorVec[i]<<6; //shift blue over by 6 bits, leaving lower 6 bits empty now
        colorVec[i] |= colorRGB[1]; //add green value to lowest 6 bits
        colorVec[i] = colorVec[i]<<5; //shift blue/green over by 5 bits, leaving lowest 5 empty
        colorVec[i] |= colorRGB[1]; //add red value to lowest 5 bits
        prevColorVec[i] = -1;
      }
  
      startMs = millis();
      while ((millis()-startMs)<(dur*100)) {
        startUs = micros();
        for (i=0; i<numLines; i++) {
          if (colorVec[i]!=prevColorVec[i]) { //only draw if column has changed
            tft.drawLine(x0[i], y0[i], x1[i], y1[i], colorVec[i]); 
          }
        }
        for (i=0;i<numLines;i++) { //duplicate colorVec
          prevColorVec[i] = colorVec[i];
        }
        for (i=0;i<numLines;i++) { //shift column colors by 1 for next frame
          colorVec[(i+1)%numLines]=prevColorVec[i];
        }
        endUs = micros();
        durUs = endUs-startUs;
        bmark = (1000000/durUs)/(numLines/numrepeats);
        if (durUs<shiftPeriodUs) {
          if ((shiftPeriodUs-durUs)>16380) {
            delay((shiftPeriodUs-durUs)/1000);
          } else {
            delayMicroseconds(shiftPeriodUs-durUs);
          }
        }
      }
      break;
      
    case 3: //draw flicker stimulus
      flickerPeriodUs = 1000000/(float(freq)/10);
      startMs = millis();
      while ((millis()-startMs)<(dur*100)) {
        for (c=0; c<2; c++) {
          startUs = micros();
          for (i=0; i<numLines; i+=4) { //draw 1st 1/4 bottom-top, left-right
            tft.drawLine(x0[i], y0[i], x1[i], y1[i], colorMap[c]); 
          }
          for (i=numLines-1+(numLines%2); i>-1; i+=-4) { //draw 2nd 1/4 top-bottom, right-left
            tft.drawLine(x1[i], y1[i], x0[i], y0[i], colorMap[c]); 
          }
          for (i=1; i<numLines; i+=4) { //draw 3rd 1/4 top-bottom, left-right
            tft.drawLine(x1[i], y1[i], x0[i], y0[i], colorMap[c]); 
          }
          for (i=numLines-2+(numLines%2); i>-1; i+=-4) { //draw 4th 1/4 bottom-top, right-left
            tft.drawLine(x0[i], y0[i], x1[i], y1[i], colorMap[c]); 
          }
          endUs = micros();
          durUs = endUs-startUs;
          bmark = (1000000/durUs)/2;
          if (durUs<(flickerPeriodUs/2)) {
            if (((flickerPeriodUs/2)-durUs)>16380) {
              delay(((flickerPeriodUs/2)-durUs)/1000);
            } else {
              delayMicroseconds((flickerPeriodUs/2)-durUs);
            }
          }
        }
      }
      break;
  }

  //set output trigger back to low
  digitalWrite(TRIG_OUT, LOW);
  
  //return to background color
  for (i=0; i<numLines; i++) {
    tft.drawLine(x0[i], y0[i], x1[i], y1[i], colorMap[2]); 
  }
}


void runDemo() {
  Serial.println("Demo mode for Teensy Display");

  while (Serial.available()<1) {
    
    //fill screen with solid color
    uint16_t time = millis();
    tft.fillScreen(ST77XX_BLACK);
    time = millis() - time;
    Serial.print(F("fillScreen (240x210): "));
    Serial.print(time, DEC);
    Serial.println(F(" ms draw time"));
    delay(1000);
  
    //display bitmap
    time = millis();
    tft.drawBitmap(0, 0, logos, 240, 210, ST77XX_WHITE);
    time = millis() - time;
    Serial.print(F("drawBitmap (240x210): "));
    Serial.print(time, DEC);
    Serial.println(F(" ms draw time"));
    delay(2000);
    tft.fillScreen(ST77XX_BLACK);
    delay(1000);
    
    // draw sine-wave gratings at 0.5 Hz temporal frequency
    numGratings = 3;
    barWidth = 40;
    angleBytes[0] = 0;
    angleBytes[1] = 0;
    temporalFrequencyDHz = 5; //0.5 Hz
    preDelayDs = 0;
    durationDs = 20; //2 s
    patternType = 2; //1=square-wave grating, 2=sine-wave grating, 3=flicker
    drawPattern(patternType, centerPosition, numGratings, barWidth, angleBytes, temporalFrequencyDHz, colorBytes, preDelayDs, durationDs, wait4Trigger, startTime, benchmarkHz);
    Serial.print(F("sine-wave gratings at 0.5 Hz (240x210): "));
    Serial.print(benchmarkHz);
    Serial.println(F(" Hz at max speed "));
    delay(2000);
    tft.fillScreen(ST77XX_BLACK);

    // draw square-wave gratings at 5 Hz temporal frequency
    temporalFrequencyDHz = 50; //5 Hz
    patternType = 1; //1=square-wave grating, 2=sine-wave grating, 3=flicker
    drawPattern(patternType, centerPosition, numGratings, barWidth, angleBytes, temporalFrequencyDHz, colorBytes, preDelayDs, durationDs, wait4Trigger, startTime, benchmarkHz);
    Serial.print(F("square-wave gratings at 5 Hz (240x210): "));
    Serial.print(benchmarkHz);
    Serial.println(F(" Hz at max speed "));
    delay(2000);
    tft.fillScreen(ST77XX_BLACK);

    // draw sine-wave gratings at 5 Hz temporal frequency
    durationDs = 10; //1 s
    numGratings = 1;
    barWidth = 40;
    temporalFrequencyDHz = 50; //5 Hz
    patternType = 2; //1=square-wave grating, 2=sine-wave grating, 3=flicker
    drawPattern(patternType, centerPosition, numGratings, barWidth, angleBytes, temporalFrequencyDHz, colorBytes, preDelayDs, durationDs, wait4Trigger, startTime, benchmarkHz);
    Serial.print(F("sine-wave gratings at 5 Hz (80x80): "));
    Serial.print(benchmarkHz);
    Serial.println(F(" Hz at max speed "));
    delay(2000);
    tft.fillScreen(ST77XX_BLACK);
    
    // draw square-wave gratings at 10 Hz temporal frequency
    temporalFrequencyDHz = 100; //10 Hz
    patternType = 1; //1=square-wave grating, 2=sine-wave grating, 3=flicker
    drawPattern(patternType, centerPosition, numGratings, barWidth, angleBytes, temporalFrequencyDHz, colorBytes, preDelayDs, durationDs, wait4Trigger, startTime, benchmarkHz);
    Serial.print(F("square-wave gratings at 10 Hz (80x80): "));
    Serial.print(benchmarkHz);
    Serial.println(F(" Hz at max speed "));
    delay(2000);
    tft.fillScreen(ST77XX_BLACK);
    
    //draw square-wave gratings for multiple directions - every 15 degrees
    patternType = 1;
    numGratings = 1;
    centerPosition[0] = 0;
    centerPosition[1] = 0;
    barWidth = 60;
    temporalFrequencyDHz = 20; //2 Hz
    durationDs = 10; //1 s
    Serial.println(F("square-wave gratings at 2 Hz (120x120), every 15 degrees:"));
    for (int a2=0;a2<=180;a2+=180) {
      angleBytes[1] = a2;
      for (int a=0;a<180;a+=15){
        angleBytes[0] = a;
        Serial.print("angle ");
        Serial.print(a+a2);
        Serial.print("    ");
        drawPattern(patternType, centerPosition, numGratings, barWidth, angleBytes, temporalFrequencyDHz, colorBytes, preDelayDs, durationDs, wait4Trigger, startTime, benchmarkHz);
        Serial.print(benchmarkHz);
        Serial.println(" Hz at max speed");
      }
    }
    delay(2000);
    tft.fillScreen(ST77XX_BLACK);
    Serial.println("");
  }
}
