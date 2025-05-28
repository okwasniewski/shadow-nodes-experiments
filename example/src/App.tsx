import { useRef, useState } from 'react';
import { View, StyleSheet, Button, TextInput, Alert } from 'react-native';
import { multiply } from 'react-native-shadow-nodes-experiments';

// @ts-ignore
import { getNodeFromPublicInstance } from 'react-native/Libraries/ReactPrivate/ReactNativePrivateInterface';

multiply(2, 3);

export default function App() {
  const textRef = useRef(null);
  const [text, setText] = useState('Hello World');
  return (
    <View style={styles.container}>
      <TextInput
        multiline
        ref={textRef}
        defaultValue={text}
        onChangeText={setText}
      />
      <Button
        title="Measure Text Input"
        onPress={() => {
          const shadowNode = getNodeFromPublicInstance(textRef.current);
          // @ts-ignore JSI Exposed global Function
          const measuredSize = globalThis.__measureNode(shadowNode);
          Alert.alert('Measured Size', JSON.stringify(measuredSize, null, 2));
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
