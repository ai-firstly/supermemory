# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

这是 Supermemory 的 Ruby SDK，用于为 AI 应用添加持久化记忆功能。SDK 使用 Faraday 进行 HTTP 通信，支持文档管理、语义搜索、用户画像，以及与 Ruby AI 框架（ruby-openai、graph-agent、langchainrb）的集成。

## 常用命令

### 运行测试
```bash
bundle exec rspec                          # 运行所有测试
bundle exec rspec spec/supermemory/client_spec.rb  # 运行单个测试文件
```

### 代码质量
```bash
bundle exec rubocop                        # 运行 linter（CI 中允许失败）
```

### 构建
```bash
gem build supermemory.gemspec              # 构建 gem
gem install supermemory-*.gem              # 安装构建的 gem
```

## 代码架构

### 核心模块

- **[lib/supermemory/client.rb](lib/supermemory/client.rb)** - 主客户端类，处理 HTTP 请求、重试逻辑（408/409/429/5xx 状态码）、错误处理。使用 Faraday 连接池缓存（JSON 和 multipart 分别缓存）。
- **[lib/supermemory/configuration.rb](lib/supermemory/configuration.rb)** - 全局配置，支持 `Supermemory.configure` 块。环境变量：`SUPERMEMORY_API_KEY`、`SUPERMEMORY_BASE_URL`。
- **[lib/supermemory/errors.rb](lib/supermemory/errors.rb)** - 错误类层次结构，`ERROR_MAP` 将 HTTP 状态码映射到具体异常类。

### 资源层（Resources）

所有资源类继承自 [lib/supermemory/resources/base.rb](lib/supermemory/resources/base.rb)，每个资源通过 `client` 访问：

- **Documents** ([lib/supermemory/resources/documents.rb](lib/supermemory/resources/documents.rb)) - v3 API，文档 CRUD、批量操作、文件上传
- **Search** ([lib/supermemory/resources/search.rb](lib/supermemory/resources/search.rb)) - v3 文档搜索、v4 记忆搜索
- **Memories** - 记忆更新/��忘
- **Settings** - 用户设置管理
- **Connections** - OAuth 连接管理

### 集成层（Integrations）

位于 [lib/supermemory/integrations/](lib/supermemory/integrations/)：

- **[openai.rb](lib/supermemory/integrations/openai.rb)** - ruby-openai 集成
  - `SupermemoryTools` - OpenAI function calling 工具定义
  - `with_supermemory` - 包装 OpenAI 客户端，自动注入记忆到 system prompt
  - 三种模式：`profile`（用户画像）、`query`（搜索记忆）、`full`（两者结合）

- **[graph_agent.rb](lib/supermemory/integrations/graph_agent.rb)** - graph-agent 集成
  - `Nodes` 类提供预构建的图节点函数：`recall_memories`、`store_memory`、`search_memories`、`add_memory`
  - `build_memory_graph` - 构建完整的记忆增强图（recall → generate → store）

- **[langchain.rb](lib/supermemory/integrations/langchain.rb)** - langchainrb 集成
  - `SupermemoryTool` - Langchain 工具定义
  - `SupermemoryMemory` - 手动记忆管理类

### API 命名约定

SDK 使用 camelCase 参数发送给 API，但 Ruby 代码使用 snake_case：
- Ruby `container_tag` → API `containerTag`
- Ruby `custom_id` → API `customId`
- 转换在资源类方法中手动处理

## 测试

- 使用 RSpec + WebMock（禁用真实网络连接）
- [spec/spec_helper.rb](spec/spec_helper.rb) 在每次测试前配置测试 API key
- 集成测试位于 [spec/supermemory/integrations/](spec/supermemory/integrations/)

## 发布流程

由 [`.github/workflows/release.yml`](.github/workflows/release.yml) 自动处理，基于 git tags 触发。
