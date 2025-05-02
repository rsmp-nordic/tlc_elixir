defmodule TlcElixirWeb.Components.TypingIndicator do
  use Phoenix.Component

  attr :typing_users, :list, required: true, doc: "List of users currently typing"

  def typing_indicator(assigns) do
    ~H"""
    <span :if={@typing_users != []} class="text-gray-500 text-sm">
      <%=
        case @typing_users do
          [user] ->
            "#{user.name} is typing..."
          [user1, user2] ->
            "#{user1.name} and #{user2.name} are typing..."
          [user1, user2 | _rest] ->
            "#{user1.name}, #{user2.name} and others are typing..."
        end
      %>
    </span>
    """
  end
end
