import { useEffect, useReducer, useRef, useState } from 'react';
import {
  View,
  StyleSheet,
  processColor,
  Button,
  TextInput,
  Alert,
  ScrollView,
  useWindowDimensions,
  Modal,
  Text,
} from 'react-native';
import { multiply } from 'react-native-shadow-nodes-experiments';

// @ts-ignore
import { getNodeFromPublicInstance } from 'react-native/Libraries/ReactPrivate/ReactNativePrivateInterface';

multiply(2, 3);

const useSleepCycle = () => {
  const isActiveRef = useRef(true);

  useEffect(() => {
    const sleep = (ms) => {
      const start = Date.now();
      while (Date.now() - start < ms) {
        // Blocking sleep - this will freeze the main thread
      }
    };

    const runCycle = async () => {
      console.log('RUN');
      while (isActiveRef.current) {
        // Sleep for 50ms (blocking)
        sleep(200);

        // Do nothing for 50ms (non-blocking)
        await new Promise((resolve) => setTimeout(resolve, 250));
      }
    };

    runCycle();

    // Cleanup function
    return () => {
      isActiveRef.current = false;
    };
  }, []);
};

export default function App() {
  const textRef = useRef(null);
  const [text, setText] = useState('Hello World');
  const size = useRef(100);
  console.log('pink: ', processColor('pink'));

  const [isAnimating, setIsAnimating] = useState(false);
  const animationRef = useRef(null);

  const startAnimation = () => {
    setIsAnimating(true);

    const animate = () => {
      const shadowNode = getNodeFromPublicInstance(textRef.current);
      // @ts-ignore JSI Exposed global Function
      globalThis.__updateSize(shadowNode, {
        width: size.current,
        height: size.current,
      });
      size.current += 0.1;

      // Continue animation
      animationRef.current = requestAnimationFrame(animate);
    };

    // Start the animation loop
    animationRef.current = requestAnimationFrame(animate);
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
      <TextInput multiline defaultValue={text} onChangeText={setText} />
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
      <Button
        title="Animate single"
        onPress={() => {
          const shadowNode = getNodeFromPublicInstance(textRef.current);
          // @ts-ignore JSI Exposed global Function
          globalThis.__updateSize(shadowNode, {
            width: size.current,
            height: size.current,
          });
          size.current += 1;
        }}
      />
      <Modal visible={false}>
        <View style={{ flex: 1, backgroundColor: 'orange' }}>
          <Text>Hello</Text>
        </View>
        <View
          style={{
            position: 'absolute',
            backgroundColor: 'red',
            width: '100%',
            height: 100,
            bottom: 0,
          }}
        />
      </Modal>
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
