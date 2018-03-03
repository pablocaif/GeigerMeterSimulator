//
//  GeigerLEService.swift
//  GeigerMeterSimulator
//
//  Created by Pablo Caif on 18/2/18.
//  Copyright © 2018 Pablo Caif. All rights reserved.
//

import Foundation
import CoreBluetooth

public protocol GeigerLEServiceDelegate: class {
    func serviceNotify(message: String)
}

public class GeigerLEService: NSObject {
    
    private var peripheralManager: CBPeripheralManager?
    private var geigerMeterService: CBMutableService?
    private var radiationSensorChar: CBMutableCharacteristic?
    private let serviceGeigerCounterID = "9822918C-312C-48FA-AD7C-A5E9853C5AC5"
    private let radiationCountCharID = "190124D9-BB53-4ACB-9C48-F4D5F8C81668"
    
    private let geigerBatteryServiceID = "FA0EA16D-49D5-438C-99A7-CF61ACA41F36"
    private var batteryService: CBMutableService?
    private let geigerBatteryLevelCharID = "FA0EA16D-49D5-438C-99A7-CF61ACA41F36"
    private var batteryLevelChar: CBMutableCharacteristic?
    
    private let geigerCommandCharID = "F35065D4-DE1D-4A50-B7D0-4AE378B7E51D"
    private var geigerCommandChar: CBMutableCharacteristic?
    
    public weak var delegate: GeigerLEServiceDelegate?
    
    private var timer :Timer?


    ///Calling this function will attempt to start advertising the services
    ///as well as create the services and characteristics
    public func startAdvertisingPeripheral() {
        if peripheralManager == nil {
            peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        }
        
        if peripheralManager?.state == .poweredOn {
            peripheralManager?.removeAllServices()
            setupServicesAndCharac()
            peripheralManager?.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [CBUUID(string: serviceGeigerCounterID), CBUUID(string: geigerBatteryServiceID)]])
            delegate?.serviceNotify(message: "Service started")
        }
        
    }

    ///Calling this function will stop advertising the services
    public func stopAdvertising() {
        timer?.invalidate()
        peripheralManager?.stopAdvertising()
        peripheralManager?.removeAllServices()
        geigerMeterService = nil
        radiationSensorChar = nil
        peripheralManager = nil
        delegate?.serviceNotify(message: "Service stopped")
    }
    
    private func setupServicesAndCharac() {
        createBatteryService()
        createGeigerCounterService()
    }
    
    private func createGeigerCounterService() {
        //Services and characteristics need to be created prior to publishing the services
        radiationSensorChar = CBMutableCharacteristic(type: CBUUID(string: radiationCountCharID), properties: .notify, value: nil, permissions: .readable)
        geigerMeterService = CBMutableService(type: CBUUID(string: serviceGeigerCounterID), primary: true)
        let nameDescriptor = CBMutableDescriptor(type: CBUUID(string:CBUUIDCharacteristicUserDescriptionString), value: "Geiger counter")
        let typeDescriptor = CBMutableDescriptor(type: CBUUID(string:CBUUIDCharacteristicFormatString), value: CBUUIDCharacteristicFormatString.data(using: .utf8))
        radiationSensorChar?.descriptors = [nameDescriptor, typeDescriptor]
        
        geigerCommandChar = CBMutableCharacteristic(type: CBUUID(string: geigerCommandCharID), properties: .write, value: nil, permissions: .writeable)
        let commandDescriptor = CBMutableDescriptor(type: CBUUID(string:CBUUIDCharacteristicUserDescriptionString), value: "Commands")
        geigerCommandChar?.descriptors = [commandDescriptor]
        
        geigerMeterService?.characteristics = [radiationSensorChar!, geigerCommandChar!]
        peripheralManager?.add(geigerMeterService!)
    }
    
    private func createBatteryService() {
        batteryLevelChar = CBMutableCharacteristic(type: CBUUID(string: geigerBatteryLevelCharID), properties: .read, value: nil, permissions: .readable)
        let batteryDescriptor = CBMutableDescriptor(type: CBUUID(string:CBUUIDCharacteristicUserDescriptionString), value: "Battery level")
        batteryLevelChar?.descriptors = [batteryDescriptor]
        batteryService = CBMutableService(type: CBUUID(string: geigerBatteryServiceID), primary: true)
        batteryService?.characteristics = [batteryLevelChar!]
        peripheralManager?.add(batteryService!)
    }

    ///This function gets called by the timer and it will generate random geiger readings
    private func updateReadValue(timer: Timer) {
        guard
            let radiationSensorChar = radiationSensorChar,
            let peripheralManager = peripheralManager
            else {
                return
            }
        let radiationReading = Float32(arc4random() % 100)
        
        let bufferLength = MemoryLayout<Float32>.size
        let buffer = UnsafeMutableRawPointer.allocate(bytes: bufferLength, alignedTo: MemoryLayout<Float32>.alignment)
        _ = buffer.initializeMemory(as: Float32.self, count: 1, to: radiationReading)
        
        defer {
            buffer.deallocate(bytes: bufferLength, alignedTo: MemoryLayout<Float32>.alignment)
        }
        let dataToSend = Data(bytes: buffer, count: bufferLength)
        
        let sent = peripheralManager.updateValue(dataToSend, for: radiationSensorChar, onSubscribedCentrals: nil)
        if !sent {
            print("Could not send value\n")
        }
    }
    
    private func stopTransmitting() {
        timer?.invalidate()
        timer = nil
    }
    
    private func startTransmittingReadings() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.4 , repeats: true, block: updateReadValue)
        RunLoop.current.add(timer!, forMode: .commonModes)
    }
}

