import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GlmAiService {
  // 🌟 从环境变量读取 API Key
  static String get _apiKey => dotenv.env['GLM_API_KEY'] ?? '';
  static const String _apiUrl = 'https://open.bigmodel.cn/api/paas/v4/chat/completions';

  /// 🌟 架构师升级：增加 fullContext 参数，赋予 AI 全局感知能力
  static Stream<String> generateContentStream(String text, String actionType, {String? fullContext}) async* {
    String prompt = '';

    // 🌟 核心魔法：构建上下文语境保护罩
    String contextPrompt = '';
    if (fullContext != null && fullContext.trim().isNotEmpty) {
      contextPrompt = '\n\n【全局上下文参考】(请务必参考此笔记的全局语境来处理目标文本，保持基调一致):\n"""\n$fullContext\n"""\n\n';
    }

    // 🌟 设定 System Prompt 角色，并注入上下文
    switch (actionType) {
      case 'polish':
        prompt = '你是一个专业的文字编辑。请结合以下全局语境，润色【目标文本】，使其更加流畅、专业，修正错别字，不改变原意。$contextPrompt【目标文本】:\n$text';
        break;
      case 'expand':
        prompt = '你是一个创意作家。请结合以下全局语境，对【目标文本】进行合理扩写，增加细节和深度，使其与上下文严丝合缝。$contextPrompt【目标文本】:\n$text';
        break;
      case 'summarize':
        prompt = '你是一个速读专家。请结合全局语境，为【目标文本】提取核心摘要，要求简明扼要，使用Markdown项目符号列出。$contextPrompt【目标文本】:\n$text';
        break;
      case 'translate':
        prompt = '你是一个精通多国语言的翻译官。请结合全局语境，将【目标文本】进行信达雅的翻译。如果是中文则翻英文，外文则翻中文。$contextPrompt【目标文本】:\n$text';
        break;
      default:
        prompt = '请结合全局语境处理以下【目标文本】。$contextPrompt【目标文本】:\n$text';
    }

    // 🌟 使用 http.Request 才能处理流式响应
    final request = http.Request('POST', Uri.parse(_apiUrl))
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      })
      ..body = jsonEncode({
        'model': 'glm-4-flash',
        'messages': [
          {'role': 'user', 'content': prompt} // 现在的 prompt 包含了选中文本和整篇笔记！
        ],
        'temperature': 0.7,
        'stream': true,
      });

    // ... (下方网络请求和 SSE 流解析代码保持不变)

    try {
      final client = http.Client();
      // 等待服务器响应头
      final response = await client.send(request).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        final errorBytes = await response.stream.toBytes();
        final errorStr = utf8.decode(errorBytes);
        debugPrint('GLM 官方报错: $errorStr');
        throw Exception('API 拒绝 (状态码 ${response.statusCode})');
      }

      // 🌟 监听数据流，按行分割，逐帧解析 SSE 协议数据
      await for (final chunk in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (chunk.isEmpty) continue;

        // 智谱的流式数据都以 'data: ' 开头
        if (chunk.startsWith('data: ')) {
          final dataStr = chunk.substring(6); // 截取掉 'data: '

          if (dataStr == '[DONE]') {
            break; // 数据流结束信号
          }

          try {
            final data = jsonDecode(dataStr);
            // 🌟 流式返回的文本藏在 delta 里面，而不是 message
            final content = data['choices'][0]['delta']['content'];
            if (content != null && content.toString().isNotEmpty) {
              yield content; // 像挤牙膏一样，把这一小块文本吐出去
            }
          } catch (e) {
            debugPrint('解析流数据碎片异常: $e');
          }
        }
      }
      client.close();
    } catch (e) {
      debugPrint('底层网络/流报错: $e');
      throw Exception('请求失败: $e');
    }
  }
}