
#import <Foundation/Foundation.h>
#import "AllSensorsPlugin.h"
#import <CoreMotion/CoreMotion.h>

NSNotificationCenter *proximityObserver;

@implementation AllSensorsPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    CDYAccelerometerStreamHandler* accelerometerStreamHandler =
    [[CDYAccelerometerStreamHandler alloc] init];
    FlutterEventChannel* accelerometerChannel =
    [FlutterEventChannel eventChannelWithName:@"cindyu.com/all_sensors/accelerometer"
                              binaryMessenger:[registrar messenger]];
    CDYUserAccelStreamHandler* userAccelerometerStreamHandler =
    [[CDYUserAccelStreamHandler alloc] init];
    FlutterEventChannel* userAccelerometerChannel =
    [FlutterEventChannel eventChannelWithName:@"cindyu.com/all_sensors/user_accel"
                              binaryMessenger:[registrar messenger]];


    CDYGyroscopeStreamHandler* gyroscopeStreamHandler = [[CDYGyroscopeStreamHandler alloc] init];
    FlutterEventChannel* gyroscopeChannel =
    [FlutterEventChannel eventChannelWithName:@"cindyu.com/all_sensors/gyroscope"
                              binaryMessenger:[registrar messenger]];


    CDYProximityStreamHandler* proximityStreamHandler = [[CDYProximityStreamHandler alloc] init];
    FlutterEventChannel* proximityChannel =
    [FlutterEventChannel eventChannelWithName:@"cindyu.com/all_sensors/proximity"
                              binaryMessenger:[registrar messenger]];
    [proximityChannel setStreamHandler:proximityStreamHandler];

    NSProcessInfo* _processInfo;
    if (@available(iOS 14.0, *)) {
        BOOL isiOSAppOnMac = [NSProcessInfo processInfo].isiOSAppOnMac ? YES : NO;
        if(isiOSAppOnMac) {
        } else {
            [accelerometerChannel setStreamHandler:accelerometerStreamHandler];
            [userAccelerometerChannel setStreamHandler:userAccelerometerStreamHandler];
            [gyroscopeChannel setStreamHandler:gyroscopeStreamHandler];
        }
    } else {
        [accelerometerChannel setStreamHandler:accelerometerStreamHandler];
        [userAccelerometerChannel setStreamHandler:userAccelerometerStreamHandler];
        [gyroscopeChannel setStreamHandler:gyroscopeStreamHandler];
    }

    FlutterMethodChannel *methodChannel = [FlutterMethodChannel methodChannelWithName:@"cindyu.com/all_sensors"
                                                              binaryMessenger:registrar.messenger];

    [methodChannel setMethodCallHandler:^(FlutterMethodCall *call, FlutterResult result) {
        NSString *method = [call method];
        NSDictionary *arguments = [call arguments];

        if ([method isEqualToString:@"toggleProximityListener"]) {
            UIDevice *device = [UIDevice currentDevice];
            device.proximityMonitoringEnabled = [arguments[@"enabled"] boolValue];

            // Return if proximityListener is currently enabled. 
            result(nil);
        } else if ([method isEqualToString:@"toggleScreenOnProximityChanged"]) {
            // Does not work on iOS.
        } else {
          result(FlutterMethodNotImplemented);
        }
      }];
}

@end


const double GRAVITY_VAL = 9.8;
CMMotionManager* _cmMotionManager;

void _initCMMotionManager() {
    if (!_cmMotionManager) {
        _cmMotionManager = [[CMMotionManager alloc] init];
    }
}

static void sendTriplet(Float64 x, Float64 y, Float64 z, FlutterEventSink sink) {
    NSMutableData* event = [NSMutableData dataWithCapacity:3 * sizeof(Float64)];
    [event appendBytes:&x length:sizeof(Float64)];
    [event appendBytes:&y length:sizeof(Float64)];
    [event appendBytes:&z length:sizeof(Float64)];
    sink([FlutterStandardTypedData typedDataWithFloat64:event]);
}

@implementation CDYAccelerometerStreamHandler

- (FlutterError*)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)eventSink {
    _initCMMotionManager();
    [_cmMotionManager
     startAccelerometerUpdatesToQueue:[[NSOperationQueue alloc] init]
     withHandler:^(CMAccelerometerData* accelerometerData, NSError* error) {
         CMAcceleration acceleration = accelerometerData.acceleration;
         // Multiply by gravity, and adjust sign values to
         // align with Android.
         sendTriplet(-acceleration.x * GRAVITY_VAL, -acceleration.y * GRAVITY_VAL,
                     -acceleration.z * GRAVITY_VAL, eventSink);
     }];
    return nil;
}

- (FlutterError*)onCancelWithArguments:(id)arguments {
    [_cmMotionManager stopAccelerometerUpdates];
    return nil;
}

@end

@implementation CDYUserAccelStreamHandler

- (FlutterError*)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)eventSink {
    _initCMMotionManager();
    [_cmMotionManager
     startDeviceMotionUpdatesToQueue:[[NSOperationQueue alloc] init]
     withHandler:^(CMDeviceMotion* data, NSError* error) {
         CMAcceleration acceleration = data.userAcceleration;
         // Multiply by gravity, and adjust sign values to align with Android.
         sendTriplet(-acceleration.x * GRAVITY_VAL, -acceleration.y * GRAVITY_VAL,
                     -acceleration.z * GRAVITY_VAL, eventSink);
     }];
    return nil;
}

- (FlutterError*)onCancelWithArguments:(id)arguments {
    [_cmMotionManager stopDeviceMotionUpdates];
    return nil;
}

@end

@implementation CDYGyroscopeStreamHandler

- (FlutterError*)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)eventSink {
    _initCMMotionManager();
    [_cmMotionManager
     startGyroUpdatesToQueue:[[NSOperationQueue alloc] init]
     withHandler:^(CMGyroData* gyroData, NSError* error) {
         CMRotationRate rotationRate = gyroData.rotationRate;
         sendTriplet(rotationRate.x, rotationRate.y, rotationRate.z, eventSink);
     }];
    return nil;
}

- (FlutterError*)onCancelWithArguments:(id)arguments {
    [_cmMotionManager stopGyroUpdates];
    return nil;
}

@end

@implementation CDYProximityStreamHandler

- (FlutterError*) onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)eventSink {
    
    UIDevice *device = [UIDevice currentDevice];
    device.proximityMonitoringEnabled = YES;
    double proximityValue= device.proximityState ? 0 : 1;
    sendTriplet(proximityValue, proximityValue, proximityValue, eventSink);
    
    NSOperationQueue *mainQueue = [NSOperationQueue mainQueue];
    
    proximityObserver = [[NSNotificationCenter defaultCenter]
     addObserverForName:UIDeviceProximityStateDidChangeNotification
     object:nil
     queue:mainQueue
     usingBlock:^(NSNotification *note){
         UIDevice *device = [UIDevice currentDevice];
         double proximityValue= device.proximityState ? 0 : 1;
         sendTriplet(proximityValue, proximityValue, proximityValue, eventSink);
     }
     ];
    return nil;
    
}

- (FlutterError*)onCancelWithArguments:(id)arguments {
    [UIDevice currentDevice].proximityMonitoringEnabled = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:proximityObserver name:UIDeviceProximityStateDidChangeNotification object:nil];
    return nil;
}

@end
