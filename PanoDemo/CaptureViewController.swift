//
//  CaptureViewController.swift
//  PanoDemo
//
//  Created by Samuel Scherer on 4/28/21.
//  Copyright © 2021 RIIS. All rights reserved.
//

import Foundation
import UIKit
import DJISDK
import DJIWidget

let kNumberOfPhotosInPanorama = 8
let kRotationAngle = 45.0
let kUseBridge = true
let kBridgeIP = "192.168.128.169"

class CaptureViewController : UIViewController, DJICameraDelegate, DJIPlaybackDelegate, DJISDKManagerDelegate, DJIFlightControllerDelegate, DJIVideoFeedListener {
    
    //#define kCaptureModeAlertTag 100
    
    @IBOutlet weak var fpvPreviewView: UIView!
    @IBOutlet weak var captureBtn: UIButton!
    @IBOutlet weak var downloadBtn: UIButton!
    @IBOutlet weak var stitchBtn: UIButton!
    
    var numberSelectedPhotos = 0
    var downloadProgressAlert : UIAlertController?
    var uploadMissionProgressAlertController : UIAlertController?
    var imageArray : [UIImage]?
    var aircraftLocation : CLLocationCoordinate2D?
    var aircraftAltitude = 0.0
    var gpsSignalLevel = DJIGPSSignalLevel.levelNone
    var aircraftYaw = 0.0
    
    //MARK: - Inherited Methods
    override func viewDidLoad() {
        
        self.title = "Panorama Demo"
        self.aircraftLocation = kCLLocationCoordinate2DInvalid
        super.viewDidLoad()
        self.registerApp()
    }
    
    // Hack to allow user to see FPV view (for some reason switching camera modes fixes the view not showing initially)
    func addCameraToggleButton() {
        let testBtn = UIButton(type: UIButton.ButtonType.system)
        self.view.addSubview(testBtn)
        testBtn.translatesAutoresizingMaskIntoConstraints = false
        testBtn.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        testBtn.centerYAnchor.constraint(equalTo: self.view.centerYAnchor).isActive = true
        testBtn.widthAnchor.constraint(equalToConstant: 100).isActive = true
        testBtn.heightAnchor.constraint(equalToConstant: 50).isActive = true
        testBtn.backgroundColor = UIColor.lightGray
        testBtn.setTitle("Toggle Camera Mode", for: UIControl.State.normal)
        testBtn.addTarget(self, action: #selector(toggleCamera), for: UIControl.Event.touchUpInside)
    }

    //TODO: test this. is toggle camera btn working?
    // Hack to allow user to see FPV view (for some reason switching camera modes fixes the view not showing initially)
    @objc func toggleCamera() {
        let camera = self.fetchCamera()
        camera?.getModeWithCompletion({ (mode:DJICameraMode, error:Error?) in
            if let error = error {
                print(String(format: "Failed to get camera mode: %@", error.localizedDescription))
            } else {
                if mode == DJICameraMode.shootPhoto {
                    camera?.setMode(DJICameraMode.recordVideo, withCompletion: { (error:Error?) in
                        if let error = error {
                            print(String(format: "Failed to set camera mode: %@", error.localizedDescription))
                        }
                    })
                } else {
                    camera?.setMode(DJICameraMode.shootPhoto, withCompletion: { (error:Error?) in
                        if let error = error {
                            print(String(format: "Failed to set camera mode: %@", error.localizedDescription))
                        }
                    })
                }
            }
        })
    }

    func registerApp() {
        //Please enter the App Key in the info.plist file to register the App.
        DJISDKManager.registerApp(with: self)
    }
    
    //Pass the downloaded photos to StitchingViewController
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "Stitching" {
            if let imageArray = self.imageArray {
                segue.destination.setValue(NSMutableArray(array: self.imageArray!), forKey: "imageArray")
            }
        }
    }
    
