import resolve from '@rollup/plugin-node-resolve';
import terser from '@rollup/plugin-terser';

export default {
  input: 'frontend/src/booking-app.js',
  output: {
    file: 'public/js/booking-app.bundle.js',
    format: 'es',
    sourcemap: true
  },
  plugins: [
    resolve(),
    terser()
  ]
};
