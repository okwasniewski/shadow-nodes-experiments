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

// Custom alias to store affected node
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

// Method to clone the shadow tree copied from Unistyles.
// This was upstreamed by @bartlomiejbloniarz https://github.com/facebook/react-native/pull/50624
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
                        
                        // Convert passed props to folly::dynamic.
                        auto follyDynamicProps = jsi::dynamicFromValue(runtime, arguments[1]);
                        
                        if (!shadowNode) {
                            throw jsi::JSError(runtime, "Invalid shadow node");
                        }
                        
                        // Get current component surface id.
                        auto componentSurfaceId = shadowNode->getSurfaceId();
                        
                        // Retrieve the registry of all shadow trees.
                        auto &shadowTreeRegistry = UIManagerBinding::getBinding(runtime)->getUIManager().getShadowTreeRegistry();
                        
                        // Visit just one surface id.
                        shadowTreeRegistry.visit(componentSurfaceId, [&shadowNode, &follyDynamicProps](const ShadowTree& shadowTree) {
                          // Retrieve root node of current revision.
                          // Revisions represent versions of the tree (new commit == new revision).
                          auto rootNode = shadowTree.getCurrentRevision().rootShadowNode;
                          
                          // Create a new leaf update, which is a std::unordered_map (ShadowNodeFamily: NewProps as folly dynamic)
                          ShadowLeafUpdates updates = {{&shadowNode->getFamily(), follyDynamicProps}};
                          
                          // Create a transaction that clones returns a new tree (after update).
                          auto transaction = [&updates](const RootShadowNode& oldRootShadowNode) {
                            // Find affected nodes (current one up and all its ancestors).
                            auto affectedNodes = findAffectedNodes(oldRootShadowNode, updates);
                            
                            // Return a clone of the tree to commit.
                            return std::static_pointer_cast<RootShadowNode>(cloneShadowTree(
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
