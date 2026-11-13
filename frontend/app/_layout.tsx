import React from "react";
import { ActivityIndicator, View } from "react-native";
import { Stack } from "expo-router";
import { StatusBar } from "expo-status-bar";
import { useFonts } from "expo-font";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { SafeAreaProvider } from "react-native-safe-area-context";
import { GestureHandlerRootView } from "react-native-gesture-handler";
import { KeyboardProvider } from "react-native-keyboard-controller";
import { AuthProvider, useAuth } from "@/src/context/AuthContext";
import { ToastProvider } from "@/src/components/Toast";
import { useTheme } from "@/src/theme";

const queryClient = new QueryClient({ defaultOptions: { queries: { retry: 1, staleTime: 15000 } } });

function Gate() {
  const c = useTheme();
  const { user } = useAuth();
  // Prewarm icon font so icons render immediately (also on Expo Go Android)
  const [fontsLoaded] = useFonts({ Ionicons: require("@react-native-vector-icons/ionicons/fonts/Ionicons.ttf") });
  const ready = fontsLoaded && user !== undefined;

  if (!ready) {
    return (
      <View style={{ flex: 1, alignItems: "center", justifyContent: "center", backgroundColor: c.background }} testID="app-loading">
        <ActivityIndicator color={c.primary} size="large" />
      </View>
    );
  }
  const authed = !!user;
  const hasRole = !!user?.role;
  return (
    <Stack screenOptions={{ headerShown: false, contentStyle: { backgroundColor: c.background } }}>
      <Stack.Protected guard={!authed}>
        <Stack.Screen name="login" />
      </Stack.Protected>
      <Stack.Protected guard={authed && !hasRole}>
        <Stack.Screen name="onboarding" />
      </Stack.Protected>
      <Stack.Protected guard={authed && hasRole}>
        <Stack.Screen name="(tabs)" />
        <Stack.Screen name="campaign/[id]" />
        <Stack.Screen name="submit/[id]" options={{ presentation: "modal" }} />
        <Stack.Screen name="notifications" />
        <Stack.Screen name="withdraw" />
        <Stack.Screen name="topup" />
        <Stack.Screen name="new-campaign" />
      </Stack.Protected>
    </Stack>
  );
}

export default function RootLayout() {
  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <SafeAreaProvider>
        <KeyboardProvider>
          <QueryClientProvider client={queryClient}>
            <AuthProvider>
              <ToastProvider>
                <StatusBar style="auto" />
                <Gate />
              </ToastProvider>
            </AuthProvider>
          </QueryClientProvider>
        </KeyboardProvider>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}