// MARK: CBPeripheralManagerDelegate
extension GeigerLEService: CBPeripheralManagerDelegate {
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            print("Peripheral manager switched on\n")
            startAdvertisingPeripheral()
        case .poweredOff:
            print("Peripheral manager switched off\n")
            stopAdvertising()
        case .resetting:
            print("Peripheral manager reseting\n")
            stopAdvertising()
        case .unauthorized:
            print("Peripheral manager unauthorised\n")
        case .unknown:
            print("Peripheral manager unknown\n")
        case .unsupported:
            print("Peripheral manager unsoported\n")
        }
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        if characteristic.uuid == radiationSensorChar?.uuid {
            //We negotiate low latency with the central. The central will respond with its lowest connection time
            peripheralManager?.setDesiredConnectionLatency(.low, for: central)
            
            startTransmittingReadings()
            let message = "Central \(central.identifier.uuidString) subscribed"
            print(message)
            delegate?.serviceNotify(message: message)
        }
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        let message = "Central \(central.identifier.uuidString) cancelled subscription"
        print(message)
        delegate?.serviceNotify(message: message)
        if characteristic.uuid == radiationSensorChar?.uuid {
            stopTransmitting()
        }
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        //If the request is to read the battery level we generate a random battery level and return
        if request.characteristic.uuid == batteryLevelChar?.uuid {
            var batteryLevel: UInt8 = UInt8(arc4random() % 100)
            batteryLevelChar?.value = Data(bytes: &batteryLevel, count: MemoryLayout<UInt8>.size)
            request.value = batteryLevelChar?.value
            peripheralManager?.respond(to: request, withResult: .success)
            delegate?.serviceNotify(message: "New battery level=\(batteryLevel)%")
        }
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        requests.forEach { request in
            //If the request is to write to the command characteristic we execute the command
            if request.characteristic.uuid == geigerCommandChar?.uuid {
                var command = UInt8(0)
                guard let data = request.value else {return}
                data.copyBytes(to: &command, count: MemoryLayout<UInt8>.size)
                switch command {
                case GeigerCommand.standBy.rawValue:
                    stopTransmitting()
                    delegate?.serviceNotify(message: "Received command to standby")
                case GeigerCommand.on.rawValue:
                    startTransmittingReadings()
                    delegate?.serviceNotify(message: "Received command to turn on")
                default:
                    peripheralManager?.respond(to: request, withResult: .requestNotSupported)
                    return
                }
                geigerCommandChar?.value = Data(bytes: &command, count: MemoryLayout<UInt8>.size)
                peripheralManager?.respond(to: request, withResult: .success)
            }
        }
    }
    
    public func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        print("Did start advertising")
        if let errorAdvertising = error {
            print("Error advertising \(errorAdvertising.localizedDescription)")
        }
    }
}

enum GeigerCommand: UInt8 {
    case standBy = 0
    case on
}
