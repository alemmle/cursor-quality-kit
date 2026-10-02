// Used only when the project lints with ESLint (requires eslint and typescript-eslint).
import { defineConfig } from 'eslint/config';
import tseslint from 'typescript-eslint';

export default defineConfig([
  tseslint.configs.recommended,
  {
    ignores: ['dist/**', 'coverage/**', 'drizzle/**'],
  },
  {
    rules: {
      '@typescript-eslint/no-explicit-any': 'error',
    },
  },
]);
