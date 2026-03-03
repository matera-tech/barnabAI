# frozen_string_literal: true

class Recipes::BaseRecipe < Actions::BaseAction
  include Actions::HasFunctionMetadata

  function_stops_reflexion? true

  protected

  def channel_id
    context.channel_id || user.slack_user_id
  end

  def in_thread?
    context.thread_ts.present?
  end
end
