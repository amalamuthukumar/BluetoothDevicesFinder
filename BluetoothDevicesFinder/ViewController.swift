//
//  ViewController.swift
//  BluetoothDevicesFinder
//
//  Created by Amala on 25/10/18.
//  Copyright © 2018 Amala. All rights reserved.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController {
    
    @IBOutlet weak var bleListTableView: UITableView!
    
    var centralManager : CBCentralManager?
    var peripherals = Array<CBPeripheral>()
    var connectedPeripheral : CBPeripheral?
    var connectedUUID : String?
    var mainCharacteristic:CBCharacteristic? = nil
    var centralManagerState: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        customiseRightNavBar()
        //initialise corebluetooth central manager
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func customiseRightNavBar(){
        self.navigationItem.rightBarButtonItem = nil
        let rightButton = UIButton()
        if (connectedPeripheral == nil) {
            rightButton.setTitle("Scan", for: [])
            rightButton.setTitleColor(UIColor.blue, for: [])
            rightButton.frame = CGRect(origin: CGPoint(x: 0,y :0), size: CGSize(width: 60, height: 30))
            rightButton.addTarget(self, action: #selector(self.scanButtonPressed), for: .touchUpInside)
        } else {
            rightButton.setTitle("Disconnect", for: [])
            rightButton.setTitleColor(UIColor.blue, for: [])
            rightButton.frame = CGRect(origin: CGPoint(x: 0,y :0), size: CGSize(width: 100, height: 30))
            rightButton.addTarget(self, action: #selector(self.disconnectButtonPressed), for: .touchUpInside)
        }
        
        let rightBarButton = UIBarButtonItem()
        rightBarButton.customView = rightButton
        self.navigationItem.rightBarButtonItem = rightBarButton
    }
    
    @objc func scanButtonPressed() {
        scanBLEDevices()
    }
    
    @objc func disconnectButtonPressed(){
        centralManager?.cancelPeripheralConnection(connectedPeripheral!)
    }
    
    func scanBLEDevices(){
        if centralManager?.state.rawValue == 5 {
            self.centralManager?.scanForPeripherals(withServices: nil, options: nil)
            //stop scanning after 10 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                self.stopScanForBLEDevices()
            }
        } else {
            let alert = UIAlertController(title: "Error!", message: centralManagerState, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            self.present(alert, animated: true)
        }
    }
    
    func stopScanForBLEDevices(){
        centralManager?.stopScan()
    }
}

extension ViewController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
            case .unknown:
                centralManagerState = "Unknown"
            case .resetting:
                centralManagerState = "Resetting"
            case .unsupported:
                centralManagerState = "Unsupported"
            case .unauthorized:
                centralManagerState = "Unauthorized"
            case .poweredOff:
                centralManagerState = "Powered Off"
            case .poweredOn:
                centralManagerState = "Powered On"
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        peripherals.append(peripheral)
        connectedUUID = (advertisementData["kCBAdvDataServiceUUIDs"] as! NSArray).firstObject as? String
        bleListTableView.reloadData()
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices(nil)
        connectedPeripheral = peripheral
        print("Connected to:\(connectedPeripheral?.name!)")
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectedPeripheral = nil
        customiseRightNavBar()
        print("Disconnected" + peripheral.name!)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("DidFailToConnect:\(error!)")
    }
}

extension ViewController: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services! {
            print("Service found with UUID..\(service.uuid.uuidString)")
            //device information service
            if service.uuid.uuidString == "180A" {
                peripheral.discoverCharacteristics(nil, for: service)
            }
            //GAP (Generic Access Profile) for Device Name
            // This replaces the deprecated CBUUIDGenericAccessProfileString
            if (service.uuid.uuidString == "1800") {
                peripheral.discoverCharacteristics(nil, for: service)
            }
            //Bluno Service
            if (service.uuid.uuidString == "DFB0") {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if (service.uuid.uuidString == "1800") {
            for characteristic in service.characteristics! {
                if (characteristic.uuid.uuidString == "2A00") {
                    peripheral.readValue(for: characteristic)
                    print("Found Device Name Characteristic")
                }
            }
        }
        if (service.uuid.uuidString == "180A") {
            for characteristic in service.characteristics! {
                if (characteristic.uuid.uuidString == "2A29") {
                    peripheral.readValue(for: characteristic)
                    print("Found a Device Manufacturer Name Characteristic")
                } else if (characteristic.uuid.uuidString == "2A25") {
                    peripheral.readValue(for: characteristic)
                    print("Found Serial Number")
                }
            }
        }
        if (service.uuid.uuidString == "DFB0") {
            for characteristic in service.characteristics! {
                if (characteristic.uuid.uuidString == "DFB1") {
                    //we'll save the reference, we need it to write data
                    mainCharacteristic = characteristic
                    //Set Notify is useful to read incoming data async
                    peripheral.setNotifyValue(true, for: characteristic)
                    print("Found Bluno Data Characteristic")
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if (characteristic.uuid.uuidString == "2A00") {
            //value for device name recieved
            let deviceName = characteristic.value
            print(deviceName ?? "No Device Name")
        } else if (characteristic.uuid.uuidString == "2A29") {
            //value for manufacturer name recieved
            let manufacturerName = characteristic.value
            print(manufacturerName ?? "No Manufacturer Name")
        } else if (characteristic.uuid.uuidString == "2A25") {
            //value for system ID recieved
            let serialNumber = characteristic.value
            print(serialNumber ?? "No Serial Number")
        } else if (characteristic.uuid.uuidString == "DFB1") {
            //data recieved
            if(characteristic.value != nil) {
                let stringValue = String(data: characteristic.value!, encoding: String.Encoding.utf8)!
                print("Received Message:\(stringValue)")
            }
        }
    }
}

extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell:UITableViewCell = self.bleListTableView.dequeueReusableCell(withIdentifier: "cell")! as UITableViewCell
        let peripheral = peripherals[indexPath.row]
        cell.textLabel?.text = peripheral.name
        return cell
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return peripherals.count
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let peripheral = peripherals[indexPath.row]
        centralManager?.connect(peripheral, options: nil)
    }
}
