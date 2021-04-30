//
//  StitchingViewController.swift
//  PanoDemo
//
//  Created by Samuel Scherer on 4/30/21.
//  Copyright © 2021 DJI. All rights reserved.
//

import Foundation

import UIKit

class StitchingViewController : UIViewController {
    @objc public var imageArray : NSMutableArray? //TODO: use [UIImage] ?
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var imageView: UIImageView!
    
    override func viewDidLoad() {
        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
            // cv::Mat stitchMat;
            // if(![Stitching stitchImageWithArray:weakImageArray andResult:stitchMat]) {
            //     [weakSelf showAlertWithTitle:@"Stitching" andMessage:@"Stitching failed"];
            //     return;
            // }
            //
            // cv::Mat cropedMat;
            // if(![Cropping cropWithMat:stitchMat andResult:cropedMat]){
            //     [weakSelf showAlertWithTitle:@"Cropping" andMessage:@"cropping failed"];
            //     return;
            // }
            //
            // UIImage *stitchImage=[OpenCVConversion UIImageFromCVMat:cropedMat];
            // UIImageWriteToSavedPhotosAlbum(stitchImage, nil, nil, nil);
            //
            // dispatch_async(dispatch_get_main_queue(), ^{
            //
            // [weakSelf showAlertWithTitle:@"Save Photo Success" andMessage:@"Panoroma photo is saved to Album, please check it!"];
            //     _imageView.image=stitchImage;
            // });
        }
        super.viewDidLoad()
    }
    
    //show the alert view in main thread
    func showAlertWith(title:String, message:String) {
        DispatchQueue.main.async { [weak self] in
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: "OK", style: UIAlertAction.Style.cancel) { UIAlertAction in
                alertController.dismiss(animated: true, completion: nil)
            }
            alertController.addAction(cancelAction)
            self?.activityIndicator.stopAnimating()
        }
    }
}

