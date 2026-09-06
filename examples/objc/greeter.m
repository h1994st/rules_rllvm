#import <Foundation/Foundation.h>

#import "objc/greeter.h"

@interface RllvmGreeter : NSObject
- (int)value;
@end

@implementation RllvmGreeter
- (int)value {
  return 42;
}
@end

int rllvm_objc_value(void) {
  RllvmGreeter *greeter = [[RllvmGreeter alloc] init];
  return [greeter value];
}
