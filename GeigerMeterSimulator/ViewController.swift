//
//  ViewController.swift
//  GeigerMeterSimulator
//
//  Created by Pablo Caif on 18/2/18.
//  Copyright © 2018 Pablo Caif. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
    
    
    @IBOutlet weak var statusLabel: NSTextField!
    @IBOutlet var textViewInfo: NSTextView!
    let geigerService = GeigerLEService()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        geigerService.delegate = self
        
    }

    override func viewDidAppear() {
        view.window?.title = "Geiger Simulator"
    }
    
    override func viewWillDisappear() {
        geigerService.stopAdvertising()
    }
    
    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    @IBAction func didPressStartService(_ sender: Any) {
        geigerService.startAdvertisingPeripheral()
    }
    
    
    @IBAction func didPressStopService(_ sender: Any) {
        geigerService.stopAdvertising()
    }
}

// MARK: GeigerLEServiceDelegate
extension ViewController: GeigerLEServiceDelegate {
    func serviceNotifiy(message: String) {
        textViewInfo.textStorage!.append(NSAttributedString(string: message + "\n"))
    }
    
    
}
