class MigrateRedcarpetToCommonMarker < ActiveRecord::Migration[7.2]
  def up
    Setting.where(name: 'text_formatting', value: 'markdown').update_all(value: 'common_mark')
  end

  def down
    # no-op
  end
end
