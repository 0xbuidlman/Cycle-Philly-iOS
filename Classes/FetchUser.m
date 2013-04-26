/** Cycle Atlanta, Copyright 2012, 2013 Georgia Institute of Technology
 *                                    Atlanta, GA. USA
 *
 *   @author Christopher Le Dantec <ledantec@gatech.edu>
 *   @author Anhong Guo <guoanhong@gatech.edu>
 *
 *   Cycle Atlanta is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation, either version 3 of the License, or
 *   (at your option) any later version.
 *
 *   Cycle Atlanta is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details.
 *
 *   You should have received a copy of the GNU General Public License
 *   along with Cycle Atlanta.  If not, see <http://www.gnu.org/licenses/>.
 */

#import "FetchUser.h"
#import "FetchTripData.h"
#import "constants.h"
#import "CycleAtlantaAppDelegate.h"
#import "PersonalInfoViewController.h"

@implementation FetchUser

@synthesize managedObjectContext, receivedData, parent, deviceUniqueIdHash, activityDelegate, alertDelegate, activityIndicator, downloadingProgressView, user, urlRequest;

- (id)init{
    self.managedObjectContext = [(CycleAtlantaAppDelegate *)[[UIApplication sharedApplication] delegate] managedObjectContext];

    return self;
}

- (void)loadUser:(NSDictionary *)userDict{
    NSFetchRequest		*request = [[NSFetchRequest alloc] init];
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"User" inManagedObjectContext:managedObjectContext];
	[request setEntity:entity];
	NSError *error;
	NSMutableArray *mutableFetchResults = [[self.managedObjectContext executeFetchRequest:request error:&error] mutableCopy];
	
    if (mutableFetchResults == nil) {
		// Handle the error.
		NSLog(@"no saved user");
		if ( error != nil )
			NSLog(@"Fetch User fetch error %@, %@", error, [error localizedDescription]);
	}	
	[self setUser:[mutableFetchResults objectAtIndex:0]];
    
    if ( user != nil ){
        if ( [userDict objectForKey:@"age"] != (id)[NSNull null]) {
            [user setAge:[NSNumber numberWithInteger:[[userDict objectForKey:@"age"] integerValue]]];
        }
        if ([userDict objectForKey:@"email"]!= NULL) {
            [user setEmail:[userDict objectForKey:@"email"]];
        }
        if ([userDict objectForKey:@"gender"] != (id)[NSNull null]) {
            [user setGender:[NSNumber numberWithInteger:[[userDict objectForKey:@"gender"] integerValue]]];
        }
        if ([userDict objectForKey:@"ethnicity"] != (id)[NSNull null]) {
            [user setEthnicity:[NSNumber numberWithInteger:[[userDict objectForKey:@"ethnicity"] integerValue]]];
        }
        if ([userDict objectForKey:@"income"] != (id)[NSNull null]) {
            [user setIncome:[NSNumber numberWithInteger:[[userDict objectForKey:@"income"] integerValue]]];
        }        
        if ([userDict objectForKey:@"homeZIP"] != (id)[NSNull null]) {
            [user setHomeZIP:[userDict objectForKey:@"homeZIP"]];
        }
        if ([userDict objectForKey:@"workZIP"] != (id)[NSNull null]) {
            [user setWorkZIP:[userDict objectForKey:@"workZIP"]];
        }
        if ([userDict objectForKey:@"schoolZIP"] != (id)[NSNull null]) {
            [user setSchoolZIP:[userDict objectForKey:@"schoolZIP"]];
        }
        if ([userDict objectForKey:@"cycling_freq"] != (id)[NSNull null]) {
            [user setCyclingFreq:[NSNumber numberWithInteger:[[userDict objectForKey:@"cycling_freq"] integerValue]]];
        }
        if ([userDict objectForKey:@"rider_type"] != (id)[NSNull null]) {
            [user setRider_type:[NSNumber numberWithInteger:[[userDict objectForKey:@"rider_type"] integerValue]]];
        }
        if ([userDict objectForKey:@"rider_history"] != (id)[NSNull null]) {
            [user setRider_history:[NSNumber numberWithInteger:[[userDict objectForKey:@"rider_history"] integerValue]]];
        }
    }
    [self.managedObjectContext save:&error];
    [self.parent viewWillAppear:false];
	[mutableFetchResults release];
	[request release];
}

