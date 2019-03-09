//
//  ViewController.swift
//  BLE-ESP32-Download
//
//  Created by Ryan Detzel on 3/9/19.
//  Copyright © 2019 Ryan Detzel. All rights reserved.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate {
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!

    var centralManager: CBCentralManager?
    var peripheral: CBPeripheral?
    var dumpDataCharacteristic: CBCharacteristic?

    let serviceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    let dataUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    let readUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")

    var size: UInt16 = 0;
    var allData: Data = Data(capacity: 1)

    override func viewDidLoad() {
        super.viewDidLoad()

        let centralQueue: DispatchQueue = DispatchQueue(label: "com.ryandetzel.BLE", attributes: .concurrent)
        centralManager = CBCentralManager(delegate: self, queue: centralQueue)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .unknown:
            print("Bluetooth status is UNKNOWN")
        case .resetting:
            print("Bluetooth status is RESETTING")
        case .unsupported:
            print("Bluetooth status is UNSUPPORTED")
        case .unauthorized:
            print("Bluetooth status is UNAUTHORIZED")
        case .poweredOff:
            print("Bluetooth status is POWERED OFF")
        case .poweredOn:
            print("Bluetooth status is POWERED ON")
            centralManager?.scanForPeripherals(withServices: [serviceUUID])
        } // END switch
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {

        print(peripheral.name!)
        self.peripheral = peripheral
        self.peripheral?.delegate = self

        centralManager?.stopScan()
        centralManager?.connect(self.peripheral!)

    } // END func centralManager(... didDiscover peripheral

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        self.peripheral?.discoverServices([serviceUUID])
    } // END func centralManager(... didConnect peripheral

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected!")
        centralManager?.scanForPeripherals(withServices: [serviceUUID])
    } // END func centralManager(... didDisconnectPeripheral peripheral

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services! {
            if service.uuid == serviceUUID {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    } // END func peripheral(... didDiscoverServices

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for characteristic in service.characteristics! {
            if characteristic.uuid == readUUID {
                // Read how many bytes we should read from the esp32.
                peripheral.readValue(for: characteristic)
            }else if characteristic.uuid == dataUUID {
                dumpDataCharacteristic = characteristic
            }
        } // END for
    } // END func peripheral(... didDiscoverCharacteristicsFor service


    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {

        if characteristic.uuid == readUUID {
            let data = characteristic.value!
            let value = data.withUnsafeBytes { (ptr: UnsafePointer<UInt16>) -> UInt16 in
                return ptr.pointee
            }
            print("Should read \(value) bytes")
            size = value
            allData.removeAll()
            progressView.setProgress(0.0, animated: false);

            let dump = "dump".data(using: .utf8)!
            peripheral.writeValue(dump, for: dumpDataCharacteristic!, type: CBCharacteristicWriteType.withResponse)
            peripheral.setNotifyValue(true, for: dumpDataCharacteristic!)
        } else if characteristic.uuid == dataUUID {
            let data = characteristic.value!
            allData.append(data)

            DispatchQueue.main.async { () -> Void in
                self.statusLabel?.text = "\(self.allData.count) bytes";
                let progressPct = Float(self.allData.count) / Float(self.size);
                self.progressView.setProgress(progressPct, animated: true);
            };

            if (allData.count >= size){
                print("All done reading \(allData.count) bytes")
                peripheral.setNotifyValue(false, for: dumpDataCharacteristic!)

                // We should verify the data.
                print(allData[0]);
                print(allData[allData.count-1]);
//                for n in 0...allData.count-1 {
//                    print(allData[n]);
//                }
            }
        } // END if characteristic.uuid ==...
    } // END func peripheral(... didUpdateValueFor characteristic
}
