//
//  SavedCDTVC.m
//  Kaspa
//
//  Created by Nabil Maadarani on 2015-04-05.
//  Copyright (c) 2015 Nabil Maadarani. All rights reserved.
//

#import "SavedCDTVC.h"
#import "SavedTopic.h"
#import "SavedTopic+SavedTopicCategory.h"
#import "SavedTopicsDatabaseAvailability.h"
#import "SavedCDTVC+MOC.h"

@interface SavedCDTVC ()
@property (strong, nonatomic) AVSpeechSynthesizer *speechSynthesizer;
@property (nonatomic, strong) NSManagedObjectContext *savedTopicDatabaseContext;
@property int rowOfCellBeingSpoken;
@end

@implementation SavedCDTVC

// Post notification when context is set (for a refresh when deleting cells)
- (void)setSavedTopicDatabaseContext:(NSManagedObjectContext *)savedTopicDatabaseContext {
    _savedTopicDatabaseContext = savedTopicDatabaseContext;
    
    NSDictionary *userInfo = self.savedTopicDatabaseContext ? @{ SavedTopicsDatabaseAvailabilityContext : self.savedTopicDatabaseContext } : nil;
    
    // Post notification to tell the saved table list there's new data
    [[NSNotificationCenter defaultCenter] postNotificationName:SavedTopicsDatabaseAvailabilityNotification
                                                        object:self
                                                      userInfo:userInfo];
}


- (void)awakeFromNib {
    // Receive notification in order to refresh table
    [[NSNotificationCenter defaultCenter] addObserverForName:SavedTopicsDatabaseAvailabilityNotification
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification *note) {
                                                      self.managedObjectContext = note.userInfo[SavedTopicsDatabaseAvailabilityContext];
                                                  }];
}

- (void)setManagedObjectContext:(NSManagedObjectContext *)managedObjectContext {
    _managedObjectContext = managedObjectContext;
    
    NSFetchRequest *request =  [NSFetchRequest fetchRequestWithEntityName:@"SavedTopic"];
    request.predicate = nil;
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"date" ascending:YES]];
    
    self.fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                                                        managedObjectContext:managedObjectContext
                                                                          sectionNameKeyPath:nil
                                                                                   cacheName:nil];
}

- (AVSpeechSynthesizer *)speechSynthesizer {
    if(!_speechSynthesizer) {
        _speechSynthesizer = [[AVSpeechSynthesizer alloc] init];
        _speechSynthesizer.delegate = self;
    }
    return _speechSynthesizer;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Create the speech synthesizer to save time
    self.speechSynthesizer = [[AVSpeechSynthesizer alloc] init];
    self.speechSynthesizer.delegate = self;
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Saved Topic Cell" forIndexPath:indexPath];
    
    // Fetch the saved topic at this cell
    SavedTopic *savedTopic = [self.fetchedResultsController objectAtIndexPath:indexPath];
    
    // Configure the cell
    NSString *cellChannel = savedTopic.channel;
    
    // Cell title & icon
    UIImage *cellImage = [[UIImage alloc] init];
    if([cellChannel isEqualToString:@"Today"]) {
        // Today
        cell.textLabel.text = @"Today Information";
        cellImage = [UIImage imageNamed:@"Today"];
    } else if([cellChannel isEqualToString:@"Weather"]) {
        // Weather
        cell.textLabel.text = @"Weather Information";
        cellImage = [UIImage imageNamed:@"Weather"];
    } else if([cellChannel isEqualToString:@"Calendar Events"]) {
        // Calendar
        cell.textLabel.text = @"Calendar Information";
        cellImage = [UIImage imageNamed:@"Calendar"];
    }
    // Apply image with correct sizing
    cell.imageView.image = [UIImage imageWithCGImage:cellImage.CGImage
                                               scale:cellImage.size.width/40
                                         orientation:cellImage.imageOrientation];
    
    // Cell detail (date)
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"MMMM dd yyyy";
    cell.detailTextLabel.text = [formatter stringFromDate:[NSDate date]];
    
    // Unread image
    UIImageView *unreadImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Unread"]];
    cell.accessoryView = unreadImage;
    [cell.accessoryView setFrame:CGRectMake(0, 0, 20, 20)];
    
    return cell;
}

// Add title to section
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return NSLocalizedString(@"PREVIOUSLY SAVED:", @"");
}

#pragma mark - Cell selection behaviour

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];

    if([self image:((UIImageView *)cell.accessoryView).image isEqualTo:[UIImage imageNamed:@"Unread"]] ||
       cell.accessoryType == UITableViewCellAccessoryCheckmark) {
        // Not speaking this cell --> speak it
        
        // First check if another cell is speaking, and shut it down
        if(self.speechSynthesizer.speaking) {
            [self.speechSynthesizer stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
            [self markCurrentlySpokenCellAsDone];
        }
        
        if(cell.accessoryType == UITableViewCellAccessoryCheckmark)
            cell.accessoryType = UITableViewCellAccessoryNone; // Clear out the checkmark if it's there
        
        SavedTopic *savedTopic = [self.fetchedResultsController objectAtIndexPath:indexPath];
        NSString *cellChannel = savedTopic.channel;
        
        // Find the topic of speach
        if([cellChannel isEqualToString:@"Today"]) {
            [self speakToday:savedTopic.data];
        } else if([cellChannel isEqualToString:@"Weather"]) {
            [self speakWeather:savedTopic.data];
        } else if([cellChannel isEqualToString:@"Calendar Events"]) {
            [self speakCalendarEvents:savedTopic.data];
        }
        // Set current cell as being spoken
        self.rowOfCellBeingSpoken = (int)indexPath.row;
        
        // Set accessory icon to speaker while speaking
        [self setCellAccessoryView:cell ToImageWithName:@"Speaker"];
    } else if([self image:((UIImageView *)cell.accessoryView).image isEqualTo:[UIImage imageNamed:@"Speaker"]]) {
        // Cell just tapped is being spoken --> pause it
        [self.speechSynthesizer pauseSpeakingAtBoundary:AVSpeechBoundaryWord];
        
        // Set accessory icon to paused
        [self setCellAccessoryView:cell ToImageWithName:@"Paused"];
    } else if([self image:((UIImageView *)cell.accessoryView).image isEqualTo:[UIImage imageNamed:@"Paused"]]) {
        // Speak is paused --> resume
        [self.speechSynthesizer continueSpeaking];
        
        // Change icon back to speaker
        if(self.speechSynthesizer.speaking) // Still didn't finish
            [self setCellAccessoryView:cell ToImageWithName:@"Speaker"];
        else {
            cell.accessoryView = nil;
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        }
    }
    
    // Unselect the selected row
    NSIndexPath* selection = [self.tableView indexPathForSelectedRow];
    if (selection)
        [self.tableView deselectRowAtIndexPath:selection animated:YES];
}