    //MARK: - DJISDKManagerDelegate Methods
    func productConnected(_ product: DJIBaseProduct?) {
        if product != nil {
            if let camera = self.fetchCamera() {
                camera.delegate = self
                camera.playbackManager?.delegate = self
            }
        }

        if let flightController = self.fetchFlightController() {
            flightController.delegate = self
        }
        
        // If this demo is used in China, it's required to login to your DJI account to activate the application.
        // Also you need to use DJI Go app to bind the aircraft to your DJI account.
        // For more details, please check this demo's tutorial.
        DJISDKManager.userAccountManager().logIntoDJIUserAccount(withAuthorizationRequired: false) { (state:DJIUserAccountState, error:Error?) in
            if let error = error {
                print("Login failed: \(error.localizedDescription)")
            }
        }
        
        DJIVideoPreviewer.instance()?.setView(self.fpvPreviewView)
        DJISDKManager.videoFeeder()?.primaryVideoFeed.add(self, with: nil)//TODO: add logic for enterprise drones with secondary feeds (FPV demo has it i think...)
        DJIVideoPreviewer.instance()?.start()
    }

    func appRegisteredWithError(_ error: Error?) {
        var message = "Registered App Successfully!"
        
        if let error = error {
            message = String(format: "Register App Failed! Please enter your App Key and check the network. Error: %@", error.localizedDescription)
        } else {
            if kUseBridge {
                DJISDKManager.enableBridgeMode(withBridgeAppIP: kBridgeIP)
            } else {
                DJISDKManager.startConnectionToProduct()
            }
            
            DJISDKManager.videoFeeder()?.primaryVideoFeed.add(self, with: nil)
            DJIVideoPreviewer.instance()?.start()
        }
        self.showAlertWith(title:"Register App", message:message)
    }
    
    //MARK: - DJIVideoFeedListener
    func videoFeed(_ videoFeed: DJIVideoFeed, didUpdateVideoData rawData: Data) {
        let videoData = rawData as NSData
        let videoBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: videoData.length)
        videoData.getBytes(videoBuffer, length: videoData.length)
        DJIVideoPreviewer.instance().push(videoBuffer, length: Int32(videoData.count))
    }

    //MARK: - DJIPlaybackDelegate
    func playbackManager(_ playbackManager: DJIPlaybackManager, didUpdate playbackState: DJICameraPlaybackState) {
        self.numberSelectedPhotos = Int(playbackState.selectedFileCount)
    }
    
    //MARK: - DJIFlightControllerDelegate Method
    func flightController(_ fc: DJIFlightController, didUpdate state: DJIFlightControllerState) {
        self.aircraftLocation = CLLocationCoordinate2DMake(state.aircraftLocation?.coordinate.latitude ?? 0, state.aircraftLocation?.coordinate.longitude ?? 0)
        self.gpsSignalLevel = state.gpsSignalLevel
        self.aircraftAltitude = state.altitude
        self.aircraftYaw = state.attitude.yaw
    }

    //MARK: - Custom Methods
    func cleanVideoPreview() {
        DJIVideoPreviewer.instance()?.setView(nil)
        DJISDKManager.videoFeeder()?.primaryVideoFeed.remove(self)
        
        // TODO: make this swifty
        if self.fpvPreviewView != nil {
            self.fpvPreviewView.removeFromSuperview()
            self.fpvPreviewView = nil
        }
    }

    func fetchFlightController() -> DJIFlightController? {
        let aircraft = DJISDKManager.product() as? DJIAircraft
        return aircraft?.flightController
    }
    
    func fetchCamera() -> DJICamera? {
        return DJISDKManager.product()?.camera
    }

    func fetchGimbal() -> DJIGimbal? {
        return DJISDKManager.product()?.gimbal
    }

    func showAlertWith(title:String, message:String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        let okAction = UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil)
        alert.addAction(okAction)
        self.present(alert, animated: true, completion: nil)
    }
    
