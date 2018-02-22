//
//  GeigerLEService.swift
//  GeigerMeterSimulator
//
//  Created by Pablo Caif on 18/2/18.
//  Copyright © 2018 Pablo Caif. All rights reserved.
//

import Foundation
import CoreBluetooth

public class GeigerLEService: NSObject {
    
    private var peripheralManager: CBPeripheralManager?
    private var geigerMeterService :CBMutableService?
    private var radiationSensorChar :CBMutableCharacteristic?
    private let peripheralUUID = "190124D9-BB53-4ACB-9C48-F4D5F8C81668"
    private let serviceScanParametersID = "1813"
    private let analogCharID = "2A58"
    private var timer :Timer?
    
    public func startAdvertisingPeripheral() {
        if peripheralManager == nil {
            peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        }
        
        if peripheralManager?.state == .poweredOn {
            peripheralManager?.removeAllServices()
            setupServicesAndCharac()
            peripheralManager?.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [CBUUID(string: serviceScanParametersID)]])
        }
    }
    
    public func stopAdvertising() {
        timer?.invalidate()
        peripheralManager?.stopAdvertising()
        geigerMeterService = nil
        radiationSensorChar = nil
        peripheralManager = nil
    }
    
    private func setupServicesAndCharac() {
        radiationSensorChar = CBMutableCharacteristic(type: CBUUID(string: analogCharID), properties: .notify, value: nil, permissions: .readable)
        geigerMeterService = CBMutableService(type: CBUUID(string: serviceScanParametersID), primary: true)
        let descriptor = CBMutableDescriptor(type: CBUUID(string:CBUUIDCharacteristicFormatString), value: CBUUIDCharacteristicFormatString.data(using: .utf8))
        radiationSensorChar?.descriptors = [descriptor]
        geigerMeterService?.characteristics = [radiationSensorChar!]
        peripheralManager?.add(geigerMeterService!)
    }
    
    private func updateReadValue(timer: Timer) {
        let radiationReading = Float32(arc4random() % 100)
        
        let bufferLength = MemoryLayout<Float32>.size
        let buffer = UnsafeMutableRawPointer.allocate(bytes: bufferLength, alignedTo: MemoryLayout<Float32>.alignment)
        _ = buffer.initializeMemory(as: Float32.self, count: 1, to: radiationReading)
        
        defer {
            buffer.deallocate(bytes: bufferLength, alignedTo: MemoryLayout<Float32>.alignment)
        }
        let dataToSend = Data(bytes: buffer, count: bufferLength)
        
        let sent = peripheralManager?.updateValue(dataToSend, for: radiationSensorChar!, onSubscribedCentrals: nil)
        if !sent! {
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
        case .resetting:
            print("Peripheral manager reseting\n")
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
            print("Central \(central.identifier.uuidString) subscribed\n")
        }
    }
    
    public func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        print("Central \(central.identifier.uuidString) cancelled subscription")
        if characteristic.uuid == radiationSensorChar?.uuid {
            stopTransmiting()
        }
    }
    
    public func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        print("Did start advertising")
        if let errorAdvertising = error {
            print("Error advertising \(errorAdvertising.localizedDescription)")
        }
    }
    
}
