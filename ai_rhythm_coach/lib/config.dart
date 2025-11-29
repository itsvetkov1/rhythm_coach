enum AIProvider { anthropic, openai }

class AIConfig {
  // Default configuration for builds without API keys
  // Users should create their own config.dart with real API keys for production use
  static const AIProvider provider = AIProvider.anthropic;

  // Anthropic (Claude) API configuration
  static const String anthropicApiKey = 'YOUR_ANTHROPIC_API_KEY_HERE';
  static const String anthropicEndpoint = 'https://api.anthropic.com/v1/messages';
  static const String anthropicModel = 'claude-3-5-sonnet-20241022';

  // OpenAI (GPT) API configuration
  static const String openaiApiKey = 'YOUR_OPENAI_API_KEY_HERE';
  static const String openaiEndpoint = 'https://api.openai.com/v1/chat/completions';
  static const String openaiModel = 'gpt-4';
}
