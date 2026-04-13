# NoteSync 🚀

**隐私优先、跨平台、拥有双引擎同步能力的第二大脑。**

NoteSync 不仅仅是一个笔记应用。它通过极客的方式解决了多端同步的痛点：既能通过 **WebDAV** 拥抱云端，也能通过 **局域网 P2P** 在内网实现闪电般的物理传输。

---

## ✨ 核心特性

### 🔐 双引擎同步系统 (Sync Engine V2)
- **WebDAV 云端同步**：支持坚果云、Nextcloud 等标准协议，实现多设备增量同步。
- **局域网 P2P 雷达**：
    - **零配置发现**：基于 mDNS 协议，设备间无需输入 IP，自动“握手”。
    - **物理流传输**：不仅同步文字，更支持图片附件的流式拉取。
    - **路径重写引擎**：智能解决 Windows 与 Android 之间物理路径不兼容的痛点。
- **冲突解决**：采用 LWW (Last Write Wins) 确定性算法，确保数据一致性。

### 🎨 现代感设计
- **Material Design 3**：全量应用 MD3 规范，支持深色模式。
- **动态 UI**：可视化存储看板、局域网设备扫描雷达。
- **流畅体验**：基于 Isar 高性能数据库，所有操作即时响应。

### 📝 创作与整理
- **富文本/Markdown**：支持图片插入、列表、任务清单。
- **多级整理**：强大的分类（Category）与标签（Tag）系统。

---

## 🛠️ 技术栈

- **Framework**: [Flutter](https://flutter.dev)
- **Database**: [Isar](https://isar.dev) (NoSQL, 高性能本地存储)
- **Networking**: [Shelf](https://pub.dev/packages/shelf) (本地微型服务), [nsd](https://pub.dev/packages/nsd) (mDNS 发现)
- **State Management**: [Provider](https://pub.dev/packages/provider)

---

