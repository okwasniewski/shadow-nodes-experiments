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
  
  auto measureNode = jsi::Function::createFromHostFunction(
                    runtime,
                    jsi::PropNameID::forAscii(runtime, "__measureNode"),
                    1,
                    [](
                      jsi::Runtime& runtime,
                      const jsi::Value& /*thisValue*/,
                      const jsi::Value* arguments,
                      size_t count) -> jsi::Value {
                        if (count < 1) {
                            throw jsi::JSError(runtime, "measureNode expects 1 argument");
                        }
                        
                        ShadowNode::Shared shadowNode = shadowNodeFromValue(runtime, arguments[0]);
                        if (!shadowNode) {
                            throw jsi::JSError(runtime, "Invalid shadow node");
                        }
                        
                        auto layoutableShadowNode =
                             dynamic_pointer_cast<const LayoutableShadowNode>(shadowNode);
                        
                        
                        auto layout = layoutableShadowNode->getLayoutMetrics();
                        
                        auto object = jsi::Object(runtime);
                        object.setProperty(runtime, "width", layout.frame.size.width);
                        object.setProperty(runtime, "height", layout.frame.size.height);

                        return jsi::Value(runtime, std::move(object));
                  });
  
  runtime.global().setProperty(runtime, "__measureNode", std::move(measureNode));
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
    return std::make_shared<facebook::react::NativeShadowNodesExperimentsSpecJSI>(params);
}

@end
