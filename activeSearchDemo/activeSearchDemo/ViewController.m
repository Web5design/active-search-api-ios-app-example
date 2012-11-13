//
//  ViewController.m
//  activeSearchDemo
//
//  Created by Neil Mansilla on 11/12/12.
//  Copyright (c) 2012 Mashery. All rights reserved.
//

#import "ViewController.h"
#import "AppDelegate.h"
#import "StackMob.h"
#import "SMClient.h"
#import "SMQuery.h"
#import "Activity.h"
#import "Constants.h"

@interface ViewController ()

@end

@implementation ViewController

- (AppDelegate *)appDelegate {
    return (AppDelegate *)[[UIApplication sharedApplication] delegate];
}

- (id) init
{
    self = [super init];
    if (self) {
        //
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.managedObjectContext = [self.appDelegate managedObjectContext];
}

- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar {
    searchBar.showsScopeBar = YES;
    [searchBar sizeToFit];
    
    [searchBar setShowsCancelButton:YES animated:YES];
    
    return YES;
}

- (BOOL)searchBarShouldEndEditing:(UISearchBar *)searchBar {
    searchBar.scopeButtonTitles = nil;
    searchBar.showsScopeBar = NO;
    [searchBar sizeToFit];
    
    [searchBar setShowsCancelButton:NO animated:YES];
    
    return YES;
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [self handleSearch:searchBar];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *) searchBar {
    [searchBar resignFirstResponder];
}

- (void)handleSearch:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder]; // dismiss keyboard
    [self searchActivities:searchBar.text];
}

