# Geiger Meter simulator

This is a sample MacApp that simulates a Geiger counter bluetooth
peripheral using CoreBluetooth `CBPeripheralManager`.

The app advertises 2 services one as a custom battery service
that has a characteristic informing the current level of 
battery charge.
The second service is the Geiger Counter which is another custom
service. This service has 2 characteristics:

* Geiger counter - supports notify for change
* Command characteristic which allow send commands such as 
Standby or Switch on

This app is not a production implementation, it's only for demonstration proposes. 
For production implementation there are multiple things to consider from handling errors to 
persisting the connection and possibly pairing to a device. And of course proper automated tests.

## Getting started

Import open the project as a regular Xcode project and run the Mac app.
The app has 2 buttons one to start advertising and another one to stop.
I wrote the iOS demo [app](https://github.com/pablocaif/GeigerCounter)

When running the iOS demo app on a device the device will attempt to connect 
to the advertised peripheral and then attempt to discover and 
consume the services.