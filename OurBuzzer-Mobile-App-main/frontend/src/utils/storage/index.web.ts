export const storage = {
  getItem: async (key: string) => (typeof window === "undefined" ? null : window.localStorage.getItem(key)),
  setItem: async (key: string, value: string) => window.localStorage.setItem(key, value),
  removeItem: async (key: string) => window.localStorage.removeItem(key),
};
