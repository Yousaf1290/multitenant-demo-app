class CreateCompanies < ActiveRecord::Migration[8.1]
  def change
    create_table :companies do |t|
      t.string :name, null: false
      t.string :slug, null: false, index: { unique: true }
      t.string :database_name, null: false, index: { unique: true }
      t.string :status, null: false, default: "active"
      t.string :currency, null: false, default: "USD"
      t.string :catalog_csv_path

      t.timestamps
    end
  end
end
