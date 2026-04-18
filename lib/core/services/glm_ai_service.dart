import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class GlmAiService {
  // 🌟 将这里替换为你申请的智谱 API Key
  static const String _apiKey = 'fe3cc01c2be64bc8bafdc50a9acdf9de.a75pkGxtCg6tgOja';
  static const String _apiUrl = 'https://open.bigmodel.cn/api/paas/v4/chat/completions';

  /// 发起 AI 请求
  static Future<String> generateContent(String text, String actionType) async {
    String prompt = '';

    // 设定 System Prompt 角色
    switch (actionType) {
      case 'polish':
        prompt = '你是一个专业的文字编辑。请润色以下文本，使其更加流畅、专业，修正错别字，不改变原意：\n\n$text';
        break;
      case 'expand':
        prompt = '你是一个创意作家。请对以下文本进行扩写，增加细节和深度，使其更加丰富生动：\n\n$text';
        break;
      case 'summarize':
        prompt = '你是一个速读专家。请为以下文本提取核心摘要，要求简明扼要，最好用项目符号列出：\n\n$text';
        break;
      case 'translate':
        prompt = '你是一个精通多国语言的翻译官。如果以下文本是中文，请翻译成地道的英文；如果是外文，请翻译成优雅的中文：\n\n$text';
        break;
      default:
        prompt = '请处理以下文本：\n\n$text';
    }

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'glm-4-flash',
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.7,
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final decodedResponse = utf8.decode(response.bodyBytes);
        final data = jsonDecode(decodedResponse);
        return data['choices'][0]['message']['content'] ?? 'AI 返回了空内容。';
      } else {
        // 🌟 架构师修复：把智谱官方的真实报错原因提取出来！
        final decodedError = utf8.decode(response.bodyBytes);
        debugPrint('GLM 官方报错: $decodedError');
        throw Exception('API 拒绝 (状态码 ${response.statusCode})');
      }
    } catch (e) {
      debugPrint('底层网络报错: $e');
      // 🌟 让底部的弹窗直接显示真实的报错信息，而不是模糊的提示
      throw Exception('请求失败: $e');
    }
  }
}