-(void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        SavedTopic *savedTopic = [self.fetchedResultsController objectAtIndexPath:indexPath];
        NSDate *cellDate = savedTopic.date;
        
        self.savedTopicDatabaseContext = [self createMainQueueManagedObjectContext];
        NSManagedObjectContext *context = self.savedTopicDatabaseContext;
        
        [context performBlock:^{
            [SavedTopic removeFromSavedListWithDate:cellDate
                             inManagedObjectContext:context];
            [context save:NULL];
        }];

    } else {
        NSLog(@"Unhandled editing style! %ld", editingStyle);
    }
}

- (BOOL)image:(UIImage *)image1 isEqualTo:(UIImage *)image2
{
    NSData *data1 = UIImagePNGRepresentation(image1);
    NSData *data2 = UIImagePNGRepresentation(image2);
    
    return [data1 isEqual:data2];
}

// Put checkmark on cell with the speaker icon
- (void)markCurrentlySpokenCellAsDone {
    NSIndexPath* cellPath = [NSIndexPath indexPathForRow:self.rowOfCellBeingSpoken inSection:0];
    UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:cellPath];

    // Remove current image and set checkmark
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryCheckmark;
}

- (void)setCellAccessoryView:(UITableViewCell *)cell
             ToImageWithName:(NSString *)imageName {
    UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:imageName]];
    cell.accessoryView = imageView;
    [cell.accessoryView setFrame:CGRectMake(0, 0, 20, 20)];
}

#pragma mark - Speaking utterances
- (void)speakToday:(NSString *)speechString {
    // Today (mark end with ...)
    AVSpeechUtterance *utterance = [[AVSpeechUtterance alloc] initWithString:
                                    [NSString stringWithFormat:@"%@]", speechString]];
    [self setUpVoiceAndSpeak:utterance];
}

- (void)speakWeather:(NSString *)speechString {
    // Weather (mark end with ...)
    NSMutableArray *weatherSentences = [[speechString componentsSeparatedByString:@".."] mutableCopy];
    // Remove last object since it's an empty string
    [weatherSentences removeLastObject];
    
    for(NSString *weatherSentence in weatherSentences) {
        AVSpeechUtterance *utterance = nil;
        if([weatherSentence isEqualToString:[weatherSentences lastObject]]) {
            utterance = [[AVSpeechUtterance alloc] initWithString:
                         [NSString stringWithFormat:@"%@]",weatherSentence]];
        } else
            utterance = [[AVSpeechUtterance alloc] initWithString:weatherSentence];
        
        [self setUpVoiceAndSpeak:utterance];
    }
}


- (void)speakCalendarEvents:(NSArray *)speechArray {
    // Calendar events (mark end with ])
    for(NSString *eventSentence in speechArray) {
        AVSpeechUtterance *utterance = nil;
        if([eventSentence isEqualToString:[speechArray lastObject]])
            utterance = [[AVSpeechUtterance alloc] initWithString:
                         [NSString stringWithFormat:@"%@]",eventSentence]];
        else
            utterance = [[AVSpeechUtterance alloc] initWithString:eventSentence];
        
        [self setUpVoiceAndSpeak:utterance];
    }
}

- (void)setUpVoiceAndSpeak:(AVSpeechUtterance *)utterance {
    utterance.pitchMultiplier = 1.25f;
    utterance.rate = 0.15f;
    utterance.preUtteranceDelay = 0.1f;
    utterance.postUtteranceDelay = 0.1f;
    
    // Speak
    [self.speechSynthesizer speakUtterance:utterance];
}


#pragma mark - SpeechUtterance delegate
- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didFinishSpeechUtterance:(AVSpeechUtterance *)utterance {
    if([utterance.speechString hasSuffix:@"]"])
        [self markCurrentlySpokenCellAsDone];
}

#pragma mark - Extra stuff
/*
 // Override to support conditional editing of the table view.
 - (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
 // Return NO if you do not want the specified item to be editable.
 return YES;
 }
 */

/*
 // Override to support editing the table view.
 - (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
 if (editingStyle == UITableViewCellEditingStyleDelete) {
 // Delete the row from the data source
 [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
 } else if (editingStyle == UITableViewCellEditingStyleInsert) {
 // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
 }
 }
 */

/*
 // Override to support rearranging the table view.
 - (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
 }
 */

/*
 // Override to support conditional rearranging of the table view.
 - (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
 // Return NO if you do not want the item to be re-orderable.
 return YES;
 }
 */

/*
 ##pragma mark - mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */

@end
