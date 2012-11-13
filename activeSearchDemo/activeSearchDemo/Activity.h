//
//  Activity.h
//  activeSearchDemo
//
//  Created by Neil Mansilla on 11/12/12.
//  Copyright (c) 2012 Mashery. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import "SBJson.h"
#import "ViewController.h"

@interface Activity : NSObject <MKAnnotation>
{
    NSString *title;
    NSString *summary;
    NSString *url;
    NSString *location;
    CLLocationCoordinate2D coordinate;
}

@property (nonatomic,retain) NSString *title;
@property (nonatomic,retain) NSString *summary;
@property (nonatomic,retain) NSString *url;
@property (nonatomic,retain) NSString *location;
@property (nonatomic, assign) NSUInteger tag;
@property (nonatomic, assign) CLLocationCoordinate2D coordinate;

@end