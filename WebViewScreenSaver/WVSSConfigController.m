//
//  WVSSConfigController.m
//  WebViewScreenSaver
//
//  Created by Alastair Tse on 26/04/2015.
//
//  Copyright 2015 Alastair Tse.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "WVSSConfigController.h"
#import "WVSSAddress.h"
#import "WVSSAddressListFetcher.h"
#import "WVSSConfig.h"
#import "WebViewScreenSaverView.h"

#import <WebKit/WebKit.h>

static NSString *const kURLTableRow = @"kURLTableRow";
// Configuration sheet columns.
static NSString *const kTableColumnURL = @"url";
static NSString *const kTableColumnTime = @"time";
static NSString *const kTableColumnPreview = @"preview";

@interface WVSSConfigController () <WVSSAddressListFetcherDelegate, WKNavigationDelegate, NSWindowDelegate>
@property(nonatomic, strong) WVSSConfig *config;
@property(nonatomic, strong) WKWebView *previewWebView;
@end

@implementation WVSSConfigController

- (instancetype)initWithUserDefaults:(NSUserDefaults *)userDefaults {
  self = [super init];
  if (self) {
    self.config = [[WVSSConfig alloc] initWithUserDefaults:userDefaults];
    [self appendSampleAddressIfEmpty];

    // Fetch URLs if we're using the URLsURL.
    [self fetchAddresses];
  }
  return self;
}

- (void)synchronize {
  self.config.addressListURL = self.urlsURLField.stringValue;
  
  self.config.timeFormat = self.timeFormatPopup.selectedItem.title;
  
  // 只保留年月日，时分秒固定为 00:00:00
  NSCalendar *calendar = [NSCalendar currentCalendar];
  NSDateComponents *components = [calendar components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond) fromDate:self.birthDatePicker.dateValue];
  components.hour = 0;
  components.minute = 0;
  components.second = 0;
  self.config.birthDate = [calendar dateFromComponents:components];
  
  self.config.scale = self.scaleSlider.floatValue;
  self.config.brightness = self.brightnessSlider.floatValue;
  self.config.showBackground = self.showBackgroundCheckbox.state == NSControlStateValueOn;
  self.config.multiMonitor = self.multiMonitorCheckbox.state == NSControlStateValueOn;
  
  [self.config synchronize];
}

- (void)appendSampleAddressIfEmpty {
  if (!self.config.addresses.count) {
    [self appendAddress];
  }
}

- (NSArray *)addresses {
  return self.config.addresses;
}

- (void)appendAddress {
  WVSSAddress *address = [WVSSAddress defaultAddress];
  [self.config.addresses addObject:address];
  [self.urlTable reloadData];
}

- (void)removeAddressAtIndex:(NSInteger)index {
  [self.config.addresses removeObjectAtIndex:(NSUInteger)index];
  [self.urlTable reloadData];
}

- (void)fetchAddresses {
  if (!self.config.shouldFetchAddressList) return;

  NSString *addressFetchURL = self.config.addressListURL;
  if (!addressFetchURL.length) return;
  if (!([addressFetchURL hasPrefix:@"http://"] || [addressFetchURL hasPrefix:@"https://"])) return;

  WVSSAddressListFetcher *fetcher = [[WVSSAddressListFetcher alloc] initWithURL:addressFetchURL];
  fetcher.delegate = self;
}

#pragma mark - Actions

- (IBAction)addRow:(id)sender {
  [self appendAddress];
}

- (IBAction)removeRow:(id)sender {
  NSInteger row = [self.urlTable selectedRow];
  if (row != NSNotFound) {
    [self removeAddressAtIndex:row];
  }
}

- (IBAction)resetData:(id)sender {
  NSAlert *alert = [[NSAlert alloc] init];
  [alert setMessageText:@"Clear History"];
  [alert setInformativeText:@"Clears history, cookies, cache and more."];
  [alert setIcon:[NSImage imageNamed:NSImageNameCaution]];
  [alert addButtonWithTitle:@"Clear Data"];
  [alert addButtonWithTitle:@"Cancel"];
  [alert setAlertStyle:NSAlertStyleWarning];
  [alert beginSheetModalForWindow:self.sheet
                completionHandler:^(NSModalResponse returnCode) {
                  if (returnCode == NSAlertFirstButtonReturn) {
                    [self clearWebViewHistory];
                  }
                }];
}

