defmodule Snownix.Storage do
  @moduledoc """
  Upload service
  """

  alias ExAws.S3

  @doc """
  Upload a file to a specifice bucket S3
  """
  def upload_file(bucket, dest_path, file_binary) do
    image =
      S3.put_object(bucket, dest_path, file_binary)
      |> ExAws.request()

    if image do
      {:ok, generate_s3_link(bucket, dest_path)}
    else
      {:error}
    end
  end

  defp generate_s3_link(bucket, dest_path) do
    s3 = Application.fetch_env!(:ex_aws, :s3)

    case s3[:host] do
      nil ->
        dest_path

      _ ->
        Path.join(
          s3[:scheme] <> s3[:host] <> ":" <> Integer.to_string(s3[:port]) <> "/",
          Path.join(bucket, dest_path)
        )
    end
  end
end
