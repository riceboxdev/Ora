import { computed, ref } from 'vue';

// Theme state
const currentTheme = ref(null);
const isLoading = ref(false);

// Default theme configuration
const defaultTheme = {
    name: 'Default Light',
    colors: {
        background: '0 0% 100%',
        foreground: '222.2 84% 4.9%',
        card: '0 0% 100%',
        cardForeground: '222.2 84% 4.9%',
        popover: '0 0% 100%',
        popoverForeground: '222.2 84% 4.9%',
        primary: '221.2 83.2% 53.3%',
        primaryForeground: '210 40% 98%',
        secondary: '210 40% 96%',
        secondaryForeground: '222.2 84% 4.9%',
        muted: '210 40% 96%',
        mutedForeground: '215.4 16.3% 46.9%',
        accent: '210 40% 96%',
        accentForeground: '222.2 84% 4.9%',
        destructive: '0 84.2% 60.2%',
        destructiveForeground: '210 40% 98%',
        border: '214.3 31.8% 91.4%',
        input: '214.3 31.8% 91.4%',
        ring: '221.2 83.2% 53.3%',
    },
    radius: '0.5rem',
    mode: 'light'
};

// Theme presets
export const themePresets = {
    'default-light': {
        name: 'Default Light',
        ...defaultTheme
    },
    'default-dark': {
        name: 'Default Dark',
        colors: {
            background: '222.2 84% 4.9%',
            foreground: '210 40% 98%',
            card: '222.2 84% 4.9%',
            cardForeground: '210 40% 98%',
            popover: '222.2 84% 4.9%',
            popoverForeground: '210 40% 98%',
            primary: '217.2 91.2% 59.8%',
            primaryForeground: '222.2 84% 4.9%',
            secondary: '217.2 32.6% 17.5%',
            secondaryForeground: '210 40% 98%',
            muted: '217.2 32.6% 17.5%',
            mutedForeground: '215 20.2% 65.1%',
            accent: '217.2 32.6% 17.5%',
            accentForeground: '210 40% 98%',
            destructive: '0 62.8% 30.6%',
            destructiveForeground: '210 40% 98%',
            border: '217.2 32.6% 17.5%',
            input: '217.2 32.6% 17.5%',
            ring: '224.3 76.3% 94.1%',
        },
        radius: '0.5rem',
        mode: 'dark'
    },
    'ocean': {
        name: 'Ocean Blue',
        colors: {
            background: '210 20% 98%',
            foreground: '210 60% 10%',
            card: '210 20% 98%',
            cardForeground: '210 60% 10%',
            popover: '210 20% 98%',
            popoverForeground: '210 60% 10%',
            primary: '200 98% 39%',
            primaryForeground: '0 0% 100%',
            secondary: '210 40% 90%',
            secondaryForeground: '210 60% 10%',
            muted: '210 30% 93%',
            mutedForeground: '210 20% 40%',
            accent: '190 80% 50%',
            accentForeground: '0 0% 100%',
            destructive: '0 72% 51%',
            destructiveForeground: '0 0% 100%',
            border: '210 30% 85%',
            input: '210 30% 85%',
            ring: '200 98% 39%',
        },
        radius: '0.5rem',
        mode: 'light'
    },
    'forest': {
        name: 'Forest Green',
        colors: {
            background: '140 20% 97%',
            foreground: '140 60% 10%',
            card: '140 20% 97%',
            cardForeground: '140 60% 10%',
            popover: '140 20% 97%',
            popoverForeground: '140 60% 10%',
            primary: '145 63% 42%',
            primaryForeground: '0 0% 100%',
            secondary: '140 30% 88%',
            secondaryForeground: '140 60% 10%',
            muted: '140 20% 92%',
            mutedForeground: '140 20% 40%',
            accent: '160 60% 45%',
            accentForeground: '0 0% 100%',
            destructive: '0 72% 51%',
            destructiveForeground: '0 0% 100%',
            border: '140 25% 82%',
            input: '140 25% 82%',
            ring: '145 63% 42%',
        },
        radius: '0.5rem',
        mode: 'light'
    },
    'sunset': {
        name: 'Sunset Orange',
        colors: {
            background: '30 20% 98%',
            foreground: '30 60% 10%',
            card: '30 20% 98%',
            cardForeground: '30 60% 10%',
            popover: '30 20% 98%',
            popoverForeground: '30 60% 10%',
            primary: '25 95% 53%',
            primaryForeground: '0 0% 100%',
            secondary: '30 40% 90%',
            secondaryForeground: '30 60% 10%',
            muted: '30 30% 93%',
            mutedForeground: '30 20% 40%',
            accent: '15 90% 58%',
            accentForeground: '0 0% 100%',
            destructive: '0 72% 51%',
            destructiveForeground: '0 0% 100%',
            border: '30 30% 85%',
            input: '30 30% 85%',
            ring: '25 95% 53%',
        },
        radius: '0.5rem',
        mode: 'light'
    },
    'midnight': {
        name: 'Midnight Purple',
        colors: {
            background: '250 30% 10%',
            foreground: '250 10% 95%',
            card: '250 30% 12%',
            cardForeground: '250 10% 95%',
            popover: '250 30% 12%',
            popoverForeground: '250 10% 95%',
            primary: '270 70% 60%',
            primaryForeground: '0 0% 100%',
            secondary: '250 20% 20%',
            secondaryForeground: '250 10% 95%',
            muted: '250 20% 18%',
            mutedForeground: '250 10% 60%',
            accent: '280 65% 55%',
            accentForeground: '0 0% 100%',
            destructive: '0 62% 45%',
            destructiveForeground: '0 0% 100%',
            border: '250 20% 25%',
            input: '250 20% 25%',
            ring: '270 70% 60%',
        },
        radius: '0.5rem',
        mode: 'dark'
    }
};

