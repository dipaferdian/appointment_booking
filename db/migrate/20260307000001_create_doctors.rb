class CreateDoctors < ActiveRecord::Migration[8.1]
  def change
    create_table :doctors do |t|
      t.string :external_id, null: false
      t.string :name, null: false
      t.string :specialization

      t.timestamps
    end

    add_index :doctors, :external_id, unique: true
  end
end
