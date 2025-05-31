import { useEffect, useRef, useState } from 'react';
import { View, StyleSheet, processColor, Button } from 'react-native';
import { multiply } from 'react-native-shadow-nodes-experiments';
import { runOnUI } from 'react-native-worklets';

// @ts-ignore
import { getNodeFromPublicInstance } from 'react-native/Libraries/ReactPrivate/ReactNativePrivateInterface';

multiply(2, 3);

export default function App() {
  const textRef = useRef(null);
  const pink = processColor('pink');

  const [isAnimating, setIsAnimating] = useState(false);
  const animationRef = useRef(null);

  // @ts-ignore JSI Exposed global Function
  const updateSize = globalThis.__updateSize;
  const nativeFabricUIManager = globalThis.nativeFabricUIManager;

  const startAnimation = () => {
    const shadowNode = getNodeFromPublicInstance(textRef.current);
    setIsAnimating(true);
    runOnUI(() => {
      globalThis.nativeFabricUIManager = nativeFabricUIManager;
      globalThis.size = globalThis.size || 100;
      const animate = () => {
        updateSize(shadowNode, {
          width: globalThis.size,
          height: globalThis.size,
          transform: [{ rotate: globalThis.size / 100 }],
          backgroundColor: pink,
        });
        globalThis.size += 5;

        // Continue animation
        requestAnimationFrame(animate);
      };

      // Start the animation loop
      requestAnimationFrame(animate);
    })();
  };

  const stopAnimation = () => {
    setIsAnimating(false);
    if (animationRef.current) {
      cancelAnimationFrame(animationRef.current);
      animationRef.current = null;
    }
  };

  // Clean up on unmount
  useEffect(() => {
    return () => {
      if (animationRef.current) {
        cancelAnimationFrame(animationRef.current);
      }
    };
  }, []);
  return (
    <View style={styles.container}>
      <View
        ref={textRef}
        style={{ backgroundColor: 'red', width: 100, height: 100 }}
      >
        <View
          style={{
            backgroundColor: 'blue',
            width: '100%',
            height: 50,
            position: 'absolute',
            bottom: 0,
          }}
        />
      </View>
      <Button
        title={isAnimating ? 'Stop' : 'Animate'}
        onPress={() => {
          if (isAnimating) {
            stopAnimation();
          } else {
            startAnimation();
          }
        }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