- (void)clearWebViewHistory {
  NSSet *websiteDataTypes = [WKWebsiteDataStore allWebsiteDataTypes];
  NSDate *since = [NSDate dateWithTimeIntervalSince1970:0];
  [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:websiteDataTypes
                                             modifiedSince:since
                                         completionHandler:^{
                                           NSLog(@"Web cache cleared");
                                         }];
}

#pragma mark -

- (void)addressListFetcher:(WVSSAddressListFetcher *)fetcher didFailWithError:(NSError *)error {
  NSLog(@"URLs fetcher encountered issue: %@", error.localizedDescription);
}

- (void)addressListFetcher:(WVSSAddressListFetcher *)fetcher
        didFinishWithArray:(NSArray *)response {
  [self.config.addresses removeAllObjects];
  [self.config.addresses addObjectsFromArray:response];
  [self.urlTable reloadData];

  // TODO(altse): tell delegate that the URL list had had updated.
  //_currentIndex = -1;
  //[self loadNext:nil];
}

#pragma mark Bundle

- (NSArray *)bundleHTML {
  NSString *resourcePath = [[NSBundle bundleForClass:[self class]] resourcePath];
  NSError *error = nil;
  NSArray *bundleResourceContents =
      [[NSFileManager defaultManager] contentsOfDirectoryAtPath:resourcePath error:&error];

  NSMutableArray *bundleURLs = [NSMutableArray array];
  for (NSString *filename in bundleResourceContents) {
    if ([[filename pathExtension] isEqual:@"html"]) {
      NSString *path = [resourcePath stringByAppendingPathComponent:filename];
      NSURL *urlForPath = [NSURL fileURLWithPath:path];
      WVSSAddress *address = [WVSSAddress addressWithURL:[urlForPath absoluteString] duration:180];
      [bundleURLs addObject:address];
    }
  }
  return [bundleURLs count] ? bundleURLs : nil;
}

#pragma mark - User Interface

- (NSWindow *)configureSheet {
  if (!self.sheet) {
    [self createSheetWindow];
    [self createCustomControls];
    [self initializeControlValues];
  }
  return self.sheet;
}

- (void)createSheetWindow {
  CGFloat windowWidth = 440;
  CGFloat windowHeight = 640;
  NSRect frame = NSMakeRect(0, 0, windowWidth, windowHeight);
  NSUInteger styleMask = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable;
  self.sheet = [[NSWindow alloc] initWithContentRect:frame
                                            styleMask:styleMask
                                              backing:NSBackingStoreBuffered
                                                defer:NO];
  self.sheet.title = @"LifeClock 设置";
  self.sheet.releasedWhenClosed = NO;
  self.sheetContents = self.sheet.contentView;
  self.sheet.delegate = self;
}

- (void)initializeControlValues {
  [self.timeFormatPopup removeAllItems];
  [self.timeFormatPopup addItemsWithTitles:@[@"00-23", @"01-12"]];
  if ([self.timeFormatPopup.itemTitles containsObject:self.config.timeFormat]) {
    [self.timeFormatPopup selectItemWithTitle:self.config.timeFormat];
  } else {
    [self.timeFormatPopup selectItemWithTitle:@"00-23"];
  }

  [self.birthDatePicker setDateValue:self.config.birthDate];
  [self.birthDatePicker setTimeZone:[NSTimeZone localTimeZone]];

  [self.scaleSlider setFloatValue:self.config.scale];
  [self.brightnessSlider setFloatValue:self.config.brightness];

  [self.showBackgroundCheckbox setState:self.config.showBackground ? NSControlStateValueOn : NSControlStateValueOff];
  [self.multiMonitorCheckbox setState:self.config.multiMonitor ? NSControlStateValueOn : NSControlStateValueOff];
  
  // 初始预览刷新（页面加载完成后的注入由 didFinishNavigation 回调处理）
  [self refreshPreview];
}

#pragma mark - 实时预览

