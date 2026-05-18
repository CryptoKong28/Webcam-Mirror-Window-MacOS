#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>

@interface MirrorViewController : NSViewController
- (void)prepareToShow;
- (void)pauseCamera;
- (void)stopCamera;
- (BOOL)isCameraRunning;
@end

@interface AppDelegate : NSObject <NSApplicationDelegate, NSPopoverDelegate>
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSPopover *popover;
@property(nonatomic, strong) MirrorViewController *mirrorViewController;
@end

@interface MirrorViewController ()
@property(nonatomic, strong) NSView *previewContainer;
@property(nonatomic, strong) NSTextField *messageLabel;
@property(nonatomic, strong) NSButton *settingsButton;
@property(nonatomic, strong) NSButton *quitButton;
@property(nonatomic, strong) AVCaptureSession *session;
@property(nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property(nonatomic) dispatch_queue_t sessionQueue;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];

    self.mirrorViewController = [[MirrorViewController alloc] init];
    self.popover = [[NSPopover alloc] init];
    self.popover.contentViewController = self.mirrorViewController;
    self.popover.contentSize = NSMakeSize(360, 300);
    self.popover.behavior = NSPopoverBehaviorTransient;
    self.popover.delegate = self;

    self.statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSSquareStatusItemLength];
    NSStatusBarButton *button = self.statusItem.button;
    NSImage *logoImage = [NSImage imageNamed:@"logo"];
    if (logoImage) {
        logoImage.size = NSMakeSize(18, 18);
        button.image = logoImage;
    } else {
        button.image = [NSImage imageWithSystemSymbolName:@"camera.viewfinder" accessibilityDescription:@"Mirror Check"];
        button.image.template = YES;
    }
    button.toolTip = @"Mirror Check";
    button.target = self;
    button.action = @selector(togglePopover:);
    [button sendActionOn:NSEventMaskLeftMouseUp | NSEventMaskRightMouseUp];
}

- (void)togglePopover:(NSStatusBarButton *)sender {
    if (NSApp.currentEvent.type == NSEventTypeRightMouseUp) {
        [self showMenu];
        return;
    }

    if (self.mirrorViewController.isCameraRunning) {
        [self.mirrorViewController stopCamera];
        [self.popover performClose:sender];
        return;
    }

    if (self.popover.shown) {
        [self.popover performClose:sender];
    } else {
        [self.mirrorViewController prepareToShow];
        [self.popover showRelativeToRect:sender.bounds ofView:sender preferredEdge:NSRectEdgeMinY];
        [self.popover.contentViewController.view.window makeKeyWindow];
    }
}

- (void)showMenu {
    NSMenu *menu = [[NSMenu alloc] init];
    [menu addItemWithTitle:@"Show Mirror" action:@selector(showMirrorFromMenu) keyEquivalent:@""];
    [menu addItemWithTitle:@"Stop Camera" action:@selector(stopCameraFromMenu) keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Quit Mirror Check" action:@selector(quit) keyEquivalent:@"q"];
    self.statusItem.menu = menu;
    [self.statusItem.button performClick:nil];
    self.statusItem.menu = nil;
}

- (void)showMirrorFromMenu {
    NSStatusBarButton *button = self.statusItem.button;
    if (!button) {
        return;
    }

    [self.mirrorViewController prepareToShow];
    [self.popover showRelativeToRect:button.bounds ofView:button preferredEdge:NSRectEdgeMinY];
}

- (void)stopCameraFromMenu {
    [self.mirrorViewController stopCamera];
    [self.popover performClose:nil];
}

- (void)quit {
    [NSApp terminate:nil];
}

- (void)popoverDidClose:(NSNotification *)notification {
    (void)notification;
    [self.mirrorViewController pauseCamera];
}

@end

@implementation MirrorViewController

- (instancetype)init {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _sessionQueue = dispatch_queue_create("MirrorCheck.CameraSession", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)loadView {
    NSView *root = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 360, 300)];
    root.wantsLayer = YES;
    root.layer.backgroundColor = NSColor.windowBackgroundColor.CGColor;

    self.previewContainer = [[NSView alloc] initWithFrame:NSZeroRect];
    self.previewContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.previewContainer.wantsLayer = YES;
    self.previewContainer.layer.backgroundColor = NSColor.blackColor.CGColor;
    self.previewContainer.layer.cornerRadius = 10.0;
    self.previewContainer.layer.masksToBounds = YES;

    self.messageLabel = [NSTextField labelWithString:@"Starting camera..."];
    self.messageLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.messageLabel.alignment = NSTextAlignmentCenter;
    self.messageLabel.lineBreakMode = NSLineBreakByWordWrapping;
    self.messageLabel.maximumNumberOfLines = 3;
    self.messageLabel.textColor = NSColor.secondaryLabelColor;

    self.settingsButton = [NSButton buttonWithTitle:@"Open Camera Privacy Settings" target:self action:@selector(openCameraSettings)];
    self.settingsButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.settingsButton.bezelStyle = NSBezelStyleRounded;
    self.settingsButton.hidden = YES;

    self.quitButton = [NSButton buttonWithTitle:@"Quit" target:NSApp action:@selector(terminate:)];
    self.quitButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.quitButton.bezelStyle = NSBezelStyleRounded;

    NSStackView *footer = [NSStackView stackViewWithViews:@[ self.settingsButton, self.quitButton ]];
    footer.translatesAutoresizingMaskIntoConstraints = NO;
    footer.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    footer.alignment = NSLayoutAttributeCenterY;
    footer.distribution = NSStackViewDistributionGravityAreas;
    footer.spacing = 8.0;

    [root addSubview:self.previewContainer];
    [root addSubview:self.messageLabel];
    [root addSubview:footer];

    [NSLayoutConstraint activateConstraints:@[
        [self.previewContainer.topAnchor constraintEqualToAnchor:root.topAnchor constant:12.0],
        [self.previewContainer.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:12.0],
        [self.previewContainer.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-12.0],
        [self.previewContainer.heightAnchor constraintEqualToAnchor:self.previewContainer.widthAnchor multiplier:0.72],

        [self.messageLabel.centerXAnchor constraintEqualToAnchor:self.previewContainer.centerXAnchor],
        [self.messageLabel.centerYAnchor constraintEqualToAnchor:self.previewContainer.centerYAnchor],
        [self.messageLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.previewContainer.leadingAnchor constant:16.0],
        [self.messageLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.previewContainer.trailingAnchor constant:-16.0],

        [footer.topAnchor constraintEqualToAnchor:self.previewContainer.bottomAnchor constant:10.0],
        [footer.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:12.0],
        [footer.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-12.0],
        [footer.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-12.0],
    ]];

    self.view = root;
}

