# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Dialects
      class OpenAiCompatible < Dialect
        class << self
          def can_translate?(_model_name)
            true
          end
        end

        def tokenizer
          llm_model&.tokenizer_class || DiscourseAi::Tokenizer::Llama3Tokenizer
        end

        def tools
          @tools ||= tools_dialect.translated_tools
        end

        def max_prompt_tokens
          return llm_model.max_prompt_tokens if llm_model&.max_prompt_tokens

          32_000
        end

        def translate
          translated = super

          return translated unless llm_model.lookup_custom_param("disable_system_prompt")

          system_and_user_msgs = translated.shift(2)
          user_msg = system_and_user_msgs.last
          user_msg[:content] = [system_and_user_msgs.first[:content], user_msg[:content]].join("\n")

          translated.unshift(user_msg)
        end

        private

        def system_msg(msg)
          msg = { role: "system", content: msg[:content] }

          if tools_dialect.instructions.present?
            msg[:content] = msg[:content].dup << "\n\n#{tools_dialect.instructions}"
          end

          msg
        end

        def model_msg(msg)
          { role: "assistant", content: msg[:content] }
        end

        def tool_call_msg(msg)
          translated = tools_dialect.from_raw_tool_call(msg)
          { role: "assistant", content: translated }
        end

        def tool_msg(msg)
          translated = tools_dialect.from_raw_tool(msg)
          { role: "user", content: translated }
        end

        def user_msg(msg)
          content = +""
          content << "#{msg[:id]}: " if msg[:id]
          content << msg[:content]

          message = { role: "user", content: content }

          message[:content] = inline_images(message[:content], msg) if vision_support?

          message
        end

        def inline_images(content, message)
          encoded_uploads = prompt.encoded_uploads(message)
          return content if encoded_uploads.blank?

          content_w_imgs =
            encoded_uploads.reduce([]) do |memo, details|
              memo << {
                type: "image_url",
                image_url: {
                  url: "data:#{details[:mime_type]};base64,#{details[:base64]}",
                },
              }
            end

          content_w_imgs << { type: "text", text: message[:content] }
        end
      end
    end
  end
end
