import React from "react";
import { Modal, Pressable, StyleSheet, Text, View } from "react-native";
import { KeyboardAwareScrollView } from "react-native-keyboard-controller";
import { useSafeAreaInsets } from "react-native-safe-area-context";
import { Ionicons } from "@react-native-vector-icons/ionicons";
import { useTheme } from "@/src/theme";

type Props = { visible: boolean; onClose: () => void; title: string; children: React.ReactNode; testID: string };

export function Sheet({ visible, onClose, title, children, testID }: Props) {
  const c = useTheme();
  const insets = useSafeAreaInsets();
  return (
    <Modal visible={visible} transparent animationType="slide" onRequestClose={onClose} statusBarTranslucent>
      <View style={[styles.backdrop, { backgroundColor: c.overlay }]}>
        <Pressable style={StyleSheet.absoluteFill} onPress={onClose} testID={`${testID}-backdrop`} />
        <View testID={testID} style={[styles.sheet, { backgroundColor: c.surface, paddingBottom: insets.bottom + 16 }]}>
          <View style={[styles.handle, { backgroundColor: c.border }]} />
          <View style={styles.head}>
            <Text style={[styles.title, { color: c.textPrimary }]}>{title}</Text>
            <Pressable testID={`${testID}-close`} onPress={onClose} hitSlop={12} style={[styles.close, { backgroundColor: c.surfaceMuted }]}>
              <Ionicons name="close" size={20} color={c.textPrimary} />
            </Pressable>
          </View>
          <KeyboardAwareScrollView bottomOffset={24} keyboardShouldPersistTaps="handled" contentContainerStyle={{ gap: 14, paddingHorizontal: 20 }}>
            {children}
          </KeyboardAwareScrollView>
        </View>
      </View>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: { flex: 1, justifyContent: "flex-end" },
  sheet: { borderTopLeftRadius: 24, borderTopRightRadius: 24, maxHeight: "88%", paddingTop: 8 },
  handle: { width: 40, height: 5, borderRadius: 3, alignSelf: "center", marginBottom: 8 },
  head: { flexDirection: "row", alignItems: "center", justifyContent: "space-between", paddingHorizontal: 20, paddingBottom: 12 },
  title: { fontSize: 18, fontWeight: "800", flex: 1 },
  close: { width: 36, height: 36, borderRadius: 18, alignItems: "center", justifyContent: "center" },
});
