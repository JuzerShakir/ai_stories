# frozen_string_literal: true

class CreateStoryExcerptJob < ApplicationJob
  queue_as :default
  retry_on NoMethodError

  def perform(story_id:, current_user_id:)
    user = User.find(current_user_id)
    return if user.open_ai_token.blank?

    @client = OpenAI::Client.new(access_token: user.open_ai_token)

    story = Story.find(story_id)
    return unless story.pages.any?

    create_excerpt(story)
    CreateStoryTitleJob.perform_later(story_id:, current_user_id:)
  end

  private

  def create_excerpt(story)
    response = create_excerpt_content(story)
    puts response
    story.update(excerpt: response['choices'][0]['message']['content'].strip)
  end

  def create_excerpt_content(story)
    story_content = story.pages.order(number: :asc).pluck(:content).join("\n\n")

    @client.chat(
      parameters: {
        model: 'gpt-3.5-turbo',
        messages: [{ role: 'user', content: "#{story_content}\nTl;dr:" }],
        max_tokens: 200
      }
    )
  end
end
