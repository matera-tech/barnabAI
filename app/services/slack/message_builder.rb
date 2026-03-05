# frozen_string_literal: true

module Slack
  # See https://app.slack.com/block-kit-builder/ for reference on block structure and supported block types
  class MessageBuilder
    attr_accessor :text, :blocks, :attachments

    # @param text [String] The text content of the message (optional - only used in notifications if blocks are provided)
    # @param blocks [Array<Hash>] An array of block objects representing the message
    def initialize(text: nil, blocks: [])
      @text = text
      @blocks = blocks || []
      @attachments = []
    end

    def send!(channel:, thread_ts: nil)
      Slack::Client.send_message(channel:, thread_ts:, **to_h)
      nil
    end

    # Section block text limit imposed by the Slack API. Longer strings are
    # automatically moved to a collapsible attachment instead.
    SECTION_TEXT_MAX_LENGTH = 3000

    # @param text [String, Hash] The text content of the section block (string will be converted to mrkdwn format)
    # @param fields [String, Hash, Array<String|Hash>] An array of strings to be added as fields in the section block
    # @return [Slack::MessageBuilder] Returns self to allow chaining
    def add_section_block(text = nil, fields: nil)
      if text.is_a?(String) && text.length > SECTION_TEXT_MAX_LENGTH && fields.nil?
        return add_attachment(text)
      end

      block = { type: "section" }
      if text
        block[:text] = text.is_a?(String) ? { type: "mrkdwn", text: text } : text
      end
      if fields
        block[:fields] = Array.wrap(fields).map do |field|
          field.is_a?(String) ? { type: "mrkdwn", text: field } : field
        end
      end
      @blocks << block
      self
    end

    # @param elements [String, Hash, Array<String|Hash>] A single string, hash, or an array of strings and/or hashes to be added as context elements
    # @return [Slack::MessageBuilder] Returns self to allow chaining
    def add_context_block(*elements)
      @blocks << {
        type: "context",
        elements: elements.map { |e| e.is_a?(String) ? { type: "mrkdwn", text: e } : e }
      }
      self
    end

    # @param title [String] Title of the section
    # @return [Slack::MessageBuilder] Returns self to allow chaining
    def add_header_block(title)
      @blocks << {
        type: "header",
        text: {
          type: "plain_text",
          text: title,
          emoji: true
        },
      }
      self
    end

    def add_divider
      @blocks << { type: "divider" }
      self
    end

    # Adds a collapsible attachment. Slack auto-collapses long attachment text
    # behind a "See more" / "See less" toggle.
    # @param text [String] The mrkdwn text content
    # @param color [String, nil] Optional hex color for the left-side bar
    # @return [Slack::MessageBuilder] Returns self to allow chaining
    def add_attachment(text, color: nil)
      attachment = { text: text, mrkdwn_in: ["text"] }
      attachment[:color] = color if color
      @attachments << attachment
      self
    end

    # Convert to hash for Slack API
    def to_h
      result = {}
      result[:text] = @text if @text.present?
      result[:blocks] = @blocks if @blocks.present?
      result[:attachments] = @attachments if @attachments.present?
      result
    end

    class << self
      # @return Hash{Symbol => String} A helper method to create a Slack image element for context blocks
      def block_image_element(image_url, alt_text)
        { type: "image", image_url: image_url, alt_text: alt_text }
      end
    end

    private

    def truncate(text, max)
      return text if text.length <= max

      text[0, max - 1].concat("…")
    end
  end
end
