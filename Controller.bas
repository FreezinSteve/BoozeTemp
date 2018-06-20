' Therm2.Bas - PICAXE-14M
'
' Four channel temperature measurement using 10K NTC thermistors on A/D 0, 1, 6, 7.
'
' Measures voltage across the thermistor and uses a combination of table lookup
' and linear interpolation to calculate the temperature in degrees C.
'
' Sends temperature to PC (or similar).
'
' For each channel, operates or releases relays, or similar, on OUT0, 1, 2 or 3.  Note that
' this may be used to turn on a fan (hot alarm) or turn on a heater (cold alarm).
'
' Uses about 400 bytes of 2048 available.
'
' copyright, Peter H Anderson, Baltimore, MD, June, '05

  Symbol ADVal = W0
  Symbol TC_100 = W0	' ADVal not needed when TC_100 is calculated

  'Symbol Channel = B2
 
  Symbol ADValHi8 = B3
  Symbol ADValLow2 = B4
  Symbol N = B5
  Symbol SignFlag = B5	' N is not need when this is used
  Symbol Digg = B6	' Diff not needed when this is used
  Symbol Diff = B6
  Symbol Whole = B7
  Symbol Fract = B8
  Symbol Setpoint = B9
  Symbol SP_100 = W5		' B10 and B11
  Symbol ScreenTimer = W6 	' B12 and B13   
  
  
  Symbol TEMP_CHAN = C.0
  Symbol HEATER_PIN = B.3
  Symbol OLED_RST = B.4
  Symbol OLED_RX = B.5
  Symbol SET_UP = PinC.1
  Symbol SET_DN = PinC.2
  
  Symbol BAUD = T9600_8
  Symbol TEMP_ROW = 0x02
  Symbol SETP_ROW = 0x03
  Symbol HEAT_ROW = 0x06
  Symbol HEAT_COL = 0x03
  Symbol DATA_COL = 0x07
  Symbol SP_ADDR = 255
  Symbol SCREEN_TIMEOUT = 900	' about 15 minutes
  
  setfreq m8
  
  setint or %00000110,%00000110
  

' Wait 500ms for OLED to power up
' Send U (0x55) to enable auto-baud
' Send E (0x45) to erase screen
' Send B (0x42 MSB LSB) to set back colour
' Send Hello 73 00 00 00 FF FF 48 65 6C 6C 6F 00 (73, COL, ROW, FONT, COLOUR_MSB, COLOUR_LSB, CHAR, CHAR,... 00
  High OLED_RX
  
  High OLED_RST
  Pause 100
  Low OLED_RST
 
  Pause 1000  
  serout OLED_RX,BAUD,(0x55, 0x55, 0x55)
  Pause 50      
  serout OLED_RX,BAUD,(0x42, 0x00, 0x00)  	' Set black
  Pause 1500  
  
  ' Set pen size to 1 to enable line drawing
  serout OLED_RX,baud,(0x70,0x01)	
  ' Draw a rectangular border
  serout OLED_RX,BAUD,(0x72,0x00,0x00,0x5F,0x3F,0x00,0xFF)
  Pause 10  
  serout OLED_RX,BAUD,(0x72,0x01,0x01,0x5E,0x3E,0x00,0xAA)
  Pause 10  
  serout OLED_RX,BAUD,(0x72,0x02,0x02,0x5D,0x3D,0x00,0x55)
  Pause 10  
  serout OLED_RX,BAUD,(0x72,0x03,0x03,0x5C,0x3C,0x00,0x3)
  Pause 10  
  serout OLED_RX,BAUD,(0x4C,0x04,0x06,0x5B,0x06,0x88,0x00)
  Pause 10  
  serout OLED_RX,BAUD,(0x4C,0x04,0x12,0x5B,0x12,0x88,0x00)
  Pause 10  

  ' Set opaque text
  serout OLED_RX,BAUD,(0x4F,0x01)    
  Pause 10  
  serout OLED_RX,BAUD,(0x73,0x00,0x01,0x01,0xFF,0xFF, "Booze Master",0x00)	' Header row
  Pause 10  
  serout OLED_RX,BAUD,(0x73,0x01,TEMP_ROW,0x02,0xFF,0xFF, "Temp:",0x00)	
  Pause 10  
  serout OLED_RX,BAUD,(0x73,0x01,SETP_ROW,0x02,0xFF,0xFF, "Set :",0x00)	
  Pause 10  
    
  ' Get current setpoint from EEPROM
  read SP_ADDR,Setpoint
  if Setpoint = 0 then
  	Setpoint = 20
  endif
  ScreenTimer = SCREEN_TIMEOUT - 1
  
  
