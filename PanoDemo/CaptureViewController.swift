//
//  CaptureViewController.swift
//  PanoDemo
//
//  Created by Samuel Scherer on 4/28/21.
//  Copyright © 2021 DJI. All rights reserved.
//

import Foundation
import UIKit
import DJISDK
import DJIWidget

class CaptureViewController : UIViewController, DJICameraDelegate, DJIPlaybackDelegate, DJISDKManagerDelegate, DJIFlightControllerDelegate, DJIVideoFeedListener {
    
    //#define PHOTO_NUMBER 8
    let numberOfPhotos = 8
    //#define ROTATE_ANGLE 45
    let rotationAngle = 45.0
    
    let useBridge = true
    let bridgeIP = "192.168.128.169"
    
    //#define kCaptureModeAlertTag 100
    
    @IBOutlet weak var fpvPreviewView: UIView!
    @IBOutlet weak var captureBtn: UIButton!
    @IBOutlet weak var downloadBtn: UIButton!
    @IBOutlet weak var stitchBtn: UIButton!
    
    //@property (nonatomic, assign) __block int numberSelectedPhotos;
    var numberSelectedPhotos : Int?
    //@property (strong, nonatomic) UIAlertView* downloadProgressAlert;
    var downloadProgressAlert : UIAlertController?
    //@property (strong, nonatomic) UIAlertView* uploadMissionProgressAlert;
    var uploadMissionProgressAlertController : UIAlertController?
    //@property (strong, nonatomic) NSMutableArray* imageArray;
    var imageArray : [UIImage]?
    //@property (atomic) CLLocationCoordinate2D aircraftLocation;
    var aircraftLocation : CLLocationCoordinate2D?
    //@property (atomic) double aircraftAltitude;
    var aircraftAltitude = 0.0
    //@property (atomic) DJIGPSSignalLevel gpsSignalLevel;
    var gpsSignalLevel = DJIGPSSignalLevel.levelNone
    //@property (atomic) double aircraftYaw;
    var aircraftYaw = 0.0
    
    //MARK: - Inherited Methods
    //
    //- (void)viewDidLoad {
    //    [super viewDidLoad];
    //
    //    self.title = @"Panorama Demo";
    //    self.aircraftLocation = kCLLocationCoordinate2DInvalid;
    //
    //    [self registerApp];
    //
    //}
    
    override func viewDidLoad() {
        
        self.title = "Panorama Demo"
        self.aircraftLocation = kCLLocationCoordinate2DInvalid
        super.viewDidLoad()
        self.registerApp()
    }
    
