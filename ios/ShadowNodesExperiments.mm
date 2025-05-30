#import "ShadowNodesExperiments.h"
#import <jsi/jsi.h>
#import "RCTTurboModuleWithJSIBindings.h"
#include <iostream>
#include <react/renderer/uimanager/primitives.h>
#include <react/renderer/core/LayoutableShadowNode.h>
#import <React/RCTScheduler.h>
#import <React/RCTSurfacePresenter.h>
#import <React/RCTSurfacePresenterStub.h>
#include <react/renderer/uimanager/UIManagerMountHook.h>
#include <react/renderer/uimanager/UIManagerBinding.h>

using namespace facebook;
using namespace facebook::react;

using AffectedNodes = std::unordered_map<const ShadowNodeFamily*, std::unordered_set<int>>;

using ShadowLeafUpdates = std::unordered_map<const ShadowNodeFamily*, folly::dynamic>;

class ExperimentalCommitHook : public UIManagerCommitHook {
public:
  ExperimentalCommitHook(const std::shared_ptr<UIManager> &uiManager)
    : uiManager_(uiManager) {
    uiManager_->registerCommitHook(*this);
  }

  ~ExperimentalCommitHook() noexcept override {
    uiManager_->unregisterCommitHook(*this);
  }

  void commitHookWasRegistered(UIManager const &) noexcept override {}

  void commitHookWasUnregistered(UIManager const &) noexcept override {}

  RootShadowNode::Unshared shadowTreeWillCommit(
      ShadowTree const &shadowTree,
      RootShadowNode::Shared const &oldRootShadowNode,
      RootShadowNode::Unshared const &newRootShadowNode) noexcept override {
//    auto rootNode = newRootShadowNode->ShadowNode::clone(ShadowNodeFragment{});
      NSLog(@"shadowTreeWillCommit: %d", newRootShadowNode->revision_);
    
    return std::static_pointer_cast<RootShadowNode>(newRootShadowNode);
  }
    
private:
  std::shared_ptr<UIManager> uiManager_;
};

class ExperimentalMountHook : public UIManagerMountHook {
public:
  
  ExperimentalMountHook(const std::shared_ptr<UIManager> &uiManager)
  : uiManager_(uiManager) {
    uiManager_->registerMountHook(*this);
  }
  
  ~ExperimentalMountHook() noexcept override {
    uiManager_->unregisterMountHook(*this);
  }
  
  void shadowTreeDidMount(const RootShadowNode::Shared &rootShadowNode, double mountTime) noexcept  override {
    NSLog(@"shadowTreeDidMount");
  }

  void shadowTreeDidUnmount(SurfaceId, double) noexcept override {
    NSLog(@"shadowTreeDidUnmount");
  }
    
private:
  std::shared_ptr<UIManager> uiManager_;
};



@interface ShadowNodesExperiments () <RCTTurboModuleWithJSIBindings>

@end

@implementation ShadowNodesExperiments {
  __weak RCTSurfacePresenter* _surfacePresenter;
  std::shared_ptr<ExperimentalCommitHook> commitHook_;
  std::shared_ptr<ExperimentalMountHook> mountHook_;
}
RCT_EXPORT_MODULE()

- (NSNumber *)multiply:(double)a b:(double)b {
    NSNumber *result = @(a * b);

    return result;
}

ShadowNode::Unshared cloneShadowTree(const ShadowNode &shadowNode, ShadowLeafUpdates& updates, AffectedNodes& affectedNodes) {
    const auto family = &shadowNode.getFamily();
    const auto rawPropsIt = updates.find(family);
    const auto childrenIt = affectedNodes.find(family);

    // Only copy children if we need to update them
    std::shared_ptr<ShadowNode::ListOfShared> childrenPtr;
    const auto& originalChildren = shadowNode.getChildren();

    if (childrenIt != affectedNodes.end()) {
        auto children = originalChildren;

        for (const auto index : childrenIt->second) {
            children[index] = cloneShadowTree(*children[index], updates, affectedNodes);
        }

        childrenPtr = std::make_shared<ShadowNode::ListOfShared>(std::move(children));
    } else {
        childrenPtr = std::make_shared<ShadowNode::ListOfShared>(originalChildren);
    }

    Props::Shared updatedProps = nullptr;

    if (rawPropsIt != updates.end()) {
        const auto& componentDescriptor = shadowNode.getComponentDescriptor();
        const auto& props = shadowNode.getProps();

        PropsParserContext propsParserContext{
            shadowNode.getSurfaceId(),
            *shadowNode.getContextContainer()
        };

        folly::dynamic newProps;
        #ifdef ANDROID
            auto safeProps = rawPropsIt->second == nullptr
                ? folly::dynamic::object()
                : rawPropsIt->second;
            newProps = folly::dynamic::merge(props->rawProps, safeProps);
        #else
            newProps = rawPropsIt->second;
        #endif

        updatedProps = componentDescriptor.cloneProps(
            propsParserContext,
            props,
            RawProps(newProps)
        );
    }
  
  auto clone = shadowNode.clone({
    updatedProps ? updatedProps : ShadowNodeFragment::propsPlaceholder(),
    childrenPtr,
    shadowNode.getState()
  });
  
  // Do it with Layoutable Shadow Node.
  
//  if (const auto layoutableNode = std::dynamic_pointer_cast<YogaLayoutableShadowNode>(clone)) {
//    layoutableNode->setSize({.width = 300, .height = 300});
//  }
  
  return clone;
}