//MARK: - Shoot Panorama By Rotating Aircraft Methods
    func shootPanoRotateAircraft() {
        print("SS called shootPanoRotateAircraft")
        if DJISDKManager.product()?.model == DJIAircraftModelNameSpark {
            //TODO: add spark logic
            print("TODO: add spark logic")
//        [[DJISDKManager missionControl].activeTrackMissionOperator setGestureModeEnabled:NO withCompletion:^(NSError * _Nullable error) {
//            weakReturn(target);
//            if (error) {
//                NSLog(@"Set Gesture mode enabled failed");
//            } else {
//                [target setCameraModeToShootPhoto];
//            }
//        }];
        } else {
            self.setCameraModeToShootPhoto()//TODO: rename to something appropriate
        }
    }

    func setCameraModeToShootPhoto() {
        let camera = self.fetchCamera()
        camera?.getModeWithCompletion({ [weak self] (mode:DJICameraMode, error:Error?) in
            if error == nil {
                if mode == DJICameraMode.shootPhoto {
                    self?.enableVirtualStick()
                } else {
                    //TODO: is [weak self] necessay in the second closure?
                    camera?.setMode(DJICameraMode.shootPhoto, withCompletion: { [weak self] (error:Error?) in
                        if error == nil {
                            self?.enableVirtualStick()
                        }
                    })
                }
            }
        })
    }
    
    func enableVirtualStick() {//TODO: rename something appropriate
        if let flightController = self.fetchFlightController() {
            flightController.yawControlMode = DJIVirtualStickYawControlMode.angle
            flightController.rollPitchCoordinateSystem = DJIVirtualStickFlightCoordinateSystem.ground
            flightController.setVirtualStickModeEnabled(true) { [weak self] (error:Error?) in
                if let error = error {
                    print("Enable VirtualStickControlMode Failed with error: \(error.localizedDescription)")
                } else {
                    DispatchQueue.main.async { [weak self] () in //Again, need to call weak self from closure inside closure?
                        self?.executeVirtualStickControl()
                    }
                }
            }
        }
    }
    
    func executeVirtualStickControl() {
        print("called executeVirtualStickControl")
        //__weak DJICamera *camera = [self fetchCamera];
        let camera = self.fetchCamera()
        
        for photoNumber in 0 ..< kNumberOfPhotosInPanorama {
            //Filter the angle between -180 ~ 0, 0 ~ 180
            var yawAngle = kRotationAngle * Double(photoNumber)
            if yawAngle > 180.0 {
                yawAngle = yawAngle - 360.0
            }
            
            let timer = Timer(timeInterval: 0.2, target: self, selector: #selector(rotateDrone), userInfo: ["YawAngle":yawAngle], repeats: true)

            timer.fire()

            RunLoop.current.add(timer, forMode: RunLoop.Mode.default)
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 2))
            timer.invalidate()
            
            //TODO: how to destroy the timer?
            //        timer = nil;
            
            print("SS Shooting photo nunber \(photoNumber)")
            camera?.startShootPhoto(completion: { (error:Error?) in
                if let error = error {
                    print("SS Failed to shoot photo: \(error.localizedDescription)")
                } else {
                    print("SS Shot Photo!")
                }
            })
            
            sleep(2)
        }

        let flightController = self.fetchFlightController()
        if let flightController = flightController {
            flightController.setVirtualStickModeEnabled(false) { [weak self] (error:Error?) in
                if let error = error {
                    print("Disable VirtualStickControlMode Failed with error: \(error.localizedDescription)")
                    print("Retrying...")
                    if let flightController = self?.fetchFlightController() {
                        flightController.setVirtualStickModeEnabled(false, withCompletion: nil)
                    }
                }
            }
        }

        DispatchQueue.main.async { [weak self] () in
            self?.showAlertWith(title: "Capture Photos", message: "Capture finished")
        }
    }

    @objc func rotateDrone(timer:Timer) {
        guard let timerUserInfoDictionary = timer.userInfo as? [String:Float] else { return }
        guard let yawAngle = timerUserInfoDictionary["YawAngle"] else { return }
        let flightController = self.fetchFlightController()
        let vsFlightControlData = DJIVirtualStickFlightControlData(pitch: 0,
                                                                   roll: 0,
                                                                   yaw: yawAngle,
                                                                   verticalThrottle: 0)
        flightController?.isVirtualStickAdvancedModeEnabled = true
        flightController?.send(vsFlightControlData, withCompletion: { (error:Error?) in
            if let error = error {
                print("Send FlightControl Data Failed: \(error.localizedDescription)")
            }
        })
    }

    //MARK: - Shoot Panorama By Rotating Gimbal Methods
    func shootPanoRotateGimbal() {
        guard let camera = self.fetchCamera() else {
            print("fetchCamera returned nil")
            return
        }
        camera.setMode(DJICameraMode.shootPhoto) { [weak self] (error:Error?) in
            if error == nil {
                DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                    self?.executeRotateGimbal()
                }
            }
        }
    }
    
    func executeRotateGimbal() {
        guard let gimbal = self.fetchGimbal() else {return}
        guard let camera = self.fetchCamera() else {return}
        
        //Reset Gimbal at the beginning
        gimbal.reset { (error:Error?) in
            if let error = error {
                print("ResetGimbal Failed: \(error.localizedDescription)")
            }
        }
        sleep(3)
        
        //rotate the gimbal clockwise
        var yawAngle = 0.0
        
        for photoNumber in 0 ..< kNumberOfPhotosInPanorama {
            print("SS Start Shoot Photo \(photoNumber)")
            
            camera.setShootPhotoMode(DJICameraShootPhotoMode.single) { (error:Error?) in
                //dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()) {
                    camera.startShootPhoto { (error:Error?) in
                        if let error = error {
                            print("SS ShootPhotoError: \(error.localizedDescription)")
                        } else {
                            print("SS Successfully Shot Photo")
                        }
                    }
                }
            }
            sleep(2)

            yawAngle = yawAngle + kRotationAngle
            if yawAngle > 180.0 {
                yawAngle = yawAngle - 360.0
            }
            
            let yawRotation = NSNumber(value:yawAngle)
            
            let rotation = DJIGimbalRotation(pitchValue: 0,
                                             rollValue: 0,
                                             yawValue: yawRotation,
                                             time: 1,
                                             mode: DJIGimbalRotationMode.absoluteAngle,
                                             ignore: false)
            
            gimbal.rotate(with: rotation) { (error:Error?) in
                if let error = error {
                    print("SS Rotation Error: \(error.localizedDescription)")
                }
            }
            
            sleep(2)
        }

        DispatchQueue.main.async { [weak self] () in
            self?.showAlertWith(title: "Capture Photos", message: "Capture finished")
        }
    }
    
    //MARK: - Rotate Drone With Waypoint Mission Methods
    func missionOperator() -> DJIWaypointMissionOperator? {
        return DJISDKManager.missionControl()?.waypointMissionOperator()
    }

    func shootPanoWaypointMission() {
        guard let aircraftLocation = self.aircraftLocation else { return }
        if (CLLocationCoordinate2DIsValid(aircraftLocation)) && (self.gpsSignalLevel != DJIGPSSignalLevel.level0) && (self.gpsSignalLevel != DJIGPSSignalLevel.level1) {
            self.uploadWaypointMission()
        } else {
            self.showAlertWith(title: "GPS signal weak", message: "Rotate drone failed")
        }
    }
    
    func initializeMission() {
        let mission = DJIMutableWaypointMission()
        mission.maxFlightSpeed = 15.0
        mission.autoFlightSpeed = 4.0
        
        guard let aircraftLocation = self.aircraftLocation else { return }
        let waypoint1 = DJIWaypoint(coordinate: aircraftLocation)
        waypoint1.altitude = Float(self.aircraftAltitude)

        for photoNumber in 0..<kNumberOfPhotosInPanorama {
            var rotateAngle = Int16(photoNumber) * Int16(kRotationAngle)
            if rotateAngle > 180 {
                rotateAngle = rotateAngle - 360
            }
            
            let shootPhotoAction = DJIWaypointAction(actionType: DJIWaypointActionType.shootPhoto, param: 0)
            let rotateAction = DJIWaypointAction(actionType: DJIWaypointActionType.rotateAircraft, param: rotateAngle)
            waypoint1.add(shootPhotoAction)
            waypoint1.add(rotateAction)
            
        }
        
        let waypoint2 = DJIWaypoint(coordinate: aircraftLocation)
        waypoint2.altitude = Float(self.aircraftAltitude + 1.0)
        mission.add(waypoint1)
        mission.add(waypoint2)
        
        //Change the default action of Go Home to None
        mission.finishedAction = DJIWaypointMissionFinishedAction.noAction

        self.missionOperator()?.load(mission)
        
        self.missionOperator()?.addListener(toUploadEvent: self, with: DispatchQueue.main, andBlock: { [weak self] (event:DJIWaypointMissionUploadEvent) in
            if event.currentState == DJIWaypointMissionState.uploading {
                guard let progress = event.progress else { return }
                let message = "Uploaded Waypoint Index: \(progress.uploadedWaypointIndex + 1), Total Waypoints: \(progress.totalWaypointCount)"
                
                if let _ = self?.uploadMissionProgressAlertController {
                    self?.uploadMissionProgressAlertController?.message = message
                } else {
                    let uploadMissionProgressAC = UIAlertController(title: nil, message: message, preferredStyle: UIAlertController.Style.alert)
                    self?.uploadMissionProgressAlertController = uploadMissionProgressAC
                    self?.present(uploadMissionProgressAC, animated: true, completion: nil)
                }
            } else if event.currentState == DJIWaypointMissionState.readyToExecute {
                self?.uploadMissionProgressAlertController?.dismiss(animated: true, completion: nil)
                self?.uploadMissionProgressAlertController = nil
                
                let finishedAlertController = UIAlertController(title: "Upload Mission Finished",
                                                                message: nil,
                                                                preferredStyle: UIAlertController.Style.alert)
                let startMissionAction = UIAlertAction(title: "Start Mission", style: UIAlertAction.Style.default) { [weak self] (_) in
                    self?.startWaypointMission()
                }
                
                let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertAction.Style.default, handler: nil)
                finishedAlertController.addAction(startMissionAction)
                finishedAlertController.addAction(cancelAction)
                self?.present(finishedAlertController, animated: true, completion: nil)
            }
        })
        
        self.missionOperator()?.addListener(toFinished: self, with: DispatchQueue.main, andBlock: { [weak self] (error:Error?) in
            if let error = error {
                self?.showAlertWith(title: "Mission Execution Failed", message: error.localizedDescription)
            } else {
                self?.showAlertWith(title: "Mission Execution Finished", message: "")

            }
        })
    }

    func uploadWaypointMission() {
        self.initializeMission()
        
        self.missionOperator()?.uploadMission(completion: { (error:Error?) in
            if let error = error {
                print("Upload Mission Failed: \(error.localizedDescription)")
            } else {
                print("Upload Mission Finished")
            }
        })
    }
    
    func startWaypointMission() {
        self.missionOperator()?.startMission(completion: { (error:Error?) in
            if let error = error {
                self.showAlertWith(title: "Start Mission Failed", message: error.localizedDescription)
            } else {
                self.showAlertWith(title: "Start Mission Success", message: "")
            }
        })
    }

    //MARK: - Select the lastest photos for Panorama
    func selectPhotosForPlaybackMode() {
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async { [weak self] in
            print("in closure")
            let camera = self?.fetchCamera()
            camera?.playbackManager?.enterMultiplePreviewMode()
            sleep(1)
            camera?.playbackManager?.enterMultipleEditMode()
            sleep(1)
            
            guard let self = self else { return }
            while self.numberSelectedPhotos != kNumberOfPhotosInPanorama {
                camera?.playbackManager?.selectAllFilesInPage()
                sleep(1)
                
                if self.numberSelectedPhotos > kNumberOfPhotosInPanorama {
                    for unselectFileIndex in 0 ..< kNumberOfPhotosInPanorama {
                        camera?.playbackManager?.toggleFileSelection(at: Int32(unselectFileIndex))
                        sleep(1)
                    }
                    break
                } else if self.numberSelectedPhotos < kNumberOfPhotosInPanorama {
                    camera?.playbackManager?.goToPreviousMultiplePreviewPage()
                    sleep(1)
                }
             }
            self.downloadPhotosForPlaybackMode()
        }
    }
    
    //MARK: - Download the selected photos
    func downloadPhotosForPlaybackMode() {
        var finishedFileCount = 0
        var downloadedFileData = Data()
        var totalFileSize = 0
        var targetFileName : String?

        self.imageArray = [UIImage]()

        guard let camera = self.fetchCamera() else {return}

        camera.playbackManager?.downloadSelectedFiles(preparation: { [weak self] (fileName:String?, fileType:DJIDownloadFileType, fileSize:UInt, skip:UnsafeMutablePointer<ObjCBool>) in
            totalFileSize = Int(fileSize)
            downloadedFileData = Data()
            targetFileName = fileName
            DispatchQueue.main.async { [weak self] () in
                self?.showDownloadProgressAlert()
                self?.downloadProgressAlert?.title = "Download (\(finishedFileCount + 1)/\(kNumberOfPhotosInPanorama)"
                self?.downloadProgressAlert?.message = String(format:"FileName:%@ FileSize:%0.1KB Downloaded:0.0KB", fileName ?? "", Float(fileSize) / 1024.0)
            }
        }, process: { (data:Data?, error:Error?) in
            if let data = data {
                downloadedFileData.append(data)
            }
            DispatchQueue.main.async {
                let fileName = targetFileName ?? ""
                let fileSize = Float(totalFileSize) / 1024.0
                let downloadedSize = Float(downloadedFileData.count) / 1024.0
                self.downloadProgressAlert?.message = String(format:"FileName:%@ FileSize:%0.1fKB Downloaded:%0.1fKB", fileName, fileSize, downloadedSize)
            }
        }, fileCompletion: { [weak self] in
            finishedFileCount = finishedFileCount + 1
            if let downloadPhoto = UIImage(data: downloadedFileData) {
                self?.imageArray?.append(downloadPhoto)
            }
        }, overallCompletion: { (error:Error?) in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.downloadProgressAlert?.dismiss(animated: true, completion: nil)
                self.downloadProgressAlert = nil
                //TODO: do these 3 alert controllers need an ok button?
                if let error = error {
                    let downloadFailController = UIAlertController(title: "Download failed",
                                                                  message: error.localizedDescription,
                                                                  preferredStyle: UIAlertController.Style.alert)
                    self.present(downloadFailController, animated: true, completion: nil)
                } else {
                    let downloadFinishController = UIAlertController(title: "Download (\(finishedFileCount)/\(kNumberOfPhotosInPanorama)",
                                                                     message: "download finished",
                                                                     preferredStyle: UIAlertController.Style.alert)
                    self.present(downloadFinishController, animated: true, completion: nil)
                }
                
                let camera = self.fetchCamera()
                camera?.setMode(DJICameraMode.shootPhoto, withCompletion: { (error:Error?) in
                    if let error = error {
                        let cameraModeFailController = UIAlertController(title: "Set CameraMode to ShootPhoto Failed",
                                                                      message: error.localizedDescription,
                                                                      preferredStyle: UIAlertController.Style.alert)
                        self.present(cameraModeFailController, animated: true, completion: nil)
                    }
                })
            }
            
        })
    }

    func loadMediaListsForMediaDownloadMode() {
        self.showDownloadProgressAlert()
        self.downloadProgressAlert?.title = "Refreshing file list. "
        self.downloadProgressAlert?.message = "Loading..."
        
        let camera = self.fetchCamera()
        camera?.mediaManager?.refreshFileList(of: DJICameraStorageLocation.sdCard, withCompletion: { [weak self] (error:Error?) in
            if let error = error {
                self?.downloadProgressAlert?.dismiss(animated: true, completion: nil)
                self?.downloadProgressAlert = nil
                print("Refresh file list failed: \(error.localizedDescription)")
            } else {
                self?.downloadPhotosForMediaDownloadMode()
            }
        })
    }

    func downloadPhotosForMediaDownloadMode() {
        var finishedFileCount = 0

        self.imageArray = [UIImage]()

        guard let camera = self.fetchCamera() else { return }
        guard let files = camera.mediaManager?.sdCardFileListSnapshot() else { return }
        if files.count < kNumberOfPhotosInPanorama {
            self.downloadProgressAlert?.dismiss(animated: true, completion: nil)
            self.downloadProgressAlert = nil
            let downloadFailedController = UIAlertController(title: "Download Failed", message: "Not enough photos are taken. ", preferredStyle: UIAlertController.Style.alert)
            self.present(downloadFailedController, animated: true, completion: nil)
            return
        }

        camera.mediaManager?.taskScheduler.resume(completion: { [weak self] (error:Error?) in
            if let error = error {
                self?.downloadProgressAlert?.dismiss(animated: true, completion: nil)
                self?.downloadProgressAlert = nil
                let downloadFailedController = UIAlertController(title: "Download failed",
                                                  message: "Resume file task scheduler failed. ",
                                                  preferredStyle: UIAlertController.Style.alert)
                self?.present(downloadFailedController, animated: true, completion: nil)
            }
        })
        
        self.downloadProgressAlert?.title = "Downloading..."
        self.downloadProgressAlert?.message = "Download (0/\(kNumberOfPhotosInPanorama))"

        for i in (files.count - kNumberOfPhotosInPanorama) ..< files.count {
            let file = files[i]
            
            let task = DJIFetchMediaTask.init(file: file, content: DJIFetchMediaTaskContent.preview) { [weak self] (file:DJIMediaFile, content:DJIFetchMediaTaskContent, error:Error?) in
                guard let self = self else { return }
                if let error = error {
                    self.downloadProgressAlert?.dismiss(animated: true, completion: nil)
                    self.downloadProgressAlert = nil
                    let downloadFailController = UIAlertController(title: "Download failed",
                                                                   message: "Download file \(file.fileName) failed. ",
                                                                   preferredStyle: .alert)
                } else {
                    if let image = file.preview {
                        self.imageArray?.append(image)
                    }

                    finishedFileCount = finishedFileCount + 1
                    self.downloadProgressAlert?.message = "Download (\(finishedFileCount)/\(kNumberOfPhotosInPanorama))"

                    if finishedFileCount == kNumberOfPhotosInPanorama {
                        self.downloadProgressAlert?.dismiss(animated: true, completion: nil)
                        self.downloadProgressAlert = nil
                        let downloadCompleteController = UIAlertController(title: "Download Complete",
                                                                           message: "\(kNumberOfPhotosInPanorama) files have been downloaded. ",
                                                                           preferredStyle: UIAlertController.Style.alert)
                        let okAction = UIAlertAction(title: "OK", style: .cancel) { (action:UIAlertAction) in
                            downloadCompleteController.dismiss(animated: true, completion: nil)
                        }
                        downloadCompleteController.addAction(okAction)
                        self.present(downloadCompleteController, animated: true, completion: nil)
                        
                        camera.setMode(DJICameraMode.shootPhoto) { (error:Error?) in
                            if let error = error {
                                let setCameraModeFailController = UIAlertController(title: "Set CameraMode to ShootPhoto Failed",
                                                                                   message: error.localizedDescription,
                                                                                   preferredStyle: UIAlertController.Style.alert)
                                self.present(setCameraModeFailController, animated: true, completion: nil)
                            }
                        }
                    }
                }
            }
            camera.mediaManager?.taskScheduler.moveTask(toEnd: task)
        }
    }

    func showDownloadProgressAlert() {
        if self.downloadProgressAlert == nil {
            let downloadProgressAC = UIAlertController(title: "", message: "", preferredStyle: UIAlertController.Style.alert)
            self.downloadProgressAlert = downloadProgressAC
            self.present(downloadProgressAC, animated: true, completion: nil)
        }
    }

    //MARK: - IBAction Methods
    @IBAction func onCaptureButtonClicked(_ sender: Any) {
        let alertController = UIAlertController(title: "Select Mode", message: "", preferredStyle: UIAlertController.Style.alert)
        let rotateAircraftAction = UIAlertAction(title: "Rotate Aircraft", style: UIAlertAction.Style.default) { [weak self] (action:UIAlertAction) in
            self?.shootPanoRotateAircraft()
        }
        let rotateGimbalAction = UIAlertAction(title: "Rotate Gimbal", style: UIAlertAction.Style.default) { [weak self] (action:UIAlertAction) in
            self?.shootPanoRotateAircraft()
        }
        let waypointMissionAction = UIAlertAction(title: "Waypoint Mission", style: UIAlertAction.Style.default) { [weak self] (action:UIAlertAction) in
            self?.shootPanoRotateAircraft()
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (action:UIAlertAction) in
            alertController.dismiss(animated: true, completion: nil)
        }
        
        alertController.addAction(rotateAircraftAction)
        alertController.addAction(rotateGimbalAction)
        alertController.addAction(waypointMissionAction)
        alertController.addAction(cancelAction)
        
        self.present(alertController, animated: true, completion: nil)
    }
    @IBAction func onDownloadButtonClicked(_ sender: Any) {
        guard let camera = self.fetchCamera() else { return }
        if camera.isPlaybackSupported() {
            camera.setMode(DJICameraMode.playback) { [weak self] (error:Error?) in
                if let error = error {
                    print("Enter playback mode failed: \(error.localizedDescription)")
                } else {
                    self?.selectPhotosForPlaybackMode()
                }
            }
        } else if camera.isMediaDownloadModeSupported() {
            camera.setMode(DJICameraMode.mediaDownload) { [weak self] (error:Error?) in
                if let error = error {
                    print("Enter Media Download mode failed: \(error.localizedDescription)")
                } else {
                    self?.loadMediaListsForMediaDownloadMode()
                }
            }
        }
    }
    
    func didUpdateDatabaseDownloadProgress(_ progress: Progress) {
        //TODO:unused?
    }

}
