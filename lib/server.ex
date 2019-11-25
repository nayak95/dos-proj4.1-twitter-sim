defmodule Twitter.Server do
  use GenServer

  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg)
  end

  def init([]) do
    :ets.new(:registered_users, [:set, :private, :named_table])
    :ets.new(:tweets, [:bag, :private, :named_table])
    :ets.new(:hashtags, [:bag, :private, :named_table])
    :ets.new(:mentions, [:bag, :private, :named_table])
    :ets.new(:subscribers, [:bag, :private, :named_table])
    :ets.new(:subscribed_to, [:bag, :private, :named_table])
    :ets.new(:retweets, [:bag, :private, :named_table])
    {:ok, %{}}
  end

  # Register user
  def handle_call({:register_user, userId}, from, state) do
    {userPid, _} = from
    :ets.insert(:registered_users, {userId, userPid})
    IO.inspect(["Registered user", userId, userPid])
    {:reply, state, state}
  end

  # Deregister user
  def handle_call({:delete_user, userId}, from, state) do
    {_, registeredPid} = :ets.lookup(:registered_users, userId) |> Enum.at(0)
    {fromPid, _} = from
    if fromPid == registeredPid do
      :ets.delete(:registered_users, userId)
    end
    {:reply, state, state}
  end

  def handle_cast({:tweet_post, userId, tweet}, state) do
    time = System.monotonic_time()
    IO.puts("User #{userId} tweeted '#{tweet}'")
    :ets.insert(:tweets, {userId, tweet, time})
    find_hashtags(tweet) |> insert_hashtags(userId, tweet)
    find_mentions(tweet) |> handle_mentions(userId, tweet)
    {:noreply, state}
  end

  def handle_cast({:subscribe, userId, otherId}, state) do
    IO.inspect([userId, otherId])
    if userId != otherId do
      :ets.insert(:subscribers, {otherId, userId})
      :ets.insert(:subscribed_to, {userId, otherId})
    end
    {:noreply, state}
  end

  def handle_call({:get_subscribed_tweets, userId}, _from, state) do
    IO.inspect([userId, " is subscribed to "])
    ret = :ets.lookup(:subscribed_to, userId) |> Enum.map(fn {_, otherId} -> :ets.lookup(:tweets, otherId) end)
    {:reply, ret, state}
  end

  def handle_call({:retweet_post, userId, ownerId, tweet}, _from, state) do
    time = System.monotonic_time()
    IO.puts("User #{userId} retweeted Owner #{ownerId} - '#{tweet}'")
    :ets.insert(:retweets, {userId, ownerId, tweet, time})
    {:reply, state, state}
  end

  def handle_call({:get_hashtag_tweets, hashtag}, _from, state) do
    IO.puts("Query for #{hashtag}")
    ret = :ets.lookup(:hashtags, hashtag) |> Enum.map(fn {_, ownerId, tweet} ->
      :ets.lookup(:tweets, ownerId) |> Enum.find(fn {_, usertweet, _} -> usertweet == tweet end)
    end)
    IO.inspect(ret)
    {:reply, ret, state}
  end

  def handle_call({:get_mentioned_tweets, userId}, _from, state) do
    IO.puts("Query for @#{userId}")
    ret = :ets.lookup(:mentions, userId) |> Enum.map(fn {_, ownerId, tweet} ->
      :ets.lookup(:tweets, ownerId) |> Enum.find(fn {_, usertweet, _} -> usertweet == tweet end)
    end)
    IO.inspect(ret)
    {:reply, ret, state}
  end

  defp find_hashtags(tweet) do
    Regex.scan(~r/(#[?<hashtag>\w]+)/, tweet)
  end

  defp find_mentions(tweet) do
    Regex.scan(~r/@([?<hashtag>\w]+)/, tweet)
  end

  defp insert_hashtags(hashtags, userId, tweet) do
    hashtags |> Enum.each(fn [_, capture] ->
      :ets.insert(:hashtags, {capture, userId, tweet})
    end)
  end

  defp insert_mentions(mentions, userId, tweet) do
    mentions |> Enum.each(fn [_, capture] ->
      :ets.insert(:mentions, {String.to_integer(capture), userId, tweet})
    end)
  end

  defp send_tweet_to_mentioned(mentions) do
    :ok
  end

  defp handle_mentions(mentions, userId, tweet) do
    insert_mentions(mentions, userId, tweet)
    send_tweet_to_mentioned(mentions)
  end
end