AffectedNodes findAffectedNodes(const RootShadowNode& rootNode, ShadowLeafUpdates& updates) {
    AffectedNodes affectedNodes;

    for (const auto& [family, _] : updates) {
        auto familyAncestors = family->getAncestors(rootNode);

        for (auto it = familyAncestors.rbegin(); it != familyAncestors.rend(); ++it) {
            const auto& [parentNode, index] = *it;
            const auto parentFamily = &parentNode.get().getFamily();
            auto [setIt, inserted] = affectedNodes.try_emplace(parentFamily, std::unordered_set<int>{});

            setIt->second.insert(index);
        }
    }

    return affectedNodes;
}

- (void)setSurfacePresenter:(id<RCTSurfacePresenterStub>)surfacePresenter
{
 _surfacePresenter = surfacePresenter;
}

- (void)installJSIBindingsWithRuntime:(facebook::jsi::Runtime &)runtime callInvoker:(const std::shared_ptr<facebook::react::CallInvoker> &)callinvoker {
  commitHook_ = std::make_shared<ExperimentalCommitHook>(_surfacePresenter.scheduler.uiManager);
  mountHook_ = std::make_shared<ExperimentalMountHook>(_surfacePresenter.scheduler.uiManager);

  
  auto measureNode = jsi::Function::createFromHostFunction(
                    runtime,
                    jsi::PropNameID::forAscii(runtime, "__updateSize"),
                    1,
                    [](
                      jsi::Runtime& runtime,
                      const jsi::Value& /*thisValue*/,
                      const jsi::Value* arguments,
                      size_t count) -> jsi::Value {
                        if (count < 2) {
                            throw jsi::JSError(runtime, "measureNode expects 2 argument");
                        }
                        
                        // Helper to retrieve shadow node from native state.
                        ShadowNode::Shared shadowNode = shadowNodeFromValue(runtime, arguments[0]);
                        
                        auto style = arguments[1].getObject(runtime);
                        
                        auto width = style.getProperty(runtime, "width").getNumber();
                        auto height = style.getProperty(runtime, "height").getNumber();
                        
                        if (!shadowNode) {
                            throw jsi::JSError(runtime, "Invalid shadow node");
                        }
                        
                        // Possible improvement: retrieve only this shadow tree not all of them.
                        auto componentSurfaceId = shadowNode->getSurfaceId();
                        
                        // Retrieve the registry of all shadow trees.
                        auto &shadowTreeRegistry = UIManagerBinding::getBinding(runtime)->getUIManager().getShadowTreeRegistry();
                        
                        // Visit just one surface id.
                        shadowTreeRegistry.visit(componentSurfaceId, [&shadowNode, width, height](const ShadowTree& shadowTree) {
                          auto rootNode = shadowTree.getCurrentRevision().rootShadowNode;
                          
                          
                          ShadowLeafUpdates updates = {};
                          
                          
//                          updates[&shadowNode->getFamily()] = folly::dynamic::object
//                          ("backgroundColor", 4294951115)("width", width)("height", height);
                          updates[&shadowNode->getFamily()] = folly::dynamic::object
                          ("backgroundColor", 4294951115)("transform", folly::dynamic::array(
                                                                                             folly::dynamic::object("scale", width),
                                                                                             folly::dynamic::object("rotate", width)
                                                                                             ));
//                          
                          
                          auto transaction = [&updates](const RootShadowNode& oldRootShadowNode) {
                            
                            auto affectedNodes = findAffectedNodes(oldRootShadowNode, updates);
                            

                            return  std::static_pointer_cast<RootShadowNode>(cloneShadowTree(
                                oldRootShadowNode,
                                updates,
                                affectedNodes
                            ));
                          };
                          
                          // commit once!
                          // CommitOptions:
                          // enableStateReconciliation: https://reactnative.dev/architecture/render-pipeline#react-native-renderer-state-updates
                          // mountSynchronously: must be true as this is update from C++ not React
                          shadowTree.commit(transaction, {false, true});
                        });

                        return jsi::Value::undefined();
                  });
  
  runtime.global().setProperty(runtime, "__updateSize", std::move(measureNode));
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
    return std::make_shared<facebook::react::NativeShadowNodesExperimentsSpecJSI>(params);
}

@end