Top:

  
  GoSub MeasTemp
  GoSub DisplayTemp
  GoSub ThermostatSet  
  Gosub DisplaySetpoint
  
  if ScreenTimer = SCREEN_TIMEOUT Then
  	ScreenTimer = ScreenTimer - 1 
  	' Switch on screen
  	serout OLED_RX,BAUD,(0x59,0x01,0x01)
  	
  elseif ScreenTimer > 0 Then
  	ScreenTimer = ScreenTimer - 1   	
  	if ScreenTimer = 0 Then
  		' Switch off screen
  		serout OLED_RX,BAUD,(0x59,0x01,0x00)
  	endif
  endif 
  
  Pause 1000
  GoTo Top


MeasTemp:

  ReadADC10 TEMP_CHAN, ADVal
  ADValHi8 = ADVal / 4    ' isolate the high 8 bits
  ADValLow2 = ADVal & $03 ' low two bits

  TC_100 = 10542 + 234' adjust this as required.  Note this varies from channel to channel
  If ADValHi8  < 16 Then TooHot
  If ADValHi8 > 251 Then TooCold

  ; Calculate the temperature
  For N = 0 to ADValHi8 ' continue to subtract
     Read N, Diff
     TC_100 = TC_100 - Diff
  Next
  ' Now for the low two bits, a linear interpolation
  N = N + 1
  Read N, Diff
  Diff = Diff / 4 * ADValLow2

  TC_100 = TC_100 - Diff

MeasTemp_return:

  Return

TooHot:
TooCold:
   TC_100 = $7fff
   GoTo MeasTemp_return


DisplayTemp:
  ' Set opaque text
  serout OLED_RX,BAUD,(0x4F,0x01)
' Start of new text row	
  serout OLED_RX,BAUD,(0x73, DATA_COL, TEMP_ROW, 0x02, 0xFF, 0xFF)
  
 'serout oled_rx,baud,(#Channel, " ");
  If TC_100 = $7fff Then DisplayTempOutofRange
  SignFlag = Tc_100 / 256 / 128
  If SignFlag = 0 Then DisplayTempPositive
  TC_100 = TC_100 ^ $ffff + 1	' twos comp
  serout OLED_RX,BAUD,("-")

