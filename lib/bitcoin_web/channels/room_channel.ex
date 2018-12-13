defmodule BitcoinWeb.RoomChannel do
    use Phoenix.Channel

    def join("room:lobby", _message, socket) do
        {:ok, socket}
    end
    
    def join(_room, _params, _socket) do
        {:error, %{reason: "Invalid"}}
    end

    def handle_in("new_message", body, socket) do
        push(socket, "new_message", body)
        {:noreply, socket}
    end
    
end