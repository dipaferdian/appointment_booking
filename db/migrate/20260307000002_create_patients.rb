class CreatePatients < ActiveRecord::Migration[8.1]
  def change
    create_table :patients do |t|
      t.string :external_id, null: false
      t.string :name, null: false
      t.string :phone
      t.string :email

      t.timestamps
    end

    add_index :patients, :external_id, unique: true
  end
end
