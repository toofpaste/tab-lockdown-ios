#import "Catalog.h"
#import "API.h"
@interface Catalog ()
@property(nonatomic, strong) TVAPI *api;
@property(nonatomic, strong) NSArray<NSDictionary *> *matches;
@property(nonatomic, strong) NSArray<NSDictionary *> *visibleMatches;
@property(nonatomic, copy) NSString *statusFilter;
@property(nonatomic, copy) NSString *categoryFilter;
@property(nonatomic, copy) NSString *notice;
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic) BOOL loading;
@property(nonatomic) BOOL choosing;
@property(nonatomic) NSUInteger selectionGeneration;
@end
@implementation Catalog
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Live Sports";
    self.api = [[TVAPI alloc] init];
    self.statusFilter = @"live";
    self.matches = @[]; self.visibleMatches = @[];
    self.tableView.rowHeight = 100;
    self.tableView.remembersLastFocusedIndexPath = YES;
    self.notice = @"Loading games…";
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(resume) name:UIApplicationDidBecomeActiveNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(pause) name:UIApplicationWillResignActiveNotification object:nil];
}
- (void)viewDidAppear:(BOOL)animated { [super viewDidAppear:animated]; [self resume]; }
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated]; [self pause];
    self.selectionGeneration++; self.choosing = NO;
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; [self.timer invalidate]; }
- (void)pause { [self.timer invalidate]; self.timer = nil; }
- (void)resume {
    if (!self.view.window || self.navigationController.topViewController != self) return;
    [self pause]; [self refresh];
    __weak Catalog *weakSelf = self;
    self.timer = [NSTimer scheduledTimerWithTimeInterval:60 repeats:YES block:^(NSTimer *timer) { [weakSelf refresh]; }];
}
- (void)refresh {
    if (self.loading || self.choosing || self.presentedViewController || UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;
    self.loading = YES;
    __weak Catalog *weakSelf = self;
    // One snapshot covers live/upcoming and all categories, so filters cost no requests.
    [self.api fetch:@"matches" completion:^(NSDictionary *body, NSString *error) {
        Catalog *s = weakSelf; if (!s) return; s.loading = NO;
        NSArray *rows = TVRows(body, @"matches");
        if (!rows) { s.notice = [NSString stringWithFormat:@"%@%@", error ?: @"Unexpected API response.", s.matches.count ? @" Showing previous results." : @""]; }
        else { s.matches = rows; s.notice = @"Select a game • Play/Pause: filters and refresh"; }
        [s applyFilters];
    }];
}
- (void)applyFilters {
    NSMutableArray *rows = [NSMutableArray array];
    for (NSDictionary *m in self.matches) {
        if (![TVString(m[@"status"]) isEqual:self.statusFilter]) continue;
        if (self.categoryFilter && ![TVString(m[@"category_slug"]) isEqual:self.categoryFilter]) continue;
        [rows addObject:m];
    }
    self.visibleMatches = rows;
    self.title = [NSString stringWithFormat:@"%@ Sports%@", [self.statusFilter isEqual:@"live"] ? @"Live" : @"Upcoming", self.categoryFilter ? [@" • " stringByAppendingString:self.categoryFilter] : @""];
    [self.tableView reloadData];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { return 1; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { return MAX(1, self.visibleMatches.count); }
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { return self.notice; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"game"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"game"];
    cell.accessoryType = UITableViewCellAccessoryNone;
    if (!self.visibleMatches.count) {
        cell.textLabel.text = self.loading ? @"Loading…" : @"No games in this view";
        cell.detailTextLabel.text = @"Press Play/Pause to change filters or retry."; return cell;
    }
    NSDictionary *m = self.visibleMatches[indexPath.row];
    cell.textLabel.text = TVString(m[@"title"]);
    NSString *time = @"Time unavailable";
    if ([m[@"start"] isKindOfClass:NSNumber.class]) time = [NSDateFormatter localizedStringFromDate:[NSDate dateWithTimeIntervalSince1970:[m[@"start"] doubleValue]] dateStyle:NSDateFormatterShortStyle timeStyle:NSDateFormatterShortStyle];
    NSString *online = [m[@"online_streams"] isKindOfClass:NSNumber.class] ? [m[@"online_streams"] stringValue] : @"0";
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ • %@ • %@ online servers", TVString(m[@"category"]), time, online];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (!self.visibleMatches.count || self.choosing) return;
    NSDictionary *match = self.visibleMatches[indexPath.row];
    NSString *identifier = TVString(match[@"id"]);
    // IDs are opaque strings: percent-encode them as one path component.
    NSString *escaped = [identifier stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.alphanumericCharacterSet];
    self.choosing = YES;
    NSUInteger generation = ++self.selectionGeneration;
    self.notice = @"Loading current servers…"; [self.tableView reloadData];
    __weak Catalog *weakSelf = self;
    [self.api fetch:[NSString stringWithFormat:@"matches/%@", escaped] completion:^(NSDictionary *body, NSString *error) {
        Catalog *s = weakSelf;
        if (!s || generation != s.selectionGeneration) return;
        s.choosing = NO;
        if (s.navigationController.topViewController != s || !s.view.window) return;
        NSDictionary *current = [body[@"match"] isKindOfClass:NSDictionary.class] ? body[@"match"] : nil;
        s.notice = error ?: @"Select a game • Play/Pause: filters and refresh"; [s.tableView reloadData];
        if (!current) { [s alert:error ?: @"Unexpected match response. Please retry."]; return; }
        [s servers:current];
    }];
}
- (void)alert:(NSString *)text {
    if (self.presentedViewController) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Live Sports" message:text preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)servers:(NSDictionary *)match {
    UIAlertController *picker = [UIAlertController alertControllerWithTitle:TVString(match[@"title"]) message:@"Automatic chooses a server and switches if it fails. Back returns to games." preferredStyle:UIAlertControllerStyleAlert];
    __weak Catalog *weakSelf = self;
    void (^add)(NSString *, id) = ^(NSString *label, id raw) {
        NSURL *url = TVEmbedURL(raw); if (!url) return;
        [picker addAction:[UIAlertAction actionWithTitle:label style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            if (weakSelf.openPlayer) weakSelf.openPlayer(url, TVString(match[@"title"]));
        }]];
    };
    add(@"Automatic server selection", match[@"embed_url"]);
    NSArray *streams = [match[@"streams"] isKindOfClass:NSArray.class] ? match[@"streams"] : @[];
    for (id stream in streams) {
        if (![stream isKindOfClass:NSDictionary.class]) continue;
        add([NSString stringWithFormat:@"%@ • %@ • %@", TVString(stream[@"name"]), TVString(stream[@"language"]), TVString(stream[@"status"])], stream[@"embed_url"]);
    }
    if (!picker.actions.count) { [self alert:@"No playable server links are available yet. Try again near the start time."]; return; }
    [picker addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:picker animated:YES completion:nil];
}
- (void)pressesBegan:(NSSet<UIPress *> *)presses withEvent:(UIPressesEvent *)event {
    for (UIPress *press in presses) if (press.type == UIPressTypePlayPause && !self.presentedViewController) { [self filters]; return; }
    [super pressesBegan:presses withEvent:event];
}
- (void)filters {
    UIAlertController *picker = [UIAlertController alertControllerWithTitle:@"Browse games" message:@"Game data refreshes every minute while this screen is open." preferredStyle:UIAlertControllerStyleAlert];
    __weak Catalog *weakSelf = self;
    [picker addAction:[UIAlertAction actionWithTitle:@"Switch to website mode" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { if (weakSelf.openWebsite) weakSelf.openWebsite(); }]];
    for (NSString *status in @[@"live", @"upcoming"]) [picker addAction:[UIAlertAction actionWithTitle:status.capitalizedString style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { weakSelf.statusFilter = status; [weakSelf applyFilters]; }]];
    [picker addAction:[UIAlertAction actionWithTitle:@"All categories" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { weakSelf.categoryFilter = nil; [weakSelf applyFilters]; }]];
    NSMutableDictionary *categories = [NSMutableDictionary dictionary];
    for (NSDictionary *m in self.matches) if (TVString(m[@"category_slug"]).length) categories[m[@"category_slug"]] = TVString(m[@"category"]);
    for (NSString *slug in [categories.allKeys sortedArrayUsingSelector:@selector(compare:)]) [picker addAction:[UIAlertAction actionWithTitle:categories[slug] style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { weakSelf.categoryFilter = slug; [weakSelf applyFilters]; }]];
    [picker addAction:[UIAlertAction actionWithTitle:@"Refresh" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [weakSelf refresh]; });
    }]];
    [picker addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:picker animated:YES completion:nil];
}
@end
