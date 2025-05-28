#import "ShadowNodesExperiments.h"
#import <jsi/jsi.h>
#import "RCTTurboModuleWithJSIBindings.h"
#include <iostream>
#include <react/renderer/uimanager/primitives.h>
#include <react/renderer/core/LayoutableShadowNode.h>

using namespace facebook;
using namespace facebook::react;

@interface ShadowNodesExperiments () <RCTTurboModuleWithJSIBindings>

@end

@implementation ShadowNodesExperiments
RCT_EXPORT_MODULE()

- (NSNumber *)multiply:(double)a b:(double)b {
    NSNumber *result = @(a * b);

    return result;
}

- (void)installJSIBindingsWithRuntime:(facebook::jsi::Runtime &)runtime callInvoker:(const std::shared_ptr<facebook::react::CallInvoker> &)callinvoker {
  
  auto testFunc = jsi::Function::createFromHostFunction(
                    runtime,
                    jsi::PropNameID::forAscii(runtime, "__testFunc"),
                    1,
                    [](
                      jsi::Runtime& runtime,
                      const jsi::Value& /*thisValue*/,
                      const jsi::Value* arguments,
                      size_t count) -> jsi::Value {
                        ShadowNode::Shared shadowNode = shadowNodeFromValue(runtime, arguments[0]);
                        auto layoutableShadowNode =
                             dynamic_pointer_cast<const LayoutableShadowNode>(shadowNode);
                        
                        auto layout = layoutableShadowNode->getLayoutMetrics();
                        std::cout << "width: " << layout.frame.size.width << " height: " << layout.frame.size.height;
                         
                         return jsi::Value::undefined();
                  });
  
  runtime.global().setProperty(runtime, "__testFunc", std::move(testFunc));
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
    return std::make_shared<facebook::react::NativeShadowNodesExperimentsSpecJSI>(params);
}

@end