- (void)refreshPreview {
  if (!self.previewWebView) return;
  
  NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
  formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
  formatter.timeZone = [NSTimeZone localTimeZone];
  formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss";
  
  // 预览用的 birthDate 也标准化为 00:00:00
  NSCalendar *calendar = [NSCalendar currentCalendar];
  NSDateComponents *components = [calendar components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond) fromDate:self.birthDatePicker.dateValue];
  components.hour = 0;
  components.minute = 0;
  components.second = 0;
  NSDate *previewBirthDate = [calendar dateFromComponents:components];
  NSString *birthDateStr = [formatter stringFromDate:previewBirthDate];
  
  NSString *timeFormat = self.timeFormatPopup.selectedItem.title;
  CGFloat scale = self.scaleSlider.floatValue;
  CGFloat brightness = self.brightnessSlider.floatValue;
  BOOL showBackground = self.showBackgroundCheckbox.state == NSControlStateValueOn;
  BOOL multiMonitor = self.multiMonitorCheckbox.state == NSControlStateValueOn;
  
  NSString *script = [NSString stringWithFormat:
    @"window.reconfigureScreenSaver({"
    "  timeFormat: '%@',"
    "  birthDate: new Date('%@'),"
    "  scale: %f,"
    "  brightness: %f,"
    "  showBackground: %d,"
    "  multiMonitor: %d"
    "});",
    timeFormat,
    birthDateStr,
    scale,
    brightness,
    (int)showBackground,
    (int)multiMonitor];
  
  [self.previewWebView evaluateJavaScript:script completionHandler:^(id _Nullable result, NSError * _Nullable error) {
    if (error) {
      NSLog(@"[LifeClock] 预览更新失败: %@", error.localizedDescription);
    }
  }];
}

- (IBAction)controlChanged:(id)sender {
  [self refreshPreview];
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
  if (webView == self.previewWebView) {
    [self refreshPreview];
  }
}