DisplayTempPositive:

  Whole = TC_100 / 100
  Fract = TC_100 % 100
  serout OLED_RX,BAUD,(#Whole, ".")
  ' be sure the fractional is one digit
  Digg = Fract / 10
  serout OLED_RX,BAUD,(#Digg,0x00)
  Goto DisplayTempReturn

DisplayTempOutofRange:
  serout OLED_RX,BAUD,("!ERR",0x00)
  Goto DisplayTempReturn

DisplayTempReturn:
  Return
  
DisplaySetpoint:
  ' Set opaque text
  serout OLED_RX,BAUD,(0x4F,0x01)
  ' Display setpoint
  serout OLED_RX,BAUD,(0x73, DATA_COL, SETP_ROW, 0x02, 0xFF, 0xFF, #Setpoint, ".0",0x00)
  
  Return

ThermostatSet:
	
  SP_100 = Setpoint * 100
  sertxd ("Temp=",#TC_100,", Setpoint=" , #SP_100,13,10)  
  
  If TC_100 > SP_100 Then TurnOff  ' Hot alarm 20.00, Off at 19.00
  SP_100 = SP_100 - 50			' 1/2 degree threshold
  If TC_100 < SP_100 Then TurnOn
  Goto ThermoStatSetReturn

TurnOn:
  High HEATER_PIN
  ' Set opaque text
  '(73, COL, ROW, FONT, COLOUR_MSB, COLOUR_LSB, CHAR, CHAR,... 00
  serout OLED_RX,BAUD,(0x4F,0x01)
  serout OLED_RX,BAUD,(0x73, HEAT_COL, HEAT_ROW, 0x01, 0x88, 0x00,"==ON== ",0x00)
  Goto ThermoStatSetReturn

TurnOff:
  Low HEATER_PIN
  serout OLED_RX,BAUD,(0x4F,0x01)
  serout OLED_RX,BAUD,(0x73, HEAT_COL, HEAT_ROW, 0x01, 0x07, 0xE0,"==OFF== ",0x00)
  Goto ThermoStatSetReturn

ThermoStatSetReturn:
   Return

;========================================
; Callback for UP/DOWN buttons
interrupt:

  ' If screen is OFF then turn screen ON
  if ScreenTimer = 0 then
  	ScreenTimer = SCREEN_TIMEOUT
  	goto interrupt_wait
  endif
  
  if SET_UP = 1 then
  	Setpoint = Setpoint + 1
  	if Setpoint > 40 then
  		Setpoint = 40
  	endif
  elseif SET_DN = 1 then
  	Setpoint = Setpoint - 1  
      if Setpoint < 10 then
      	Setpoint = 10
    	endif
  endif

  ' Write to EEPROM
  write SP_ADDR,Setpoint
  
 ' Wait for interrupt to clear
interrupt_wait:
   pause 10
   if SET_UP = 1 then goto interrupt_wait  
   if SET_DN = 1 then goto interrupt_wait
   pause 50   
   setint or %00000110,%00000110
return


'''''''''''''''''''''''''''''''''''''''''''''''''''''''
 ' EEPROM locations 0 - 15 not used

  EEPROM 16, (254, 236, 220, 206, 194, 183, 173, 164)
  EEPROM 24, (157, 149, 143, 137, 131, 126, 122, 117)
  EEPROM 32, (113, 110, 106, 103, 100, 97, 94, 92)
  EEPROM 40, (89, 87, 85, 83, 81, 79, 77, 76)
  EEPROM 48, (74, 73, 71, 70, 69, 67, 66, 65)
  EEPROM 56, (64, 63, 62, 61, 60, 59, 58, 57)
  EEPROM 64, (57, 56, 55, 54, 54, 53, 52, 52)
  EEPROM 72, (51, 51, 50, 49, 49, 48, 48, 47)
  EEPROM 80, (47, 46, 46, 46, 45, 45, 44, 44)
  EEPROM 88, (44, 43, 43, 43, 42, 42, 42, 41)
  EEPROM 96, (41, 41, 41, 40, 40, 40, 40, 39)
  EEPROM 104, (39, 39, 39, 39, 38, 38, 38, 38)
  EEPROM 112, (38, 38, 37, 37, 37, 37, 37, 37)
  EEPROM 120, (37, 36, 36, 36, 36, 36, 36, 36)
  EEPROM 128, (36, 36, 36, 36, 36, 35, 35, 35)
  EEPROM 136, (35, 35, 35, 35, 35, 35, 35, 35)
  EEPROM 144, (35, 35, 35, 35, 35, 35, 35, 35)
  EEPROM 152, (35, 35, 35, 35, 35, 35, 35, 35)
  EEPROM 160, (36, 36, 36, 36, 36, 36, 36, 36)
  EEPROM 168, (36, 36, 36, 37, 37, 37, 37, 37)
  EEPROM 176, (37, 37, 38, 38, 38, 38, 38, 39)
  EEPROM 184, (39, 39, 39, 39, 40, 40, 40, 41)
  EEPROM 192, (41, 41, 42, 42, 42, 43, 43, 43)
  EEPROM 200, (44, 44, 45, 45, 46, 46, 47, 47)
  EEPROM 208, (48, 48, 49, 50, 50, 51, 52, 53)
  EEPROM 216, (53, 54, 55, 56, 57, 58, 59, 61)
  EEPROM 224, (62, 63, 65, 66, 68, 70, 72, 74)
  EEPROM 232, (76, 78, 81, 84, 87, 90, 94, 98)
  EEPROM 240, (102, 107, 113, 119, 126, 135, 144, 156)
  EEPROM 248, (170, 187, 208, 235)

  ' EEPROM 255 = Setpoint storage
