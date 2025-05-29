#include <WiFi.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <Preferences.h>
#include <DHT.h>
#include <HTTPClient.h>

#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 32
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, -1);

Preferences preferences;

#define MAX_WIFI 3

String currentSSID = "";
String ssidList[MAX_WIFI];
String passList[MAX_WIFI];

// DHT11
#define DHTPIN 4
#define DHTTYPE DHT11
DHT dht(DHTPIN, DHTTYPE);

// Relay
#define RELAY_PIN 5

unsigned long lastRead = 0;
const long interval = 10000; // 10 seconds
const float high_temp = 35;

int postSensorData(float temp, float hum, bool alert) {
  if (isnan(temp)) temp = 0;
  if (isnan(hum)) hum = 0;

  String postData = "device_id=ESP32-01";
  postData += "&temperature=" + String(temp);
  postData += "&humidity=" + String(hum);
  postData += "&alert=" + String(alert ? 1 : 0);

  HTTPClient http;
  http.begin("https://umairsuhaimee.com/sensor_data/post_reading.php");
  http.addHeader("Content-Type", "application/x-www-form-urlencoded");

  int httpCode = http.POST(postData);

  http.end();
  return httpCode;
}

bool getStableDHTReading(float &temp, float &hum, int retries = 3) {
  for (int i = 0; i < retries; i++) {
    temp = dht.readTemperature();
    hum = dht.readHumidity();
    if (!isnan(temp) && !isnan(hum)) return true;
    delay(1000);
  }
  // Final fallback
  if (isnan(temp)) temp = 0;
  if (isnan(hum))  hum = 0;
  return false;
}

struct ScrollLine {
  String text;
  int y;
  int offset = 0;
  int scrollDir = -1;
  int scrollRange = 0;
  int scrollSpeed = 1;
};

ScrollLine lines[4];
unsigned long lastScrollUpdate = 0;
const int scrollSpeed = 30;
unsigned long directionChangeDelay[4] = {0, 0, 0, 0}; // Track delay per line
bool waitingDelay[4] = {false, false, false, false};

void updateScrollingDisplay() {
  if (millis() - lastScrollUpdate >= scrollSpeed) {
    lastScrollUpdate = millis();

    display.clearDisplay();
    display.setTextWrap(false);

    for (int i = 0; i < 4; i++) {
      if (lines[i].scrollRange > 0) {
        if (waitingDelay[i]) {
          // Wait for 1s delay after direction change
          if (millis() - directionChangeDelay[i] < 1000) {
            display.setCursor(lines[i].offset, lines[i].y);
            display.println(lines[i].text);
            continue;
          } else {
            waitingDelay[i] = false; // End delay, resume scrolling
          }
        }

        lines[i].offset += lines[i].scrollSpeed * lines[i].scrollDir;

        if (lines[i].offset <= -lines[i].scrollRange || lines[i].offset >= 0) {
          lines[i].scrollDir *= -1; // Reverse direction
          directionChangeDelay[i] = millis(); // Start delay timer
          waitingDelay[i] = true;
        }
      }

      display.setCursor(lines[i].offset, lines[i].y);
      display.println(lines[i].text);
    }

    display.display();
  }
}

void setDisplayLines(String l1, String l2, String l3, String l4) {
  String all[4] = { l1, l2, l3, l4 };
  for (int i = 0; i < 4; i++) {
    lines[i].text = all[i];
    lines[i].y = i * 8;

    int16_t x1, y1;
    uint16_t tw, th;
    display.getTextBounds(lines[i].text, 0, lines[i].y, &x1, &y1, &tw, &th);
    lines[i].scrollRange = max(0, (int)tw - SCREEN_WIDTH);
    lines[i].offset = 0;
    lines[i].scrollDir = -1;
    lines[i].scrollSpeed = 1;
  }
}

void displayStatus(String msg) {
  display.setTextWrap(true);
  display.clearDisplay();
  display.setCursor(0, 0);
  display.setTextSize(1);
  display.setTextColor(WHITE);
  display.println(msg);
  display.display();
}

void displayReading(float temp, float hum, bool alert, int code) {
  String line1 = "WiFi Status: Connected to " + currentSSID;
  String line2 = "Temperature: " + String(temp) + " C";
  String line3 = "Humidity: " + String(hum) + " %";
  String line4 = (code > 0 ? "POST Success" : "POST Failed");
  if (alert) {
    line4 += " | High Temperature Alert!";
    digitalWrite(RELAY_PIN, HIGH);
  } else {
    digitalWrite(RELAY_PIN, LOW);
  }

  setDisplayLines(line1, line2, line3, line4);
}

void loadWiFiCredentials() {
  preferences.begin("wifiCreds", true);
  for (int i = 0; i < MAX_WIFI; i++) {
    ssidList[i] = preferences.getString(("ssid" + String(i)).c_str(), "");
    passList[i] = preferences.getString(("pass" + String(i)).c_str(), "");
  }
  preferences.end();
}

void connectToWiFi() {
  WiFi.disconnect(true);
  WiFi.mode(WIFI_STA);
  delay(100);
  displayStatus("WiFi: Scanning...");

  int found = WiFi.scanNetworks();
  if (found == 0) {
    displayStatus("WiFi: No Network");
    delay(5000);
    return;
  }

  for (int i = 0; i < MAX_WIFI; i++) {
    if (ssidList[i] == "") continue;
    for (int j = 0; j < found; j++) {
      if (WiFi.SSID(j) == ssidList[i]) {
        WiFi.begin(ssidList[i].c_str(), passList[i].c_str());
        displayStatus("WiFi: Connecting to " + ssidList[i]);
        int tries = 0;
        while (WiFi.status() != WL_CONNECTED && tries < 20) {
          delay(500);
          tries++;
        }
        if (WiFi.status() == WL_CONNECTED) {
          currentSSID = ssidList[i];
          displayStatus("WiFi: " + currentSSID);
          return;
        }
      }
    }
  }

  displayStatus("WiFi: No WiFi");
}

// Add/overwrite credentials to EEPROM (manually call once then comment out)
void saveSampleCredentials() {
  preferences.begin("wifiCreds", false); // write mode
  preferences.putString("ssid0", "myUUM_Guest");
  preferences.putString("pass0", "");

  preferences.putString("ssid1", "UUMWiFi_Guest");
  preferences.putString("pass1", "");

  preferences.putString("ssid2", "iPhone 16 Pro Max");
  preferences.putString("pass2", "umair12111");
  preferences.end();
}

void setup() {
  Serial.begin(115200);
  display.begin(SSD1306_SWITCHCAPVCC, 0x3C);
  display.clearDisplay();
  dht.begin();
  delay(100);
  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, LOW);  // OFF by default (active HIGH)

  // Call once to save WiFi (comment out after first flash)
  // saveSampleCredentials();

  loadWiFiCredentials();
  connectToWiFi();
}

void loop() {
  updateScrollingDisplay();

  if (WiFi.status() != WL_CONNECTED) {
    connectToWiFi();
  }

  if (millis() - lastRead >= interval) {
    lastRead = millis();

    float temp = NAN, hum = NAN;
    bool success = getStableDHTReading(temp, hum);
    bool alert = temp > high_temp;

    int code = postSensorData(temp, hum, alert);

    if (success) {
      displayReading(temp, hum, alert, code);
    } else {
      displayStatus("Failed to read DHT!");
      digitalWrite(RELAY_PIN, LOW); // Turn relay OFF
    }
  }
}