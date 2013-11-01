# Add product packages relation
Spree::Product.class_eval do
  attr_accessible :is_sold, :discontinue_on

  # Can't use add_search_scope for this as it needs a default argument
  def self.available(available_on = nil, currency = nil)
    stock_items_table = Spree::StockItem.quoted_table_name
    stock_locations_table = Spree::StockLocation.quoted_table_name
    variants_table = Spree::Variant.quoted_table_name
    available_scope = joins(:master => :prices).where("#{Spree::Product.quoted_table_name}.available_on <= ?", available_on || Time.now)
    available_scope = available_scope.where(:is_sold => true)
    available_scope = available_scope.where("#{Spree::Product.quoted_table_name}.discontinue_on is null
                          OR #{Spree::Product.quoted_table_name}.discontinue_on > ?
                          OR
                          (
                            #{Spree::Product.quoted_table_name}.discontinue_on <= ? AND
                            #{quoted_table_name}.id in (
                              SELECT #{variants_table}.product_id FROM #{variants_table}
                                LEFT JOIN #{stock_items_table} ON #{stock_items_table}.variant_id = #{variants_table}.id
                                LEFT JOIN #{stock_locations_table} ON #{stock_items_table}.stock_location_id = #{stock_locations_table}.id
                              WHERE
                                #{variants_table}.product_id = #{quoted_table_name}.id AND
                                #{variants_table}.deleted_at IS NULL AND
                                #{stock_locations_table}.active = ?
                              GROUP BY #{variants_table}.product_id
                              HAVING sum(#{stock_items_table}.count_on_hand) > 0 OR
                                #{stock_items_table}.backorderable = ?
                            )
                          )", available_on || Time.now, available_on || Time.now, true, true)
    unless Spree::Config.show_products_without_price
        available_scope = available_scope.where('spree_prices.currency' => currency || Spree::Config[:currency]).where('spree_prices.amount IS NOT NULL')
    end
    available_scope
  end
  search_scopes << :available

end
