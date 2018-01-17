# we need a database

# we need a table to store blog posts

# we need a Post class

#   were gonna need to save blog posts

class Post < ActiveRecord::Base

  ATTRIBUTES = {
    :id => "INTEGER PRIMARY KEY",
    :title => "TEXT",
    :content => "TEXT",
    :author_name => "TEXT"
  }
  # the attributes are our introspection points.

  ATTRIBUTES.keys.each do |key|
    attr_accessor keys
  end

  def destroy
    sql = <<-SQL
      DELETE FROM #{self.class.table_name} WHERE id = ?
    SQL

    DB[:conn].execute(sql, self.id)
  end

  def self.find(id)
    sql = <<-SQL
      SELECT * FROM #{self.table_name} WHERE id = ?
    SQL

    rows = DB[:conn].execute(sql, id)
    if rows.first
      self.reify_from_row(rows.first)
    # reify -- make real - turn array into an object(a post instance)
    else
      nil
    end
  end

  def self.reify_from_row(row)
    self.new.tap do |p|
      ATTRIBUTES.keys.each.with_index do |attribute_name, i|
        p.send("#{attribute_name}=", row[i])
      end
    end
  end

  def self.create_sql
    # {
    #   :id => "INTEGER PRIMARY KEY",
    #   :title => "TEXT",
    #   :content => "TEXT",
    #   :author_name => "TEXT"
    # }

    ATTRIBUTES.collect{|attribute_name, schema|}.join(", ")
    # use join because without, end up with an array as opposed to a string joined by comma's.
      "#{attribute_name} #{schema}"
    end

    # goal to end up with schema :
    # id INTEGER PRIMARY KEY AUTOINCREMENT,
    # title TEXT,
    # content TEXT
    # as a string
  end

  def self.all
    rows = DB.execute("SELECT * FROM posts")
    # [[1, "Default Title", nil]]

    rows.collect do |row|
      p = Post.new
      p.id = row[0]
      p.title = row[1]
      p.content = row[2]
      p
    end
  end

  def self.create_table
    sql = <<-SQL
    CREATE TABLE IF NOT EXISTS #{self.table_name} (
      -- #{self.create_sql}
    );
    SQL

    DB.execute(sql)
  end

  def ==(other_post)
    self.id == other_post.id
    # need it so posts know about object equality.
  end

  def save
    persisted? ? update : insert
  end

  def persisted?
    !!self.id
  end

  def self.attribute_names_for_insert
    # "title, content" #basically every key from the ATTRIBUTES hash except id joined by a comma
    ATTRIBUTES.keys[1..-1].join(",")
  end

  def self.question_marks_for_insert
    (ATTRIBUTES.keys.size-1).times.collect{"?"}.join(",") #will return the number of question marks i need
    4 #=> "?,?,?,?"
  end


  def attribute_values
    # ["Post Title", "Post Content", "Post Author"] -- want to get this back
    ATTRIBUTES.keys[1..-1].collect{|attribute_name| self.send(attribute_name)}
  end

  def self.sql_for_update
    # "title = ? content = ?" can't actually write title... abstracting.
    ATTRIBUTES.keys[1..-1].collect{|attribute_name|"#{attribute_name} = ?"}.join(",")
    # give me all those keys save id, then give me each of those keys as a variable called attribute_name
    # build a string called attribute name = question mark like title = ?, content = ?,
    # and then join those individual strings with a comma
  end

  private
    def INSERT
      sql = <<-SQL
        INSERT INTO #{self.class.table_name} (#{self.class.attribute_names_for_insert}) VALUES (#{self.class.question_marks_for_insert})
      SQL

      # DB[:conn].execute(sql, self.title, self.content) -- will become -->
      DB[:conn].execute(sql, *attribute_values) #<-- there is my splat
      # calling a method -- three_args(*[1,2,3])
      # * is called splatting an array - means take all your elements and send them as individual arguments to your method -
      # very rare- mostly exists in metaprogramming
      self.id = DB[:conn].execute("SELECT last_insert_rowid();").flatten.first
    end

    def update
      sql = <<-SQL
        UPDATE posts SET #{self.class.sql_for_update} WHERE id = ?
      SQL

      # DB[:conn].execute(sql, self.title, self.content, self.id) --- splatting again
      DB[:conn].execute(sql, *attribute_values, self.id)
      # splatting my attribute values(3 arguments), then pass in final argument of self.id
    end

  end

  # def save
  #   sql = <<-SQL
  #     INSERT INTO posts (title, content) VALUES (?, ?)
  #   SQL
  #   DB.execute(sql, self.title, self.content)
  #
  #   id = DB.execute("SELECT last_insert_rowid() FROM posts;").flatten.first
  #   self.id = id
  # end
end

ALL OF THIS SUCKS WAY TOO COMPLICATED -- TOO MANY STEPS -- NEED TO ABSTRACT
NEED TO GO THROUGH AND ABSTRACT AWAY the attr_accessors
class Post
  attr_accessor :id, :title, :content

  def self.table_name
    # want to return "posts"
    # "#{Post.to_s.downcase}s"
    # abstraction is self -- a universal idea - all it means is a measurement of details
    "#{self.to_s.downcase}s"
  end

  # reified - reification is the opposite of abstraction, when you reify you make it more literal.

  def self.find(id)
    sql = <<-SQL
      SELECT * FROM #{self.table_name} WHERE id = ?
    SQL

    rows = DB[:conn].execute(sql)
    self.reify_from_row(rows.first)
    # reify -- make real - turn array into an object(a post instance)
  end

  def self.reify_from_row(row)
    # take the raw array data, instantiate a new post [p],
    # tap returns the instance that we tapped (which is post itself)
    # but before we do that, grab the post data, cast the data into a attributes of a new instance
    # then return it
    self.new.tap do |p|
      p.id = row[0]
      p.title = row[1]
      p.content = row[2]
    end
  end

  def self.create_table
    sql = <<-SQL
    CREATE TABLE IF NOT EXISTS posts (
      -- CREATE TABLE IF NOT EXISTS #{self.table_name}
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT,
      content TEXT
    );
    SQL

    DB.execute(sql)
  end

  private
  # don't want you to be able to access this
    def insert
      # This method is not really saving, just insert, if you run code, inserts multiple times. (However many you try to "save")
      sql = <<-SQL
          INSERT INTO #{self.class.table_name} (title, content) VALUES (?, ?)
      SQL

      DB[:conn].execute(sql, self.title, self.content)
      # After we insert a post, we need to get the primary key out of the DB
      # and set the id of this instance to that value
    self.id = DB[:conn].execute("SELECT last_insert_rowid();").flatten.first
    end
      #
    def update
      sql = <<-SQL
        UPDATE posts SET title = ?, content = ? WHERE id = ?
      SQL

      DB[:conn].execute(sql, self.title, self.content, self.id)
    end


    def save
      # if the post has been saved before, then call UPDATE
      persisted? ? update : insert
      # otherwise, call insert
    end

    def persisted?
      # if it has an id, then I know it's true (!! double bang operand - using the double bang converts an object into it's truthy value)
      !!self.id
    end
  end

end
