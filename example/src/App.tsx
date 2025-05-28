import { useRef } from 'react';
import { Text, View, StyleSheet, Button } from 'react-native';
import { multiply } from 'react-native-shadow-nodes-experiments';

import ReactNativeInterface from 'react-native/Libraries/ReactPrivate/ReactNativePrivateInterface';

const result = multiply(3, 7);

export default function App() {
  const textRef = useRef(null);
  return (
    <View style={styles.container}>
      <Text ref={textRef}>Result: {result}</Text>
      <Button
        title="Click me"
        onPress={() => {
          const shadowNode = ReactNativeInterface.getNodeFromPublicInstance(
            textRef.current
          );
          // @ts-ignore
          globalThis.__testFunc(shadowNode);
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
