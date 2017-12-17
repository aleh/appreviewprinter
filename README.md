# App Store Review Printer

Lua-only firmware for an autonomous App Store review printer based on NodeMCU and a stock thermal printer.

Note that it is still under development.

## Configuration

The Makefile is tested with OS X only but should work on Linux. It assumes you have the amazing [nodemcu-uploader](https://github.com/kmpm/nodemcu-uploader) installed and that your NodeMCU device has its name matching `/dev/tty.wchusbserial*` pattern.

Rename `config-example.lua` to `config.lua` and adjust to suit your needs.

## Printer

Any stock thermal printer should work here, like the ones sold by Adafruit. And as always they have great docs here: https://cdn-learn.adafruit.com/downloads/pdf/mini-thermal-receipt-printer.pdf

Sparkfun also has related docs, though don't rely on all the commands available in every printer: 
https://www.sparkfun.com/datasheets/Components/General/Driver%20board.pdf

Here is a link for a cheap 58mm one (turned out to be pretty narrow):
https://aliexpress.com/item/JP-QR203-58mm-Mini-Embedded-Receipt-Thermal-Printer-Compatible-with-EML203/32653084570.html

Name on the front: GOOJPRT

TTL connector wires:

        BLACK  - GND
        RED    - VCC
        YELLOW - TX (i.e. data from the controller to the printer)
        GREEN  - perhaps RX, though was not able to get anything back from the printer.
        BLUE   - sort of a CTS signal, 0 if the printer ready, 1 if we need to wait.

See `./doc/escpos.pdf` on some of the escape commands supported.
