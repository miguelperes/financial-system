defmodule FinancialSystem do
  alias FinancialSystem.Account, as: Account

  @moduledoc """
  Implements functions to handle monetary transactions, such as 
  transfers (on `FinancialSystem.Account` structs), currency conversion and arithmetic operations on
  `Money` types.
  """

  @doc """
  Transfer the `value` amount of money from `source_account` to `destination_accounts`.<br/><br/>
  If `destination_accounts` is a single `FinancialSystem.Account`, a normal transfer is performed<br/>
  Returns `{:ok, {updated_source_account, updated_destination_account}}` if transfer was successfull, otherwise `{:error, reason}`.<br/><br/>
  If `destination_accounts` is a list of `FinancialSystem.Account`, it splits `value` evenly and transfer the resulting fraction to each of the accounts in the list.<br/>
  Returns `{:ok, {updated_source_account, updated_destination_account_list}}` if transfer was successfull, otherwise `{:error, reason}`.<br/><br/>

  ## Examples      

      iex> account1 = FinancialSystem.Account.new("10.50", :USD)
      iex> account2 = FinancialSystem.Account.new("0.0", :USD)
      iex> FinancialSystem.transfer(account1, account2, 5.0)
      {
        :ok,
        {
          %FinancialSystem.Account{account_id: nil, balance: Money.new("5.50", :USD)},
          %FinancialSystem.Account{account_id: nil, balance: Money.new("5.0", :USD)}
        }
      }

      iex> account1 = FinancialSystem.Account.new("10.50", :USD)
      iex> account2 = FinancialSystem.Account.new("0.0", :USD)
      iex> account3 = FinancialSystem.Account.new("500.0", :USD)
      iex> FinancialSystem.transfer(account3, [account1, account2], 100.0)
      {
        :ok,
        {
          %FinancialSystem.Account{account_id: nil, balance: Money.new("400.0", :USD)},
          [
            %FinancialSystem.Account{account_id: nil, balance: Money.new("60.50", :USD)},
            %FinancialSystem.Account{account_id: nil, balance: Money.new("50.0", :USD)}
          ]
        }
      }
  """
  @spec transfer(Account.t(), Account.t() | [Account.t()], float) ::
          {:ok, {Account.t(), Account.t() | [Account.t()]}} | {:error, String.t()}
  def transfer(source_account, destination_accounts, value) when is_list(destination_accounts) do
    case FinancialSystem.has_enough(source_account, value) do
      true ->
        splitted_amount = value / length(destination_accounts)

        transfers_result =
          Enum.map(destination_accounts, fn acc ->
            transfer!(source_account, acc, splitted_amount)
          end)

        updated_source_account = %FinancialSystem.Account{
          source_account
          | balance: FinancialSystem.sub(source_account.balance, value)
        }

        updated_destination_accounts =
          for {_source_result, dest_result} <- transfers_result do
            dest_result
          end

        {:ok, {updated_source_account, updated_destination_accounts}}

      false ->
        {:error, "Not enough money. (balance: #{source_account.balance.amount})"}
    end
  end

  def transfer(
        %Account{balance: %Money{currency: src_currency}} = source_account,
        %Account{balance: %Money{currency: dest_currency}} = destination_account,
        value
      ) do
    case FinancialSystem.has_enough(source_account, value) do
      true ->
        updated_source_account = %FinancialSystem.Account{
          source_account
          | balance: FinancialSystem.sub(source_account.balance, value)
        }

        converted_incoming_value =
          FinancialSystem.Currency.convert!(value, src_currency, dest_currency)

        updated_destination_account = %FinancialSystem.Account{
          destination_account
          | balance: FinancialSystem.add(destination_account.balance, converted_incoming_value)
        }

        {:ok, {updated_source_account, updated_destination_account}}

      false ->
        {:error, "Not enough money. (balance: #{source_account.balance.amount})"}
    end
  end

  @doc """
  Transfer the `value` amount of money from `source_account` to `destination_accounts`.<br/>
  Similar to `FinancialSystem.transfer/3`, but returns unwrapped.

  ## Examples      

      iex> account1 = FinancialSystem.Account.new("10.50", :USD)
      iex> account2 = FinancialSystem.Account.new("0.0", :USD)
      iex> FinancialSystem.transfer!(account1, account2, 5.0)
      {
        %FinancialSystem.Account{account_id: nil, balance: Money.new("5.50", :USD)},
        %FinancialSystem.Account{account_id: nil, balance: Money.new("5.0", :USD)}
      }

      iex> account1 = FinancialSystem.Account.new("10.50", :USD)
      iex> account2 = FinancialSystem.Account.new("0.0", :USD)
      iex> account3 = FinancialSystem.Account.new("500.0", :USD)
      iex> FinancialSystem.transfer!(account3, [account1, account2], 100.0)
      {
        %FinancialSystem.Account{account_id: nil, balance: Money.new("400.0", :USD)},
        [
          %FinancialSystem.Account{account_id: nil, balance: Money.new("60.50", :USD)},
          %FinancialSystem.Account{account_id: nil, balance: Money.new("50.0", :USD)}
        ]
      }
  """
  @spec transfer(Account.t(), Account.t() | [Account.t()], float) ::
          {Account.t(), Account.t() | [Account.t()]} | no_return
  def transfer!(source_account, destination_account, value) do
    case transfer(source_account, destination_account, value) do
      {:ok, result} -> result
      {:error, reason} -> raise(reason)
    end
  end

  @doc """
  Returns a new `Money` structure with `value` added to original `money`

  ## Examples
      iex> FinancialSystem.add(Money.new("10.0", :BRL), 10.50)
      Money.new("20.5", :BRL)

      iex> FinancialSystem.add(Money.new("10.0", :BRL), Decimal.new(10.50))
      Money.new("20.5", :BRL)
  """
  @spec add(Money.t(), float | integer | String.t() | Decimal.t()) :: Money.t()
  def add(money, value) when is_float(value) or is_integer(value) or is_binary(value) do
    FinancialSystem.add(money, Decimal.new(value))
  end

  def add(%Money{amount: amount, currency: currency}, value) do
    amount
    |> Decimal.add(value)
    |> Money.new(currency)
  end

  @doc """
  Returns a new `Money` structure with `value` subtracted from original `money`

  ## Examples
      iex> FinancialSystem.sub(Money.new("10.0", :BRL), 5.0)
      Money.new("5.0", :BRL)
  """
  @spec add(Money.t(), float | integer | String.t() | Decimal.t()) :: Money.t()
  def sub(money, value) when is_float(value) or is_integer(value) do
    FinancialSystem.sub(money, Decimal.new(value))
  end

  def sub(%Money{amount: amount, currency: currency}, value) do
    amount
    |> Decimal.sub(value)
    |> Money.new(currency)
  end

  @doc """
  Determines if an account has more than the specified `value`. Returns a `boolean`.

  ## Examples
      iex> account = FinancialSystem.Account.new("10.50", :USD)
      iex> FinancialSystem.has_enough(account, 5.0)
      true

      iex> account = FinancialSystem.Account.new("10.50", :USD)
      iex> FinancialSystem.has_enough(account, 11.0)
      false
  """
  @spec has_enough(Account.t(), float) :: boolean
  def has_enough(%FinancialSystem.Account{balance: money}, value) do
    Decimal.to_float(money.amount) >= value
  end
end
