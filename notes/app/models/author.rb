class Author


  def self.table_name
    "#{self.to_s.downcase}s"
  end

  
end
