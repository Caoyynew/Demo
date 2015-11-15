//
//  PeripheralOperateManager.m
//  BlueTooth
//
//  Created by Kangqj on 15/11/2.
//  Copyright © 2015年 Kangqj. All rights reserved.
//

#import "PeripheralOperateManager.h"

@interface PeripheralOperateManager () <CBPeripheralManagerDelegate,CBPeripheralDelegate>
{
    NSTimer *timer;
}

@property(nonatomic, strong) CBPeripheralManager *peripheralManager;
@property(nonatomic, strong) CBMutableCharacteristic *readwriteCharacteristic;

@end

@implementation PeripheralOperateManager

+ (PeripheralOperateManager *)sharedManager
{
    static PeripheralOperateManager *instance = nil;
    static dispatch_once_t predicate;
    
    dispatch_once(&predicate, ^{
        instance = [[self alloc] init];
    });
    
    return instance;
}

- (id)init
{
    if (self)
    {
        self = [super init];
    }
    
    return self;
}

- (void)startBroadcastService
{
    self.peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
}

/*
typedef NS_OPTIONS(NSUInteger, CBCharacteristicProperties) {
    CBCharacteristicPropertyBroadcast=0x01,//广播,不允许本地特性
    CBCharacteristicPropertyRead=0x02,//可读
    CBCharacteristicPropertyWriteWithoutResponse=0x04,//可写,无反馈
    CBCharacteristicPropertyWrite=0x08,//可写
    CBCharacteristicPropertyNotify=0x10,//通知,无反馈
    CBCharacteristicPropertyIndicate=0x20,//标识
    CBCharacteristicPropertyAuthenticatedSignedWrites=0x40,//允许签名一个可写的特性
    CBCharacteristicPropertyExtendedProperties=0x80,//如果设置后，附加特性属性为一个扩展的属性说明，不允许本地特性
    CBCharacteristicPropertyNotifyEncryptionRequired NS_ENUM_AVAILABLE(NA, 6_0)=0x100,//如果设置后，仅允许信任的设备可以打开通知特性值
    CBCharacteristicPropertyIndicateEncryptionRequired NS_ENUM_AVAILABLE(NA, 6_0)=0x200//如果设置后，仅允许信任的设备可以打开标识特性值
};
 */

//添加服务
- (void)addServices
{
    CBUUID *descriptionStringUUID = [CBUUID UUIDWithString:CBUUIDCharacteristicUserDescriptionString];
    
    self.readwriteCharacteristic = [[CBMutableCharacteristic alloc]initWithType:[CBUUID UUIDWithString:CharacteristicUUID] properties:CBCharacteristicPropertyNotify | CBCharacteristicPropertyWrite | CBCharacteristicPropertyRead value:nil permissions:CBAttributePermissionsReadable | CBAttributePermissionsWriteable];
    
    CBMutableDescriptor *readwriteCharacteristicDescription1 = [[CBMutableDescriptor alloc]initWithType: descriptionStringUUID value:@"name"];
    [self.readwriteCharacteristic setDescriptors:@[readwriteCharacteristicDescription1]];
    
    
    CBMutableService *service = [[CBMutableService alloc]initWithType:[CBUUID UUIDWithString:ServiceUUID] primary:YES];
    [service setCharacteristics:@[self.readwriteCharacteristic]];
    
    [self.peripheralManager addService:service];
}

- (void)stopBroadcastService
{
    [self.peripheralManager stopAdvertising];
    
    self.peripheralManager.delegate = nil;
    self.peripheralManager = nil;
}

//发送数据
- (void)sendPeripgeralData:(NSString *)string
{
    [self.peripheralManager updateValue:[string dataUsingEncoding:NSUTF8StringEncoding] forCharacteristic:self.readwriteCharacteristic onSubscribedCentrals:nil];
}

//接收数据
- (void)reciveData:(ReceiveDataBlock)receive
{
    self.receiveBlock = receive;
}


#pragma  mark -- CBPeripheralManagerDelegate
- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    switch (peripheral.state)
    {
        case CBPeripheralManagerStatePoweredOn:
            [self addServices];
            break;
        case CBPeripheralManagerStatePoweredOff:
            [self.peripheralManager stopAdvertising];
            break;
            
        default:
            break;
    }
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error
{
    if (error == nil)
    {
        [self.peripheralManager startAdvertising:@{CBAdvertisementDataServiceUUIDsKey:@[[CBUUID UUIDWithString:ServiceUUID]],
                                                   CBAdvertisementDataLocalNameKey:NameKey}];
    }
    else
    {
        NSLog(@"didAddService:error:%@",error);
    }
}

//peripheral开始发送advertising
- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error{
    
}

//订阅characteristics
-(void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
    NSLog(@"订阅了 %@的数据",characteristic.UUID);
}

//取消订阅characteristics
-(void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic{
    
}

//发送数据，发送当前时间的秒数
-(BOOL)sendData
{    
    NSString *picPath = [[NSBundle mainBundle] pathForResource:@"10M" ofType:@"png"];
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:picPath];
    [handle seekToFileOffset:0];
    NSData *segmentData = [handle readDataOfLength:150];
    [handle closeFile];
    NSLog(@"sendData:%ld",segmentData.length);
    return [self.peripheralManager updateValue:segmentData forCharacteristic:self.readwriteCharacteristic onSubscribedCentrals:nil];
}


//读characteristics请求
- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveReadRequest:(CBATTRequest *)request{
    
    //判断是否有读数据的权限
    if (request.characteristic.properties & CBCharacteristicPropertyRead) {
        NSData *data = request.characteristic.value;
        [request setValue:data];
        //对请求作出成功响应
        [self.peripheralManager respondToRequest:request withResult:CBATTErrorSuccess];
    }else{
        [self.peripheralManager respondToRequest:request withResult:CBATTErrorWriteNotPermitted];
    }
}

//写characteristics请求
- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray *)requests{
    
    CBATTRequest *request = requests[0];
    
    //判断是否有写数据的权限
    if (request.characteristic.properties & CBCharacteristicPropertyWrite) {
        
        CBMutableCharacteristic *c =(CBMutableCharacteristic *)request.characteristic;
        c.value = request.value;
        NSString *dataStr = [[NSString alloc] initWithData:request.value encoding:NSUTF8StringEncoding];
        NSLog(@"didReceiveWriteRequests:%@",dataStr);
        if ([dataStr isEqualToString:BumpKey])
        {
            [self sendData];
        }
        
//        if (self.receiveBlock)
//        {
//            self.receiveBlock(request.value);
//        }
        
        [self.peripheralManager respondToRequest:request withResult:CBATTErrorSuccess];
    }else{
        [self.peripheralManager respondToRequest:request withResult:CBATTErrorWriteNotPermitted];
    }
}

- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral{
    NSLog(@"peripheralManagerIsReadyToUpdateSubscribers");
    
}

@end
