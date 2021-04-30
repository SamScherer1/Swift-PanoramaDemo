//
//  Stitching.h
//  PanoDemo
//
//  Created by DJI on 15/7/30.
//  Copyright (c) 2015年 DJI. All rights reserved.
//

#import <Foundation/Foundation.h>
@class UIImage;

@interface Stitching : NSObject

//+ (bool) stitchImageWithArray:(NSMutableArray*)imageArray andResult:(cv::Mat &) result;

+ (UIImage *)imageWithArray:(NSMutableArray *)imageArray;

@end
