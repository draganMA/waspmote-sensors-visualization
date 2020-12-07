#include <WaspSensorAgr_v20.h>
#include <WaspWIFI.h>
#include <WaspFrame.h>

uint8_t socket=SOCKET0;

// TCP server settings
#define IP_ADDRESS "192.168.100.23"
#define REMOTE_PORT 61598
#define LOCAL_PORT 2000

// WiFi AP settings
#define ESSID "DIGI-NFZN"
#define AUTHKEY "5Z36tPsK"

// declaring variables in which to store the sensors measurements
float anemometer;
float pluviometer1; //mm in current hour 
float pluviometer2; //mm in previous hour
float pluviometer3; //mm in last 24 hours
int vane;
int pendingPulses;
uint8_t status;
uint8_t ROLL;
uint8_t PITCH;
int X_out;
int Y_out;
int Z_out;
float roll;
float pitch;
float temp;
float soil_temp;
float lum;

// define node identifier
char nodeID[] = "node_WS";

void setup()
{
  // set node ID
  frame.setID( nodeID ); 

  // Turn on the sensor board
  SensorAgrv20.ON();  

  wifi_setup();
}

void loop()
{
  // enter sleep mode
  SensorAgrv20.sleepAgr("00:00:00:00", RTC_ABSOLUTE, RTC_ALM1_MODE6, SOCKET0_OFF, SENS_AGR_PLUVIOMETER);

  // check for pluviometer interruption
  if( intFlag & PLV_INT)
  {
    USB.println(F("+++ PLV interruption +++"));

    pendingPulses = intArray[PLV_POS];

    USB.print(F("Number of pending pulses:"));
    USB.println( pendingPulses );

    for(int i=0 ; i<pendingPulses; i++)
    {
      // Enter pulse information inside class structure
      SensorAgrv20.storePulse();

      // decrease number of pulses
      intArray[PLV_POS]--;
    }

    // Clear flag
    intFlag &= ~(PLV_INT); 
  }

  // check for RTC interruption
  if(intFlag & RTC_INT)
  {
    USB.println(F("+++ RTC interruption +++"));  

    // measure sensors
    measureSensors();
    send_frame();

    // Clear flag
    intFlag &= ~(RTC_INT); 
  }  
  delay(10);
}

/*******************************************************************
 *
 *  measureSensors
 *
 *  This function reads from the sensors of the Weather Station and 
 *  then creates a new Waspmote Frame with the sensor fields in order 
 *  to prepare this information to be sent
 *
 *******************************************************************/