- (void)createCustomControls {
  NSView *containerView = self.sheetContents;

  CGFloat windowWidth = 440;
  CGFloat windowHeight = 640;
  CGFloat labelWidth = 72;
  CGFloat paddingX = 20;
  CGFloat controlWidth = windowWidth - paddingX - labelWidth - 12;
  CGFloat rowHeight = 24;
  CGFloat hintHeight = 14;
  CGFloat sectionGap = 8;
  CGFloat itemGap = 2;

  // 固定预览框为 384×216（16:9），与锁屏全屏比例一致
  CGFloat previewWidth = 384;
  CGFloat previewHeight = 216;

  CGFloat previewX = (windowWidth - previewWidth) / 2.0;

  CGFloat currentY = windowHeight - 30;

  // --- 实时预览区域 ---
  currentY -= 22;
  NSTextField *previewTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(previewX, currentY, 120, 22)];
  previewTitle.stringValue = @"实时预览";
  previewTitle.font = [NSFont boldSystemFontOfSize:12];
  previewTitle.textColor = [NSColor colorWithCalibratedWhite:0.6 alpha:1.0];
  previewTitle.bezeled = NO;
  previewTitle.drawsBackground = NO;
  previewTitle.editable = NO;
  previewTitle.selectable = NO;
  [containerView addSubview:previewTitle];

  currentY -= 4;
  self.previewWebView = [[WKWebView alloc] initWithFrame:NSMakeRect(previewX, currentY - previewHeight, previewWidth, previewHeight)];
  self.previewWebView.layer.cornerRadius = 4;
  self.previewWebView.layer.masksToBounds = YES;
  self.previewWebView.layer.borderWidth = 1;
  self.previewWebView.layer.borderColor = [NSColor colorWithCalibratedWhite:0.3 alpha:1.0].CGColor;
  self.previewWebView.navigationDelegate = self;
  self.previewWebView.autoresizingMask = NSViewWidthSizable;
  [self.previewWebView setValue:@(YES) forKey:@"drawsTransparentBackground"];
  [containerView addSubview:self.previewWebView];

  // 加载 index.html 到预览 WebView
  NSBundle *bundle = [NSBundle bundleForClass:self.class];
  NSString *path = [bundle pathForResource:@"index" ofType:@"html"];
  if (path) {
    NSURL *baseURL = [NSURL fileURLWithPath:path];
    [self.previewWebView loadFileURL:baseURL allowingReadAccessToURL:[baseURL URLByDeletingLastPathComponent]];
  }

  currentY -= (previewHeight + 4);
  currentY -= sectionGap;

  // --- Time Format ---
  currentY -= rowHeight;
  NSTextField *timeFormatLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(paddingX, currentY, labelWidth, rowHeight)];
  timeFormatLabel.stringValue = @"时间格式";
  timeFormatLabel.font = [NSFont systemFontOfSize:13];
  timeFormatLabel.alignment = NSTextAlignmentRight;
  timeFormatLabel.bezeled = NO;
  timeFormatLabel.drawsBackground = NO;
  timeFormatLabel.editable = NO;
  timeFormatLabel.selectable = NO;
  [containerView addSubview:timeFormatLabel];

  self.timeFormatPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(paddingX + labelWidth + 8, currentY, 100, rowHeight)];
  [self.timeFormatPopup addItemsWithTitles:@[@"00-23", @"01-12"]];
  [containerView addSubview:self.timeFormatPopup];

  currentY -= (hintHeight + itemGap);
  NSTextField *timeFormatHint = [[NSTextField alloc] initWithFrame:NSMakeRect(paddingX + labelWidth + 8, currentY, controlWidth, hintHeight)];
  timeFormatHint.stringValue = @"24 小时制 或 12 小时制";
  timeFormatHint.font = [NSFont systemFontOfSize:10];
  timeFormatHint.textColor = [NSColor colorWithCalibratedWhite:0.45 alpha:1.0];
  timeFormatHint.bezeled = NO;
  timeFormatHint.drawsBackground = NO;
  timeFormatHint.editable = NO;
  timeFormatHint.selectable = NO;
  [containerView addSubview:timeFormatHint];

  currentY -= sectionGap;

  // --- Birth Date ---
  currentY -= rowHeight;
  NSTextField *birthDateLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(paddingX, currentY, labelWidth, rowHeight)];
  birthDateLabel.stringValue = @"出生日期";
  birthDateLabel.font = [NSFont systemFontOfSize:13];
  birthDateLabel.alignment = NSTextAlignmentRight;
  birthDateLabel.bezeled = NO;
  birthDateLabel.drawsBackground = NO;
  birthDateLabel.editable = NO;
  birthDateLabel.selectable = NO;
  [containerView addSubview:birthDateLabel];

  self.birthDatePicker = [[NSDatePicker alloc] initWithFrame:NSMakeRect(paddingX + labelWidth + 8, currentY, 140, rowHeight)];
  self.birthDatePicker.datePickerStyle = NSDatePickerStyleTextFieldAndStepper;
  self.birthDatePicker.datePickerMode = NSDatePickerModeSingle;
  self.birthDatePicker.datePickerElements = NSDatePickerElementFlagYearMonthDay;
  self.birthDatePicker.timeZone = [NSTimeZone localTimeZone];
  [containerView addSubview:self.birthDatePicker];

  currentY -= (hintHeight + itemGap);
  NSTextField *birthDateHint = [[NSTextField alloc] initWithFrame:NSMakeRect(paddingX + labelWidth + 8, currentY, controlWidth, hintHeight)];
  birthDateHint.stringValue = @"设置出生年月日，时间从 00:00:00 开始计算";
  birthDateHint.font = [NSFont systemFontOfSize:10];
  birthDateHint.textColor = [NSColor colorWithCalibratedWhite:0.45 alpha:1.0];
  birthDateHint.bezeled = NO;
  birthDateHint.drawsBackground = NO;
  birthDateHint.editable = NO;
  birthDateHint.selectable = NO;
  [containerView addSubview:birthDateHint];

  currentY -= sectionGap;

  // --- Scale ---
  currentY -= rowHeight;
  NSTextField *scaleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(paddingX, currentY, labelWidth, rowHeight)];
  scaleLabel.stringValue = @"缩放";
  scaleLabel.font = [NSFont systemFontOfSize:13];
  scaleLabel.alignment = NSTextAlignmentRight;
  scaleLabel.bezeled = NO;
  scaleLabel.drawsBackground = NO;
  scaleLabel.editable = NO;
  scaleLabel.selectable = NO;
  [containerView addSubview:scaleLabel];

  self.scaleSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(paddingX + labelWidth + 8, currentY, controlWidth, rowHeight)];
  self.scaleSlider.minValue = 0.3;
  self.scaleSlider.maxValue = 1.0;
  self.scaleSlider.integerValue = NO;
  [containerView addSubview:self.scaleSlider];

  currentY -= (hintHeight + itemGap);
  NSTextField *scaleHint = [[NSTextField alloc] initWithFrame:NSMakeRect(paddingX + labelWidth + 8, currentY, controlWidth, hintHeight)];
  scaleHint.stringValue = @"调节时钟显示大小，范围 0.3 ~ 1.0";
  scaleHint.font = [NSFont systemFontOfSize:10];
  scaleHint.textColor = [NSColor colorWithCalibratedWhite:0.45 alpha:1.0];
  scaleHint.bezeled = NO;
  scaleHint.drawsBackground = NO;
  scaleHint.editable = NO;
  scaleHint.selectable = NO;
  [containerView addSubview:scaleHint];

  currentY -= sectionGap;

  // --- Brightness ---
  currentY -= rowHeight;
  NSTextField *brightnessLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(paddingX, currentY, labelWidth, rowHeight)];
  brightnessLabel.stringValue = @"亮度";
  brightnessLabel.font = [NSFont systemFontOfSize:13];
  brightnessLabel.alignment = NSTextAlignmentRight;
  brightnessLabel.bezeled = NO;
  brightnessLabel.drawsBackground = NO;
  brightnessLabel.editable = NO;
  brightnessLabel.selectable = NO;
  [containerView addSubview:brightnessLabel];

  self.brightnessSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(paddingX + labelWidth + 8, currentY, controlWidth, rowHeight)];
  self.brightnessSlider.minValue = 0.1;
  self.brightnessSlider.maxValue = 1.0;
  self.brightnessSlider.integerValue = NO;
  [containerView addSubview:self.brightnessSlider];

  currentY -= (hintHeight + itemGap);
  NSTextField *brightnessHint = [[NSTextField alloc] initWithFrame:NSMakeRect(paddingX + labelWidth + 8, currentY, controlWidth, hintHeight)];
  brightnessHint.stringValue = @"调节文字亮度，较低亮度适合暗环境";
  brightnessHint.font = [NSFont systemFontOfSize:10];
  brightnessHint.textColor = [NSColor colorWithCalibratedWhite:0.45 alpha:1.0];
  brightnessHint.bezeled = NO;
  brightnessHint.drawsBackground = NO;
  brightnessHint.editable = NO;
  brightnessHint.selectable = NO;
  [containerView addSubview:brightnessHint];

  currentY -= sectionGap;

  // --- Show Background ---
  currentY -= rowHeight;
  self.showBackgroundCheckbox = [[NSButton alloc] initWithFrame:NSMakeRect(paddingX + labelWidth + 8, currentY + 2, 200, rowHeight)];
  self.showBackgroundCheckbox.buttonType = NSButtonTypeSwitch;
  self.showBackgroundCheckbox.title = @"显示背景";
  self.showBackgroundCheckbox.font = [NSFont systemFontOfSize:13];
  [containerView addSubview:self.showBackgroundCheckbox];

  currentY -= (hintHeight + itemGap);
  NSTextField *bgHint = [[NSTextField alloc] initWithFrame:NSMakeRect(paddingX + labelWidth + 36, currentY, controlWidth, hintHeight)];
  bgHint.stringValue = @"关闭后背景变为透明";
  bgHint.font = [NSFont systemFontOfSize:10];
  bgHint.textColor = [NSColor colorWithCalibratedWhite:0.45 alpha:1.0];
  bgHint.bezeled = NO;
  bgHint.drawsBackground = NO;
  bgHint.editable = NO;
  bgHint.selectable = NO;
  [containerView addSubview:bgHint];

  currentY -= sectionGap;

  // --- Multi Monitor ---
  currentY -= rowHeight;
  self.multiMonitorCheckbox = [[NSButton alloc] initWithFrame:NSMakeRect(paddingX + labelWidth + 8, currentY + 2, 200, rowHeight)];
  self.multiMonitorCheckbox.buttonType = NSButtonTypeSwitch;
  self.multiMonitorCheckbox.title = @"多显示器显示";
  self.multiMonitorCheckbox.font = [NSFont systemFontOfSize:13];
  [containerView addSubview:self.multiMonitorCheckbox];

  currentY -= (hintHeight + itemGap);
  NSTextField *multiHint = [[NSTextField alloc] initWithFrame:NSMakeRect(paddingX + labelWidth + 36, currentY, controlWidth, hintHeight)];
  multiHint.stringValue = @"在所有连接的显示器上同时显示屏保";
  multiHint.font = [NSFont systemFontOfSize:10];
  multiHint.textColor = [NSColor colorWithCalibratedWhite:0.45 alpha:1.0];
  multiHint.bezeled = NO;
  multiHint.drawsBackground = NO;
  multiHint.editable = NO;
  multiHint.selectable = NO;
  [containerView addSubview:multiHint];

  // 根据实际内容动态调整窗口高度（用 contentSize 避免标题栏偏差）
  CGFloat finalContentHeight = (windowHeight - currentY) + 50;
  [self.sheet setContentSize:NSMakeSize(windowWidth, finalContentHeight)];

  // 底部按钮（窗口高度确定后添加，确保始终可见）
  CGFloat buttonY = 12;
  NSButton *cancelButton = [[NSButton alloc] initWithFrame:NSMakeRect(windowWidth - 170, buttonY, 70, 26)];
  cancelButton.buttonType = NSButtonTypeMomentaryPushIn;
  cancelButton.bezelStyle = NSBezelStyleRounded;
  cancelButton.title = @"取消";
  cancelButton.target = self;
  cancelButton.action = @selector(cancelConfigSheet:);
  [containerView addSubview:cancelButton];

  NSButton *okButton = [[NSButton alloc] initWithFrame:NSMakeRect(windowWidth - 90, buttonY, 70, 26)];
  okButton.buttonType = NSButtonTypeMomentaryPushIn;
  okButton.bezelStyle = NSBezelStyleRounded;
  okButton.title = @"确认";
  okButton.target = self;
  okButton.action = @selector(dismissConfigSheet:);
  [containerView addSubview:okButton];

  // 设置控件 target/action，实现实时预览联动
  self.timeFormatPopup.target = self;
  self.timeFormatPopup.action = @selector(controlChanged:);
  self.birthDatePicker.target = self;
  self.birthDatePicker.action = @selector(controlChanged:);
  self.scaleSlider.target = self;
  self.scaleSlider.action = @selector(controlChanged:);
  self.brightnessSlider.target = self;
  self.brightnessSlider.action = @selector(controlChanged:);
  self.showBackgroundCheckbox.target = self;
  self.showBackgroundCheckbox.action = @selector(controlChanged:);
  self.multiMonitorCheckbox.target = self;
  self.multiMonitorCheckbox.action = @selector(controlChanged:);
}