-(void)loadTrip:(NSDictionary *)tripsDict{
    NSFetchRequest		*request = [[NSFetchRequest alloc] init];
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"Trip" inManagedObjectContext:self.managedObjectContext];
	[request setEntity:entity];
	NSError *error;
	NSMutableArray *storedTrips = [[self.managedObjectContext executeFetchRequest:request error:&error] mutableCopy];
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    [dateFormat setTimeZone:[NSTimeZone timeZoneWithName:@"PST"]];
    NSString *tempDateString;
    
    BOOL tripNotFound = true;
    BOOL noNewData = true;
    NSMutableArray *tripsToLoad = [[NSMutableArray alloc] init];
    NSLog(@"Total number of trips: %d", [tripsDict count]);

    for(NSDictionary *newTrip in tripsDict){
        tripNotFound = true;
        for(Trip *oldTrip in storedTrips){
            tempDateString=[dateFormat stringFromDate:oldTrip.start];
            if( [tempDateString isEqualToString:[newTrip objectForKey:@"start"]]){
                NSLog(@"trip  found");
                tripNotFound = false;
                break;
            }
        }
        if(tripNotFound){
            noNewData = false;
            [tripsToLoad addObject:newTrip];
        }
    }
    
    if(noNewData){
        [self.downloadingProgressView loadingComplete:@"No more trips to download." delayInterval:.5];
    }
    else{
        [self.downloadingProgressView setVisible:TRUE messageString:kFetchTitle];
        NSLog(@"Number of trips to download: %d", [tripsToLoad count]);
        FetchTripData *fetchTrip = [[[FetchTripData alloc] initWithTripCountAndProgessView:[tripsToLoad count] progressView:self.downloadingProgressView] autorelease];
        [fetchTrip fetchWithTrips:tripsToLoad];
    }
    
    [request release];
    [storedTrips release];
    [dateFormat release];
    [tripsToLoad release];
}


- (void)fetchUserAndTrip:(UIViewController*)parentView
{
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    self.parent = parentView;
    self.downloadingProgressView = [ProgressView progressViewInView:self.parent.parentViewController.view messageString:kFetchTitle];
    [self.downloadingProgressView setVisible:TRUE messageString:kFetchTitle];
    [self.parent.parentViewController.view addSubview:downloadingProgressView];

    //TODO: reset to delegate.uniqueIDHash for production.
    CycleAtlantaAppDelegate *delegate = [[UIApplication sharedApplication] delegate];
    self.deviceUniqueIdHash = delegate.uniqueIDHash;//production @"2ecc2e36c3e1a512d349f9b407fb281e";//me  @"3cab3ca8964ca45b3e24fa7aee4d5e1f";//test-user
    NSLog(@"start downloading");
    NSLog(@"DeviceUniqueIdHash: %@", deviceUniqueIdHash);
    
    NSDictionary *fetchDict = [NSDictionary dictionaryWithObjectsAndKeys:
                               @"get_user_and_trips", @"t", deviceUniqueIdHash, @"d", nil];
    
    NSMutableString *postBody = [NSMutableString string];
    NSString *sep = @"";
    for(NSString * key in fetchDict) {
        [postBody appendString:[NSString stringWithFormat:@"%@%@=%@",
                                sep,
                                key,
                                [fetchDict objectForKey:key]]];
        sep = @"&";
    }
    
    NSData *postData = [postBody dataUsingEncoding:NSUTF8StringEncoding];
    NSLog(@"POST Data: %@", postBody);
    
    self.urlRequest = [[[NSMutableURLRequest alloc] init] autorelease];
    [urlRequest setURL:[NSURL URLWithString:kFetchURL]];
    [urlRequest setHTTPMethod:@"POST"];
    [urlRequest setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [urlRequest setValue:[NSString stringWithFormat:@"%d", [postData length]] forHTTPHeaderField:@"Content-Length"];
    [urlRequest setHTTPBody:postData];
	
	// create the connection with the request and start loading the data
	NSURLConnection *theConnection=[[NSURLConnection alloc] initWithRequest:urlRequest delegate:self];
	
    if ( theConnection )
    {
        receivedData=[[NSMutableData data] retain];
    }
    else
    {
        // inform the user that the download could not be made
        NSLog(@"Download failed!");
    }
}

#pragma mark NSURLConnection delegate methods


- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten
 totalBytesWritten:(NSInteger)totalBytesWritten totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
	NSLog(@"%d bytesWritten, %d totalBytesWritten, %d totalBytesExpectedToWrite",
		  bytesWritten, totalBytesWritten, totalBytesExpectedToWrite );
}


- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	// this method is called when the server has determined that it
    // has enough information to create the NSURLResponse
	NSLog(@"didReceiveResponse: %@", response);
	
	NSHTTPURLResponse *httpResponse = nil;
	if ( [response isKindOfClass:[NSHTTPURLResponse class]] &&
		( httpResponse = (NSHTTPURLResponse*)response ) )
	{
		BOOL success = NO;
		NSString *title   = nil;
		NSString *message = nil;
		switch ( [httpResponse statusCode] )
		{
			case 200:
			case 201:
				success = YES;
				title	= kSuccessFetchTitle;
				message = kFetchSuccess;
				break;
			case 500:
			default:
				title = @"Internal Server Error";
				message = @"Download failed.";
		}
		
		NSLog(@"%@: %@", title, message);
        
        // DEBUG
        NSLog(@"+++++++DEBUG didReceiveResponse %@: %@", [response URL],[(NSHTTPURLResponse*)response allHeaderFields]);
        
        if ( success )
		{
            NSLog(@"Download Success!!!");
			NSError *error;
			if (![managedObjectContext save:&error]) {
				// Handle the error.
				NSLog(@"FetchUser error %@, %@", error, [error localizedDescription]);
			}
		} else {
            //no-op
        }
	}
	
    // receivedData is declared as a method instance elsewhere
    [receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	[receivedData appendData:data];
}

- (void)connection:(NSURLConnection *)connection
  didFailWithError:(NSError *)error
{
    [connection release];
    [receivedData release];
    
    [self.downloadingProgressView setErrorMessage:kFetchError];
    [self.downloadingProgressView loadingComplete:kFetchTitle delayInterval:1.7];
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
    
    NSLog(@"Connection failed! Error - %@ %@",
          [error localizedDescription],
          [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    NSLog(@"+++++++DEBUG: Received %d bytes of data", [receivedData length]);
    NSError *error;
    NSString *jsonString = [[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding];
    NSLog(@"JSON string: %@", jsonString);
    NSDictionary *JSON = [NSJSONSerialization JSONObjectWithData: [jsonString dataUsingEncoding:NSUTF8StringEncoding]
                                                         options: NSJSONReadingMutableContainers
                                                           error: &error];
    
    NSDictionary *userDict = [JSON objectForKey:@"user"];
    NSDictionary *tripsDict = [JSON objectForKey:@"trips"];
    
    //Debugging messages
//    NSData *JsonDataUser = [[NSData alloc] initWithData:[NSJSONSerialization dataWithJSONObject:userDict options:0 error:&error]];
//    NSLog(@"User Data: \n%@", [[[NSString alloc] initWithData:JsonDataUser encoding:NSUTF8StringEncoding] autorelease] );
//    NSData *JsonDataTrips = [[NSData alloc] initWithData:[NSJSONSerialization dataWithJSONObject:tripsDict options:0 error:&error]];
//    NSLog(@"Trip Data: \n%@", [[[NSString alloc] initWithData:JsonDataTrips encoding:NSUTF8StringEncoding] autorelease] );
    
    [self loadUser:userDict];
    [self loadTrip:tripsDict];
    
    // release the connection, and the data object
    [connection release];
    [receivedData release];
    [jsonString release];
}

@end