/**
 * Apply theme to document root
 */
export function applyTheme(theme) {
    if (!theme || !theme.colors) return;

    const root = document.documentElement;

    // Apply mode class
    if (theme.mode === 'dark') {
        root.classList.add('dark');
    } else {
        root.classList.remove('dark');
    }

    // Apply color CSS variables
    Object.entries(theme.colors).forEach(([key, value]) => {
        const cssVarName = `--${key.replace(/([A-Z])/g, '-$1').toLowerCase()}`;
        root.style.setProperty(cssVarName, value);
    });

    // Apply radius
    if (theme.radius) {
        root.style.setProperty('--radius', theme.radius);
    }

    currentTheme.value = theme;
}

/**
 * Save theme to localStorage
 */
export function saveThemeToLocalStorage(theme) {
    try {
        localStorage.setItem('ora-admin-theme', JSON.stringify(theme));
    } catch (error) {
        console.error('Failed to save theme to localStorage:', error);
    }
}

/**
 * Load theme from localStorage
 */
export function loadThemeFromLocalStorage() {
    try {
        const saved = localStorage.getItem('ora-admin-theme');
        return saved ? JSON.parse(saved) : null;
    } catch (error) {
        console.error('Failed to load theme from localStorage:', error);
        return null;
    }
}

/**
 * Save theme to backend (optional)
 */
export async function saveThemeToBackend(theme, api) {
    try {
        await api.post('/api/admin/settings', {
            theme: theme
        });
        return true;
    } catch (error) {
        console.error('Failed to save theme to backend:', error);
        return false;
    }
}

/**
 * Load theme from backend (optional)
 */
export async function loadThemeFromBackend(api) {
    try {
        const response = await api.get('/api/admin/settings');
        return response.data.settings?.theme || null;
    } catch (error) {
        console.error('Failed to load theme from backend:', error);
        return null;
    }
}

/**
 * Main theme composable
 */
export function useTheme() {
    const theme = computed(() => currentTheme.value);

    const setTheme = (newTheme) => {
        applyTheme(newTheme);
        saveThemeToLocalStorage(newTheme);
    };

    const loadAndApplyTheme = async (api = null) => {
        isLoading.value = true;

        try {
            // Try to load from backend if API is available
            let savedTheme = null;
            if (api) {
                savedTheme = await loadThemeFromBackend(api);
            }

            // Fallback to localStorage
            if (!savedTheme) {
                savedTheme = loadThemeFromLocalStorage();
            }

            // Apply saved theme or default
            const themeToApply = savedTheme || defaultTheme;
            applyTheme(themeToApply);
        } catch (error) {
            console.error('Error loading theme:', error);
            applyTheme(defaultTheme);
        } finally {
            isLoading.value = false;
        }
    };

    const resetTheme = () => {
        setTheme(defaultTheme);
    };

    const applyPreset = (presetName) => {
        const preset = themePresets[presetName];
        if (preset) {
            setTheme(preset);
        }
    };

    return {
        theme,
        isLoading: computed(() => isLoading.value),
        setTheme,
        loadAndApplyTheme,
        resetTheme,
        applyPreset,
        presets: themePresets,
        saveThemeToBackend
    };
}