- (IBAction)dismissConfigSheet:(id)sender {
  [self synchronize];
  [self.delegate configController:self dismissConfigSheet:self.sheet];
}

- (IBAction)cancelConfigSheet:(id)sender {
  [self.delegate configController:self dismissConfigSheet:self.sheet];
}

#pragma mark - NSWindowDelegate

- (BOOL)windowShouldClose:(NSWindow *)sender {
  [self cancelConfigSheet:sender];
  return NO;
}

- (IBAction)confirmButtonClicked:(id)sender {
  [self synchronize];
  [self.delegate configController:self dismissConfigSheet:self.sheet];
}

#pragma mark NSTableView

- (NSView *)tableView:(NSTableView *)tableView
    viewForTableColumn:(NSTableColumn *)tableColumn
                   row:(NSInteger)row {
  // In IB the tableColumn has the identifier set to the same string as the keys in our dictionary
  NSString *identifier = [tableColumn identifier];

  WVSSAddress *address = [self.config.addresses objectAtIndex:row];

  if ([identifier isEqual:kTableColumnURL]) {
    NSTableCellView *cellView = [tableView makeViewWithIdentifier:identifier owner:self];
    cellView.textField.stringValue = address.url;
    return cellView;
  } else if ([identifier isEqual:kTableColumnTime]) {
    NSTableCellView *cellView = [tableView makeViewWithIdentifier:identifier owner:self];
    cellView.textField.stringValue = [[NSNumber numberWithLong:address.duration] stringValue];
    return cellView;
  } else if ([identifier isEqual:kTableColumnPreview]) {
    NSTableCellView *cellView = [tableView makeViewWithIdentifier:identifier owner:self];
    return cellView;
  } else {
    NSAssert1(NO, @"Unhandled table column identifier %@", identifier);
  }
  return nil;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
  return [self.config.addresses count];
}