- (void)searchActivities:(NSString *)query {
    NSString *encodedQuery = (__bridge_transfer NSString *) CFURLCreateStringByAddingPercentEscapes(
                                                                                                    NULL,
                                                                                                    (__bridge CFStringRef)query,
                                                                                                    NULL,
                                                                                                    (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ",
                                                                                                    kCFStringEncodingUTF8);
    
    // Concatenate it all into URL string
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@&api_key=%@&l=%@", ACTIVEURI, ACTIVEAPIKEY, encodedQuery]];
    
    // Issue API call
	NSURLResponse *response = nil;
	NSError *error = nil;
	NSData* result = [NSURLConnection sendSynchronousRequest:[NSMutableURLRequest requestWithURL:url] returningResponse:&response error:&error];

    if ((response.expectedContentLength == NSURLResponseUnknownLength) ||
        (response.expectedContentLength < 0) ||
        (response.expectedContentLength != result.length) ||
        ([((NSHTTPURLResponse *)response) statusCode] >= 400) ||
        (!result))
    {
        NSLog(@"Active: No activities found");
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No activities found"
                                                        message:@"Use: [Postal code]\n(ex: 94103)\n\nUse: [City,State,Country]\n(ex: Oakland, CA, US)"
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    // Clear any previous map annotations
    [mapView removeAnnotations:mapView.annotations];
    
    SBJsonParser *jsonParser = [[SBJsonParser alloc] init];
    NSString *resultsString =[[NSString alloc] initWithBytes:[result bytes] length:[result length] encoding: NSUTF8StringEncoding];
    NSArray *resultsArray = [[jsonParser objectWithString:resultsString error:nil] objectForKey:@"_results"];
    
    // Cast returned objects to result objects (conforming to the mapAnnotation protocol)
    activityArray = [[NSMutableArray alloc] init];
    for (NSDictionary *result in resultsArray)
    {
        Activity *newActivity = [[Activity alloc] init];
        
        newActivity.title = [NSString stringWithFormat:@"%@",[result objectForKey:@"title"]];
        newActivity.summary = [NSString stringWithFormat:@"%@",[result objectForKey:@"summary"]];
        newActivity.url = [NSString stringWithFormat:@"%@",[[[result objectForKey:@"url"] stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
        newActivity.location = [NSString stringWithFormat:@"%@",[[result objectForKey:@"meta"] objectForKey:@"location"]];
        newActivity.coordinate = CLLocationCoordinate2DMake([[[result objectForKey:@"meta"] objectForKey:@"latitude"] doubleValue], [[[result objectForKey:@"meta"] objectForKey:@"longitude"] doubleValue]);
        
        // Add location object to an array
        [activityArray addObject:newActivity];
    }
    
    // Add locations to map
    [mapView addAnnotations:activityArray];
    [self zoomMapViewToFitAnnotationsAnimated:false];
    
    // Store locations in StackMob
    [self persistLocationsOnStackmob];
}

- (void)persistLocationsOnStackmob
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Activity" inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    int x = 0;
    for (Activity *activity in activityArray) {
        x++;
        // Edit the sort key as appropriate.
        NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"title" ascending:YES];
        NSArray *sortDescriptors = [NSArray arrayWithObjects:sortDescriptor, nil];
        [fetchRequest setSortDescriptors:sortDescriptors];
        
        // Query StackMob for existing title -- if !exist, then save.
        NSFetchedResultsController *fetchedResultsController;
        
        NSPredicate *equalPredicate =[NSPredicate predicateWithFormat:@"title == %@", [NSString stringWithFormat:@"%@",activity.title]];
        [fetchRequest setPredicate:equalPredicate];
        
        NSError *errorFetch = nil;
        if (![fetchedResultsController performFetch:&errorFetch]) {
            // Save the title in StackMob
            NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:@"Activity" inManagedObjectContext:self.managedObjectContext];
            
            [newManagedObject setValue:activity.title forKey:@"title"];
            [newManagedObject setValue:activity.summary forKey:@"summary"];
            [newManagedObject setValue:activity.url forKey:@"url"];
            [newManagedObject setValue:activity.location forKey:@"location"];
            [newManagedObject setValue:[NSString stringWithFormat:@"%f", activity.coordinate.latitude] forKey:@"latitude"];
            [newManagedObject setValue:[NSString stringWithFormat:@"%f", activity.coordinate.longitude] forKey:@"longitude"];

            [newManagedObject setValue:[newManagedObject assignObjectId] forKey:[newManagedObject primaryKeyField]];
            
            NSError *errorSave = nil;
            if (![self.managedObjectContext save:&errorSave]) {
                NSLog(@"Error saving to StackMob %@", errorSave);
            }
        }
    }
}

// Autosize map method by Brian Reiter http://ow.ly/f08HG

- (void)zoomMapViewToFitAnnotationsAnimated:(BOOL)animated
{
    NSArray *annotations = mapView.annotations;
    int count = [mapView.annotations count];
    if ( count == 0) { return; } //bail if no annotations
    //can't use NSArray with MKMapPoint because MKMapPoint is not an id
    //convert NSArray of id <MKAnnotation> into an MKCoordinateRegion that can be used to set the map size
    //can't use NSArray with MKMapPoint because MKMapPoint is not an id
    MKMapPoint points[count]; //C array of MKMapPoint struct
    for( int i=0; i<count; i++ ) //load points C array by converting coordinates to points
    {
        CLLocationCoordinate2D coordinate = [(id <MKAnnotation>)[annotations objectAtIndex:i] coordinate];
        points[i] = MKMapPointForCoordinate(coordinate);
    }
    //create MKMapRect from array of MKMapPoint
    MKMapRect mapRect = [[MKPolygon polygonWithPoints:points count:count] boundingMapRect];
    //convert MKCoordinateRegion from MKMapRect
    MKCoordinateRegion region = MKCoordinateRegionForMapRect(mapRect);
    region.span.latitudeDelta  *= ANNOTATION_REGION_PAD_FACTOR;
    //add padding so pins aren't scrunched on the edges
    region.span.latitudeDelta  *= ANNOTATION_REGION_PAD_FACTOR;
    region.span.longitudeDelta *= ANNOTATION_REGION_PAD_FACTOR;
    //but padding can't be bigger than the world
    if( region.span.latitudeDelta > MAX_DEGREES_ARC ) { region.span.latitudeDelta  = MAX_DEGREES_ARC; }
    if( region.span.longitudeDelta > MAX_DEGREES_ARC ){ region.span.longitudeDelta = MAX_DEGREES_ARC; }
    if( region.span.latitudeDelta  < MINIMUM_ZOOM_ARC ) { region.span.latitudeDelta  = MINIMUM_ZOOM_ARC; }
    //and don't zoom in stupid-close on small samples
    if( region.span.latitudeDelta  < MINIMUM_ZOOM_ARC ) { region.span.latitudeDelta  = MINIMUM_ZOOM_ARC; }
    if( region.span.longitudeDelta < MINIMUM_ZOOM_ARC ) { region.span.longitudeDelta = MINIMUM_ZOOM_ARC; }
    //and if there is a sample of 1 we want the max zoom-in instead of max zoom-out
    if( count == 1 ) {
        region.span.longitudeDelta = MINIMUM_ZOOM_ARC;
        region.span.latitudeDelta = MINIMUM_ZOOM_ARC;
        region.span.longitudeDelta = MINIMUM_ZOOM_ARC;
    }
    
    [mapView setRegion:region animated:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}


@end