    // Hack to allow user to see FPV view (for some reason switching camera modes fixes the view not showing initially)
    func addCameraToggleButton() {
        //    UIButton *testBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        let testBtn = UIButton(type: UIButton.ButtonType.system)
        //    [self.view addSubview:testBtn];
        self.view.addSubview(testBtn)
        //    testBtn.translatesAutoresizingMaskIntoConstraints = NO;
        testBtn.translatesAutoresizingMaskIntoConstraints = false
        //    [testBtn.leftAnchor constraintEqualToAnchor:self.view.leftAnchor].active = YES;
        testBtn.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        //    [testBtn.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor].active = YES;
        testBtn.centerYAnchor.constraint(equalTo: self.view.centerYAnchor).isActive = true
        //    [testBtn.widthAnchor constraintEqualToConstant:50.0].active = YES;
        testBtn.widthAnchor.constraint(equalToConstant: 100).isActive = true
        //    [testBtn.heightAnchor constraintEqualToConstant:50.0].active = YES;
        testBtn.heightAnchor.constraint(equalToConstant: 50).isActive = true
        //    testBtn.titleLabel.textColor = UIColor.blackColor;
        //testBtn.titleLabel?.textColor = UIColor.black
        //    testBtn.backgroundColor = UIColor.grayColor;
        testBtn.backgroundColor = UIColor.lightGray
        //    [testBtn setEnabled:YES];//TODO: necessary?
        //    [testBtn setTitle:@"test" forState:UIControlStateNormal];
        testBtn.setTitle("Toggle Camera Mode", for: UIControl.State.normal)
        testBtn.addTarget(self, action: #selector(toggleCamera), for: UIControl.Event.touchUpInside)
        //    [testBtn addTarget:self action:@selector(testBtnAction) forControlEvents:UIControlEventTouchUpInside];
    }

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
//-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
//    if([segue.identifier isEqualToString:@"Stitching"]) {
//        [segue.destinationViewController setValue:self.imageArray forKey:@"imageArray"];
//    }
//}
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "Stitching" {
            segue.destination.setValue(self.imageArray, forKey: "imageArray")
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
        
        //    [[DJIVideoPreviewer instance] setView:self.fpvPreviewView];
        DJIVideoPreviewer.instance()?.setView(self.fpvPreviewView)
        //    [[DJISDKManager videoFeeder].primaryVideoFeed addListener:self withQueue:nil];
        DJISDKManager.videoFeeder()?.primaryVideoFeed.add(self, with: nil)//TODO: add logic for enterprise drones with secondary feeds (FPV demo has it i think...)
        //    [[DJIVideoPreviewer instance] start];
        DJIVideoPreviewer.instance()?.start()
    }

    func appRegisteredWithError(_ error: Error?) {
        var message = "Registered App Successfully!"
        
        if let error = error {
            message = String(format: "Register App Failed! Please enter your App Key and check the network. Error: %@", error.localizedDescription)
        } else {
            if useBridge {
                DJISDKManager.enableBridgeMode(withBridgeAppIP: bridgeIP)
            } else {
                DJISDKManager.startConnectionToProduct()
            }
            
            DJISDKManager.videoFeeder()?.primaryVideoFeed.add(self, with: nil)
            DJIVideoPreviewer.instance()?.start()
        }
        self.showAlertWith(title:"Register App", message:message)
    }
    
    //MARK: - DJIVideoFeedListener
    func videoFeed(_ videoFeed: DJIVideoFeed, didUpdateVideoData videoData: Data) {
        //[[DJIVideoPreviewer instance] push:(uint8_t *)videoData.bytes length:(int)videoData.length];
    }

    //MARK: - DJIPlaybackDelegate
    func playbackManager(_ playbackManager: DJIPlaybackManager, didUpdate playbackState: DJICameraPlaybackState) {
        //self.numberSelectedPhotos = playbackState.selectedFileCount;
    }
    
    //MARK: - DJIFlightControllerDelegate Method
    func flightController(_ fc: DJIFlightController, didUpdate state: DJIFlightControllerState) {
        //    self.aircraftLocation = CLLocationCoordinate2DMake(state.aircraftLocation.coordinate.latitude, state.aircraftLocation.coordinate.longitude);
        self.aircraftLocation = CLLocationCoordinate2DMake(state.aircraftLocation?.coordinate.latitude ?? 0, state.aircraftLocation?.coordinate.longitude ?? 0)
        //    self.gpsSignalLevel = state.GPSSignalLevel;
        self.gpsSignalLevel = state.gpsSignalLevel
        //    self.aircraftAltitude = state.altitude;
        self.aircraftAltitude = state.altitude
        //    self.aircraftYaw = state.attitude.yaw;
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
        //    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        //    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
        let okAction = UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil)
        //    [alert addAction:okAction];
        alert.addAction(okAction)
        //    [self presentViewController:alert animated:YES completion:nil];
        self.present(alert, animated: true, completion: nil)
    }
    
//MARK: - Shoot Panorama By Rotating Aircraft Methods
    func shootPanoRotateAircraft() {
        print("SS called shootPanoRotateAircraft")
        if DJISDKManager.product()?.model == DJIAircraftModelNameSpark {
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
        //    DJICamera *camera = [target fetchCamera];
        //    [camera getModeWithCompletion:^(DJICameraMode mode, NSError * _Nullable error) {
        //        if (error == nil) {
        //            if (mode == DJICameraModeShootPhoto) {
        //                [target enableVirtualStick];
        //            }
        //            else {
        //                [camera setMode:DJICameraModeShootPhoto withCompletion:^(NSError * _Nullable error) {
        //                    weakReturn(target);
        //                    if (error == nil) {
        //                        [target enableVirtualStick];
        //                    }
        //                }];
        //            }
        //        }
        //    }];
        print("called setCameraModeToShootPhoto")
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
        //    DJIFlightController *flightController = [self fetchFlightController];
        //    [flightController setYawControlMode:DJIVirtualStickYawControlModeAngle];
        //    [flightController setRollPitchCoordinateSystem:DJIVirtualStickFlightCoordinateSystemGround];
        //    [flightController setVirtualStickModeEnabled:YES withCompletion:^(NSError * _Nullable error) {
        //        if (error) {
        //            NSLog(@"Enable VirtualStickControlMode Failed");
        //        }
        //        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //            [self executeVirtualStickControl];
        //        });
        //    }];
        print("called enableVirtualStick")
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
//    __weak DJICamera *camera = [self fetchCamera];
        let camera = self.fetchCamera()
        
//    for(int i = 0;i < PHOTO_NUMBER; i++){
        for photoNumber in 0 ..< numberOfPhotos {
            //Filter the angle between -180 ~ 0, 0 ~ 180
            var yawAngle = rotationAngle * Double(photoNumber)
            if yawAngle > 180.0 {
                yawAngle = yawAngle - 360.0
            }
    //
    //        NSTimer *timer =  [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(rotateDrone:) userInfo:@{@"YawAngle":@(yawAngle)} repeats:YES];
            var timer = Timer(timeInterval: 0.2, target: self, selector: #selector(rotateDrone), userInfo: ["YawAngle":yawAngle], repeats: true)
    //        [timer fire];
            timer.fire()
    //
    //        [[NSRunLoop currentRunLoop]addTimer:timer forMode:NSDefaultRunLoopMode];
    //        [[NSRunLoop currentRunLoop]runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2]];
    //        [timer invalidate];

            RunLoop.current.add(timer, forMode: RunLoop.Mode.default)
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 2))
            timer.invalidate()
    //
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

//    DJIFlightController *flightController = [self fetchFlightController];
//    [flightController setVirtualStickModeEnabled:NO withCompletion:^(NSError * _Nullable error) {
//        if (error) {
//            NSLog(@"Disable VirtualStickControlMode Failed");
//            DJIFlightController *flightController = [self fetchFlightController];
//            [flightController setVirtualStickModeEnabled:NO withCompletion:nil];
//        }
//    }];
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
//- (void)shootPanoRotateGimbal {
    func shootPanoRotateGimbal() {
        //    DJICamera *camera = [self fetchCamera];
        //    weakSelf(target);
        //    [camera setMode:DJICameraModeShootPhoto withCompletion:^(NSError * _Nullable error) {
        //        weakReturn(target);
        //        if (!error) {
        //            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        //                [target executeRotateGimbal];
        //            });
        //        }
        //    }];
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
//    DJIGimbal *gimbal = [self fetchGimbal];
//    __weak DJICamera *camera = [self fetchCamera];
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
//
//    for(int i = 0; i < PHOTO_NUMBER; i++){
        for photoNumber in 0 ..< numberOfPhotos {
            print("SS Start Shoot Photo \(photoNumber)")
//        [camera setShootPhotoMode:DJICameraShootPhotoModeSingle withCompletion:^(NSError * _Nullable error) {
//            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//                [camera startShootPhotoWithCompletion:^(NSError * _Nullable error) {
//                    if (error) {
//                        NSLog(@"SS ShootPhotoError: %@", error.description);
//                    } else {
//                        NSLog(@"SS Successfully Shot Photo");
//                    }
//                }];
//            });
//        }];
            
            camera.setShootPhotoMode(DJICameraShootPhotoMode.single) { (error:Error?) in
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

            yawAngle = yawAngle + rotationAngle
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

        for photoNumber in 0..<numberOfPhotos {
            var rotateAngle = Int16(photoNumber) * Int16(rotationAngle)
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
                //NSString *message = [NSString stringWithFormat:@"Uploaded Waypoint Index: %ld, Total Waypoints: %ld" ,event.progress.uploadedWaypointIndex + 1, event.progress.totalWaypointCount];
                guard let progress = event.progress else { return }
                let message = "Uploaded Waypoint Index: \(progress.uploadedWaypointIndex + 1), Total Waypoints: \(progress.totalWaypointCount)"
                
                //TODO: still not sure about this unwrapping pattern...
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
                //[target showAlertViewWithTitle:@"Start Mission Success" withMessage:nil];
                self.showAlertWith(title: "Start Mission Success", message: "")
            }
        })
    }

//MARK: - Select the lastest photos for Panorama
//
//-(void)selectPhotosForPlaybackMode {
//    weakSelf(target);
//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//
//        weakReturn(target);
//        DJICamera *camera = [target fetchCamera];
//        [camera.playbackManager enterMultiplePreviewMode];
//        sleep(1);
//        [camera.playbackManager enterMultipleEditMode];
//        sleep(1);
//
//        while (target.numberSelectedPhotos != PHOTO_NUMBER) {
//            [camera.playbackManager selectAllFilesInPage];
//            sleep(1);
//
//            if(target.numberSelectedPhotos > PHOTO_NUMBER){
//                for(int unselectFileIndex = 0; target.numberSelectedPhotos != PHOTO_NUMBER; unselectFileIndex++){
//                    [camera.playbackManager toggleFileSelectionAtIndex:unselectFileIndex];
//                    sleep(1);
//                }
//                break;
//            }
//            else if(target.numberSelectedPhotos < PHOTO_NUMBER) {
//                [camera.playbackManager goToPreviousMultiplePreviewPage];
//                sleep(1);
//            }
//        }
//        [target downloadPhotosForPlaybackMode];
//    });
//}
//
//MARK: - Download the selected photos
//-(void)downloadPhotosForPlaybackMode {
//    __block int finishedFileCount = 0;
//    __block NSMutableData* downloadedFileData;
//    __block long totalFileSize;
//    __block NSString* targetFileName;
//
//    self.imageArray=[NSMutableArray new];
//
//    DJICamera *camera = [self fetchCamera];
//    if (camera == nil) return;
//
//    weakSelf(target);
//    [camera.playbackManager downloadSelectedFilesWithPreparation:^(NSString * _Nullable fileName, DJIDownloadFileType fileType, NSUInteger fileSize, BOOL * _Nonnull skip) {
//
//        totalFileSize=(long)fileSize;
//        downloadedFileData=[NSMutableData new];
//        targetFileName=fileName;
//
//        dispatch_async(dispatch_get_main_queue(), ^{
//            weakReturn(target);
//            [target showDownloadProgressAlert];
//            [target.downloadProgressAlert setTitle:[NSString stringWithFormat:@"Download (%d/%d)", finishedFileCount + 1, PHOTO_NUMBER]];
//            [target.downloadProgressAlert setMessage:[NSString stringWithFormat:@"FileName:%@ FileSize:%0.1fKB Downloaded:0.0KB", fileName, fileSize / 1024.0]];
//        });
//
//    } process:^(NSData * _Nullable data, NSError * _Nullable error) {
//
//        weakReturn(target);
//        [downloadedFileData appendData:data];
//
//        dispatch_async(dispatch_get_main_queue(), ^{
//            [target.downloadProgressAlert setMessage:[NSString stringWithFormat:@"FileName:%@ FileSize:%0.1fKB Downloaded:%0.1fKB", targetFileName, totalFileSize / 1024.0, downloadedFileData.length / 1024.0]];
//        });
//
//    } fileCompletion:^{
//        weakReturn(target);
//        finishedFileCount++;
//
//        UIImage *downloadPhoto=[UIImage imageWithData:downloadedFileData];
//        [target.imageArray addObject:downloadPhoto];
//
//    } overallCompletion:^(NSError * _Nullable error) {
//
//        dispatch_async(dispatch_get_main_queue(), ^{
//            [target.downloadProgressAlert dismissWithClickedButtonIndex:0 animated:YES];
//            target.downloadProgressAlert = nil;
//
//            if (error) {
//                UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Download failed" message:[NSString stringWithFormat:@"%@", error.description] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
//                [alertView show];
//            }else
//            {
//                UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"Download (%d/%d)", finishedFileCount, PHOTO_NUMBER] message:@"download finished" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
//                [alertView show];
//            }
//
//            DJICamera *camera = [target fetchCamera];
//            [camera setMode:DJICameraModeShootPhoto withCompletion:^(NSError * _Nullable error) {
//                if (error) {
//                    UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Set CameraMode to ShootPhoto Failed" message:[NSString stringWithFormat:@"%@", error.description] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
//                    [alertView show];
//
//                }
//            }];
//
//        });
//
//    }];
//}
//
//-(void)loadMediaListsForMediaDownloadMode {
//    DJICamera *camera = [self fetchCamera];
//    [self showDownloadProgressAlert];
//    [self.downloadProgressAlert setTitle:[NSString stringWithFormat:@"Refreshing file list. "]];
//    [self.downloadProgressAlert setMessage:[NSString stringWithFormat:@"Loading..."]];
//
//    weakSelf(target);
//    [camera.mediaManager refreshFileListOfStorageLocation:DJICameraStorageLocationSDCard withCompletion:^(NSError * _Nullable error) {
//        weakReturn(target);
//        if (error) {
//            [target.downloadProgressAlert dismissWithClickedButtonIndex:0 animated:YES];
//            target.downloadProgressAlert = nil;
//            NSLog(@"Refresh file list failed: %@", error.description);
//        }
//        else {
//            [target downloadPhotosForMediaDownloadMode];
//        }
//    }];
//}
//
//-(void)downloadPhotosForMediaDownloadMode {
//    __block int finishedFileCount = 0;
//
//    self.imageArray=[NSMutableArray new];
//
//    DJICamera *camera = [self fetchCamera];
//    NSArray<DJIMediaFile *> *files = [camera.mediaManager sdCardFileListSnapshot];
//    if (files.count < PHOTO_NUMBER) {
//        [self.downloadProgressAlert dismissWithClickedButtonIndex:0 animated:YES];
//        self.downloadProgressAlert = nil;
//        UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Download failed" message:[NSString stringWithFormat:@"Not enough photos are taken. "] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
//        [alertView show];
//        return;
//    }
//
//    [camera.mediaManager.taskScheduler resumeWithCompletion:^(NSError * _Nullable error) {
//        if (error) {
//            [self.downloadProgressAlert dismissWithClickedButtonIndex:0 animated:YES];
//            self.downloadProgressAlert = nil;
//            UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Download failed" message:[NSString stringWithFormat:@"Resume file task scheduler failed. "] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
//            [alertView show];
//        }
//    }];
//
//    [self.downloadProgressAlert setTitle:[NSString stringWithFormat:@"Downloading..."]];
//    [self.downloadProgressAlert setMessage:[NSString stringWithFormat:@"Download (%d/%d)", 0, PHOTO_NUMBER]];
//
//    weakSelf(target);
//    for (int i = (int)files.count - PHOTO_NUMBER; i < files.count; i++) {
//        DJIMediaFile *file = files[i];
//
//        DJIFetchMediaTask *task = [DJIFetchMediaTask taskWithFile:file content:DJIFetchMediaTaskContentPreview andCompletion:^(DJIMediaFile * _Nonnull file, DJIFetchMediaTaskContent content, NSError * _Nullable error) {
//            weakReturn(target);
//            if (error) {
//                [target.downloadProgressAlert dismissWithClickedButtonIndex:0 animated:YES];
//                target.downloadProgressAlert = nil;
//                UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Download failed" message:[NSString stringWithFormat:@"Download file %@ failed. ", file.fileName] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
//                [alertView show];
//            }
//            else {
//                [target.imageArray addObject:file.preview];
//                finishedFileCount++;
//                [target.downloadProgressAlert setMessage:[NSString stringWithFormat:@"Download (%d/%d)", finishedFileCount, PHOTO_NUMBER]];
//
//                if (finishedFileCount == PHOTO_NUMBER) {
//
//                    [target.downloadProgressAlert dismissWithClickedButtonIndex:0 animated:YES];
//                    target.downloadProgressAlert = nil;
//                    UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Download Complete" message:[NSString stringWithFormat:@"%d files have been downloaded. ", PHOTO_NUMBER] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
//                    [alertView show];
//                    [camera setMode:DJICameraModeShootPhoto withCompletion:^(NSError * _Nullable error) {
//                        if (error) {
//                            UIAlertView* alertView = [[UIAlertView alloc] initWithTitle:@"Set CameraMode to ShootPhoto Failed" message:[NSString stringWithFormat:@"%@", error.description] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
//                            [alertView show];
//                        }
//                    }];
//                }
//            }
//        }];
//        [camera.mediaManager.taskScheduler moveTaskToEnd:task];
//    }
//}
//
//-(void) showDownloadProgressAlert {
//    if (self.downloadProgressAlert == nil) {
//        self.downloadProgressAlert = [[UIAlertView alloc] initWithTitle:@"" message:@"" delegate:nil cancelButtonTitle:nil otherButtonTitles:nil];
//        [self.downloadProgressAlert show];
//    }
//}
//
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
        //TODO:
        //    weakSelf(target);
        //    DJICamera *camera = [self fetchCamera];
        //    if (camera.isPlaybackSupported) {
        //        [camera setMode:DJICameraModePlayback withCompletion:^(NSError * _Nullable error) {
        //            weakReturn(target);
        //
        //            if (error) {
        //                NSLog(@"Enter playback mode failed: %@", error.description);
        //            }else {
        //                [target selectPhotosForPlaybackMode];
        //            }
        //        }];
        //    }
        //    else if (camera.isMediaDownloadModeSupported) {
        //        [camera setMode:DJICameraModeMediaDownload withCompletion:^(NSError * _Nullable error) {
        //            weakReturn(target);
        //            if (error) {
        //                NSLog(@"Enter Media Download mode failed: %@", error.description);
        //            } else {
        //                [target loadMediaListsForMediaDownloadMode];
        //            }
        //        }];
        //    }
    }
    
    //TODO: unused?
    func didUpdateDatabaseDownloadProgress(_ progress: Progress) {
        //TODO
    }

}
