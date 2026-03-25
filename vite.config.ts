import { defineConfig } from 'vite'

export default defineConfig({
  server: {
    host: true,
    port: 5174,
    open: false,
    cors: true,
    // 禁用自动打开浏览器
    // 优化开发服务器性能
    watch: {
      ignored: ['**/node_modules/**', '**/dist/**', '**/docs/.vitepress/cache/**']
    }
  },
  optimizeDeps: {
    // 预构建依赖，减少初始加载时间
    include: ['vue', 'dayjs', 'medium-zoom', 'mermaid'],
    exclude: ['vitepress']
  },
  build: {
    // 优化生产构建
    minify: 'terser',
    terserOptions: {
      compress: {
        drop_console: true,
        drop_debugger: true
      }
    },
    // 启用CSS代码分割
    cssCodeSplit: true,
    // 启用rollup的 treeshaking
    rollupOptions: {
      output: {
        manualChunks: {
          // 分割大型依赖
          vendor: ['vue'],
          mermaid: ['mermaid']
        }
      }
    }
  }
})