- (BOOL)canDragRowsWithIndexes:(NSIndexSet *)rowIndexes atPoint:(NSPoint)mouseDownPoint {
  return YES;
}

- (BOOL)tableView:(NSTableView *)tv
    writeRowsWithIndexes:(NSIndexSet *)rowIndexes
            toPasteboard:(NSPasteboard *)pboard {
  // Copy the row numbers to the pasteboard.
  NSData *serializedIndexes = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes requiringSecureCoding:YES error:nil];
  [pboard declareTypes:[NSArray arrayWithObject:kURLTableRow] owner:self];
  [pboard setData:serializedIndexes forType:kURLTableRow];
  return YES;
}

- (NSDragOperation)tableView:(NSTableView *)tv
                validateDrop:(id)info
                 proposedRow:(NSInteger)row
       proposedDropOperation:(NSTableViewDropOperation)op {
  // Add code here to validate the drop
  return NSDragOperationEvery;
}

- (BOOL)tableView:(NSTableView *)aTableView
       acceptDrop:(id)info
              row:(NSInteger)row
    dropOperation:(NSTableViewDropOperation)operation {
  NSPasteboard *pboard = [info draggingPasteboard];
  NSData *rowData = [pboard dataForType:kURLTableRow];
  NSIndexSet *rowIndexes = [NSKeyedUnarchiver unarchivedObjectOfClasses:[NSSet setWithArray:@[[NSIndexSet class], [NSNumber class]]] fromData:rowData error:nil];
  NSInteger dragRow = [rowIndexes firstIndex];

  NSMutableArray *addresses = self.config.addresses;
  id draggedObject = [addresses objectAtIndex:dragRow];
  NSLog(@"draggedObject: %@", draggedObject);
  if (dragRow < row) {
    [addresses insertObject:draggedObject atIndex:row];
    [addresses removeObjectAtIndex:dragRow];
    //[self.urlList noteNumberOfRowsChanged];
    [self.urlTable reloadData];
  } else {
    [addresses removeObjectAtIndex:dragRow];
    [addresses insertObject:draggedObject atIndex:row];
    //[self.urlList noteNumberOfRowsChanged];
    [self.urlTable reloadData];
  }
  return YES;
}

