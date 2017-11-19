# App Store Review Printer

## Configuration

Rename `config-example.lua` to `config.lua` and adjust to suit your needs.

## Printer

Order link for a 58mm one (turned out to be pretty narrow):
https://aliexpress.com/item/JP-QR203-58mm-Mini-Embedded-Receipt-Thermal-Printer-Compatible-with-EML203/32653084570.html

Name on the front: GOOJPRT

TTL connector wires:
BLACK  - GND
RED    - VCC
YELLOW - TX (i.e. data from the controller to the printer)
GREEN  - perhaps RX, though was not able to get anything back from the printer.
BLUE   - sort of a CTS signal, 0 if the printer ready, 1 if we need to wait.

Similar printers from Adafruit:
https://cdn-learn.adafruit.com/downloads/pdf/mini-thermal-receipt-printer.pdf

See `./docs` on some of the escape commands supported.

