defmodule MessagingService.Repo.Migrations.CreateMessages do
  use Ecto.Migration

  def change do
    create table(:messages) do
      add :direction, :string, null: false
      add :type, :string, null: false
      add :from, :string, null: false
      add :to, :string, null: false
      add :body, :text, null: false
      add :attachments, {:array, :string}
      add :timestamp, :utc_datetime, null: false
      add :provider, :string, null: false
      add :provider_message_id, :string, null: false
      add :metadata, :map, default: "{}"

      timestamps(type: :utc_datetime)
    end

    execute("""
    ALTER TABLE messages
    ADD COLUMN conversation_key TEXT GENERATED ALWAYS AS (
      LEAST("from","to") || '::' || GREATEST("from","to")
    ) STORED;
    """)

    create index(:messages, [:from, :to])
    create index(:messages, [:to])
    create index(:messages, [:timestamp])
    create index(:messages, [:inserted_at])
    create index(:messages, [:conversation_key])
  end
end
