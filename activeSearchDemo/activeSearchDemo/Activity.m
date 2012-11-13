//
//  Activity.m
//  activeSearchDemo
//
//  Created by Demo on 11/12/12.
//  Copyright (c) 2012 Mashery. All rights reserved.
//

#import "Activity.h"
#import "ViewController.h"

@implementation Activity

@synthesize title, location, url, tag, summary, coordinate;

- (id) init
{
    self = [super init];
    if (!self) return nil;
    return self;
}

-(NSString *)title
{
    return [NSString stringWithFormat:@"%@", title];
}

-(NSString *)subtitle
{
    return [NSString stringWithFormat:@"%@", summary];
}

@end