- (void)viewDidLayout {
    [super viewDidLayout];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.previewLayer.frame = self.previewContainer.bounds;
    [CATransaction commit];
}

- (void)prepareToShow {
    [self checkPermissionAndStart];
}

- (void)pauseCamera {
    [self stopCamera];
}

- (void)stopCamera {
    AVCaptureSession *session = self.session;
    dispatch_async(self.sessionQueue, ^{
        [session stopRunning];
    });
}

- (BOOL)isCameraRunning {
    return self.session.running;
}

- (void)checkPermissionAndStart {
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    switch (status) {
        case AVAuthorizationStatusAuthorized:
            [self startCamera];
            break;
        case AVAuthorizationStatusNotDetermined: {
            [self showMessage:@"Waiting for camera permission..." settingsVisible:NO];
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (granted) {
                        [self startCamera];
                    } else {
                        [self showCameraDenied];
                    }
                });
            }];
            break;
        }
        case AVAuthorizationStatusDenied:
        case AVAuthorizationStatusRestricted:
            [self showCameraDenied];
            break;
    }
}

- (void)startCamera {
    [self showMessage:@"Starting camera..." settingsVisible:NO];

    if (!self.session) {
        [self configureSession];
    }

    AVCaptureSession *session = self.session;
    if (!session) {
        [self showMessage:@"No camera was found." settingsVisible:NO];
        return;
    }

    if (!self.previewLayer) {
        AVCaptureVideoPreviewLayer *layer = [AVCaptureVideoPreviewLayer layerWithSession:session];
        layer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        [layer setAffineTransform:CGAffineTransformMakeScale(-1.0, 1.0)];
        [self.previewContainer.layer addSublayer:layer];
        self.previewLayer = layer;
        self.view.needsLayout = YES;
        [self.view layoutSubtreeIfNeeded];
    }

    self.messageLabel.hidden = YES;
    self.settingsButton.hidden = YES;

    dispatch_async(self.sessionQueue, ^{
        if (!session.running) {
            [session startRunning];
        }
    });
}

- (void)configureSession {
    AVCaptureSession *newSession = [[AVCaptureSession alloc] init];
    newSession.sessionPreset = AVCaptureSessionPresetMedium;

    AVCaptureDevice *camera = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera
                                                                 mediaType:AVMediaTypeVideo
                                                                  position:AVCaptureDevicePositionFront];
    if (!camera) {
        camera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }

    if (!camera) {
        self.session = nil;
        return;
    }

    NSError *error = nil;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:camera error:&error];
    if (error || !input || ![newSession canAddInput:input]) {
        self.session = nil;
        return;
    }

    [newSession addInput:input];
    self.session = newSession;
}

- (void)showCameraDenied {
    [self showMessage:@"Camera access is off for Mirror Check." settingsVisible:YES];
}

- (void)showMessage:(NSString *)text settingsVisible:(BOOL)settingsVisible {
    self.messageLabel.stringValue = text;
    self.messageLabel.hidden = NO;
    self.settingsButton.hidden = !settingsVisible;
}

- (void)openCameraSettings {
    NSArray<NSString *> *urls = @[
        @"x-apple.systempreferences:com.apple.preference.security?Privacy_Camera",
        @"x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Camera",
    ];

    for (NSString *value in urls) {
        NSURL *url = [NSURL URLWithString:value];
        if (url && [NSWorkspace.sharedWorkspace openURL:url]) {
            return;
        }
    }
}

@end

int main(int argc, const char *argv[]) {
    (void)argc;
    (void)argv;

    @autoreleasepool {
        NSApplication *application = NSApplication.sharedApplication;
        AppDelegate *delegate = [[AppDelegate alloc] init];
        application.delegate = delegate;
        [application run];
    }

    return 0;
}