void measureSensors()
{  

  USB.println(F("------------- Measurement process ------------------"));
  
  // Turn on sensors
  SensorAgrv20.setSensorMode(SENS_ON, SENS_AGR_PT1000);
  SensorAgrv20.setSensorMode(SENS_ON, SENS_AGR_LDR);
  SensorAgrv20.setSensorMode(SENS_ON, SENS_AGR_ANEMOMETER);
  delay(10);

  // read attached sensors
  anemometer = SensorAgrv20.readValue(SENS_AGR_ANEMOMETER);
  
  pluviometer1 = SensorAgrv20.readPluviometerCurrent();
  pluviometer2 = SensorAgrv20.readPluviometerHour();
  pluviometer3 = SensorAgrv20.readPluviometerDay();
  
  vane = SensorAgrv20.readValue(SENS_AGR_VANE);

  soil_temp = SensorAgrv20.readValue(SENS_AGR_PT1000);
  lum = SensorAgrv20.readValue(SENS_AGR_LDR);
  
  // turn off attached sensors
  SensorAgrv20.setSensorMode(SENS_OFF, SENS_AGR_ANEMOMETER);
  SensorAgrv20.setSensorMode(SENS_OFF, SENS_AGR_PT1000);
  SensorAgrv20.setSensorMode(SENS_OFF, SENS_AGR_LDR);

  // Read on-board sensors
  RTC.ON();
  temp = RTC.getTemperature();

  status = ACC.check();
  X_out = ACC.getX();
  Y_out = ACC.getY();
  Z_out = ACC.getZ();

  // calculate roll and peach
  roll = atan(Y_out / sqrt(pow(X_out, 2) + pow(Z_out, 2))) * 180 / PI;
  pitch = atan(-1 * X_out / sqrt(pow(Y_out, 2) + pow(Z_out, 2))) * 180 / PI;

  char vane_str[10] = {0};
  // get vane direction
  switch(SensorAgrv20.vaneDirection)
  {
  case  SENS_AGR_VANE_N   :  snprintf( vane_str, sizeof(vane_str), "N");
                             break;
  case  SENS_AGR_VANE_NNE :  snprintf( vane_str, sizeof(vane_str), "NNE");
                             break;  
  case  SENS_AGR_VANE_NE  :  snprintf( vane_str, sizeof(vane_str), "NE");
                             break;    
  case  SENS_AGR_VANE_ENE :  snprintf( vane_str, sizeof(vane_str), "ENE");
                             break;      
  case  SENS_AGR_VANE_E   :  snprintf( vane_str, sizeof(vane_str), "E");
                             break;    
  case  SENS_AGR_VANE_ESE :  snprintf( vane_str, sizeof(vane_str), "ESE");
                             break;  
  case  SENS_AGR_VANE_SE  :  snprintf( vane_str, sizeof(vane_str), "SE");
                             break;    
  case  SENS_AGR_VANE_SSE :  snprintf( vane_str, sizeof(vane_str), "SSE");
                             break;   
  case  SENS_AGR_VANE_S   :  snprintf( vane_str, sizeof(vane_str), "S");
                             break; 
  case  SENS_AGR_VANE_SSW :  snprintf( vane_str, sizeof(vane_str), "SSW");
                             break; 
  case  SENS_AGR_VANE_SW  :  snprintf( vane_str, sizeof(vane_str), "SW");
                             break;  
  case  SENS_AGR_VANE_WSW :  snprintf( vane_str, sizeof(vane_str), "WSW");
                             break; 
  case  SENS_AGR_VANE_W   :  snprintf( vane_str, sizeof(vane_str), "W");
                             break;   
  case  SENS_AGR_VANE_WNW :  snprintf( vane_str, sizeof(vane_str), "WNW");
                             break; 
  case  SENS_AGR_VANE_NW  :  snprintf( vane_str, sizeof(vane_str), "NW");
                             break;
  case  SENS_AGR_VANE_NNW :  snprintf( vane_str, sizeof(vane_str), "NNW");
                             break;  
  default                 :  snprintf( vane_str, sizeof(vane_str), "error");
                             break;    
  }

  //Create Waspmote Frame
  frame.createFrame(ASCII); 
  
  // add sensors values to it
  frame.addSensor( SENSOR_PLV1, pluviometer1 );
  frame.addSensor( SENSOR_PLV2, pluviometer2 );
  frame.addSensor( SENSOR_PLV3, pluviometer3 );
  frame.addSensor( SENSOR_ANE, anemometer );
  frame.addSensor( SENSOR_WV, vane_str );
  frame.addSensor(SENSOR_TCA, temp);
  frame.addSensor(SENSOR_SOILT, soil_temp);
  frame.addSensor(SENSOR_LUM, lum);
  frame.addSensor(ROLL, roll);
  frame.addSensor(PITCH, pitch);
  frame.addSensor(SENSOR_BAT, PWR.getBatteryLevel() );
}

void send_frame()
{  
  // Switch WiFi ON
  WIFI.ON(socket);

  //  Join AP
  if (WIFI.join(ESSID)) 
  {
    USB.println("Connected to AP");
    WIFI.getIP();
    
    // try a TCP connection 
    if (WIFI.setTCPclient(IP_ADDRESS, REMOTE_PORT, LOCAL_PORT)) 
    {
      // connection is open now 
      USB.println(F("TCP client set"));
  
      // send frame
      WIFI.send(frame.buffer,frame.length);  
      
      // close the TCP connection. 
      USB.println(F("Close TCP socket"));
      WIFI.close(); 
    }
    else
    {
      USB.println(F("TCP client NOT set"));
    } 
  }
  else
  {   
    USB.println(F("NOT Connected to AP"));
  }

  // Switch off wifi module
  WIFI.OFF();  
  USB.println(F("***************************"));
}

void wifi_setup()
{
  // Switch ON the WiFi module
  if( WIFI.ON(socket) == 1 )
  {    
    USB.println(F("WiFi switched ON"));
  }
  else
  {
    USB.println(F("WiFi did not initialize correctly"));
  }

  // Configure the transport protocol (UDP, TCP, FTP, HTTP...) 
  WIFI.setConnectionOptions(CLIENT); 

  // Configure the way the modules will resolve the IP address. 
  WIFI.setDHCPoptions(DHCP_ON);    

  // Configure how to connect the AP 
  WIFI.setJoinMode(MANUAL); 

  // Set Authentication key
  WIFI.setAuthKey(WPA2,AUTHKEY); 

  // Store values
  WIFI.storeData();
}