#pragma mark -

- (IBAction)tableViewCellDidEdit:(NSTextField *)textField {
  NSTableColumn *column = [self.urlTable.tableColumns objectAtIndex:[self.urlTable columnForView:textField]];
  NSString *identifier = column.identifier;
  NSInteger row = [self.urlTable selectedRow];
  
  if ([identifier isEqual:kTableColumnURL]) {
    WVSSAddress *address = [self.config.addresses objectAtIndex:row];
    address.url = textField.stringValue;
  } else if ([identifier isEqual:kTableColumnTime]) {
    WVSSAddress *address = [self.config.addresses objectAtIndex:row];
    address.duration = [textField.stringValue intValue];
  }
  // I don't think we need to reload the table.
  //    [self.urlTable reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row]
  //                             columnIndexes:[NSIndexSet indexSetWithIndex:col]];
}

- (IBAction)toggleFetchingURLs:(id)sender {
  BOOL currentValue = self.config.shouldFetchAddressList;
  self.config.shouldFetchAddressList = !currentValue;
  [self.fetchURLCheckbox setIntegerValue:self.config.shouldFetchAddressList];
  [self.urlsURLField setEnabled:self.config.shouldFetchAddressList];
}

- (IBAction)previewButtonClicked:(NSButton *)sender {
  NSInteger row = [self.urlTable rowForView:sender.superview];
  
  WVSSAddress *address = [self.config.addresses objectAtIndex:row];
  [self openAddress:address];
}

- (void)openAddress:(WVSSAddress *)address {
  NSPoint mouse = NSEvent.mouseLocation;
  NSRect bounds = NSMakeRect(0, 0, 1024, 768);
  NSRect frame = NSOffsetRect(bounds, mouse.x - bounds.size.width / 2, mouse.y - bounds.size.height / 2);
  NSWindow *window = [[NSWindow alloc] initWithContentRect:NSIntegralRect(frame)
                                                 styleMask:NSWindowStyleMaskClosable|NSWindowStyleMaskTitled|NSWindowStyleMaskResizable
                                                   backing:NSBackingStoreBuffered defer:YES];

  WKWebView *webView = [WebViewScreenSaverView makeWebView:bounds];
  [window.contentView addSubview:webView];
  
  [[[NSWindowController alloc] initWithWindow:window] showWindow:window];
  [WebViewScreenSaverView loadAddress:address target:webView];
}

@end
