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
    func serviceNotifiy(message: String)
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
    
    public func startAdvertisingPeripheral() {
        if peripheralManager == nil {
            peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        }
        
        if peripheralManager?.state == .poweredOn {
            peripheralManager?.removeAllServices()
            setupServicesAndCharac()
            peripheralManager?.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [CBUUID(string: serviceGeigerCounterID)]])
            delegate?.serviceNotifiy(message: "Service started")
        }
        
    }
    
    public func stopAdvertising() {
        timer?.invalidate()
        peripheralManager?.stopAdvertising()
        peripheralManager?.removeAllServices()
        geigerMeterService = nil
        radiationSensorChar = nil
        peripheralManager = nil
        delegate?.serviceNotifiy(message: "Service stopped")
    }
    
    private func setupServicesAndCharac() {
        createBatteryService()
        createGeigerCounterService()
    }

    private func createGeigerCounterService() {
        radiationSensorChar = CBMutableCharacteristic(type: CBUUID(string: radiationCountCharID), properties: .notify, value: nil, permissions: .readable)
        geigerMeterService = CBMutableService(type: CBUUID(string: serviceGeigerCounterID), primary: true)
        let descriptor = CBMutableDescriptor(type: CBUUID(string:CBUUIDCharacteristicUserDescriptionString), value: "Geiger counter")
        radiationSensorChar?.descriptors = [descriptor]

        geigerCommandChar = CBMutableCharacteristic(type: CBUUID(string: geigerCommandCharID), properties: .write, value: nil, permissions: .writeEncryptionRequired)
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
    
    private func updateReadValue(timer: Timer) {
        guard
            let radiationSensorChar = radiationSensorChar,
            let peripheralManager = peripheralManager
        else {
            return
        }
        var radiationReading = Float32(arc4random() % 100)
        
        let dataToSend = Data(bytes: &radiationReading, count: MemoryLayout<Float32>.size)
        
        let sent = peripheralManager.updateValue(dataToSend, for: radiationSensorChar, onSubscribedCentrals: nil)
        if !sent {
            print("Cound not send value\n")
        }
    }
    
        fileprivate func stopTransmiting() {
            timer?.invalidate()
            timer = nil
        }
    
        fileprivate func startTransmitingReadings() {
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: updateReadValue)
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
            peripheralManager?.setDesiredConnectionLatency(.low, for: central)
            
            startTransmitingReadings()
            let message = "Central \(central.identifier.uuidString) subscribed\n"
            print(message)
            delegate?.serviceNotifiy(message: message)
        }
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        let message = "Central \(central.identifier.uuidString) cancelled subscription"
        print(message)
        delegate?.serviceNotifiy(message: message)
        if characteristic.uuid == radiationSensorChar?.uuid {
            stopTransmiting()
        }
    }

    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        if request.characteristic.uuid == batteryLevelChar?.uuid {
            var batteryLevel: UInt8 = UInt8(arc4random() % 100)
            batteryLevelChar?.value = Data(bytes: &batteryLevel, count: MemoryLayout<UInt8>.size)
            request.value = batteryLevelChar?.value
            peripheralManager?.respond(to: request, withResult: .success)
            delegate?.serviceNotifiy(message: "New battery level=\(batteryLevel)%")
        }
    }

    public func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        requests.forEach { request in
            if request.characteristic.uuid == geigerCommandChar?.uuid {
                var command = UInt8(0)
                guard let data = request.value else {return}
                data.copyBytes(to: &command, count: MemoryLayout<UInt8>.size)
                switch command {
                case GeigerCommand.satndBy.rawValue:
                    stopTransmiting()
                    delegate?.serviceNotifiy(message: "Received command to standby")
                    break
                case GeigerCommand.on.rawValue:
                    startTransmitingReadings()
                    delegate?.serviceNotifiy(message: "Received command to turn on")
                    break
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
    case satndBy = 0
    case on
}
