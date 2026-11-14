# frozen_string_literal: true

class AddDoorkeeperClientMetadataAndResourceIndicators < ActiveRecord::Migration[8.1]
  def change
    add_column :oauth_applications, :client_id_metadata_materialized_at, :datetime
    add_column :oauth_access_grants, :resource, :text
    add_column :oauth_access_tokens, :resource, :text
  end
end
