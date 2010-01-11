require 'dm-core'
require 'dm-validations'
require 'dm-timestamps'

module Model
  
  db_dir = File.expand_path(File.dirname(__FILE__)+"/../db")

  adapter = DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{db_dir}/camisa.db")
  adapter.resource_naming_convention = DataMapper::NamingConventions::Resource::UnderscoredAndPluralizedWithoutModule
  
  
  class Page
    include DataMapper::Resource
    
    # Properties
    property :id,           Serial
    property :title,        String,   :required => true, :default => "Title"
    property :permalink,    String,   :default => Proc.new { |r, p| r.slug }
    property :content,      Text,     :default => "Enter some content here"
    property :created_at,   DateTime
    property :updated_at,   DateTime
    property :published_at, DateTime
    property :position,     Integer,  :default => Proc.new { |r, p| r.siblings.empty? ?  1 : r.siblings.size.next }
    property :parent_id,    Integer,  :default => 0
    property :show_title,   Boolean,  :default => true

    # Callbacks  
    before :save do
      old_permalink = self.permalink
      new_permalink = (self.parent_id && self.parent) ? (self.parent.permalink + "/" + self.slug) : self.slug
      if new_permalink != old_permalink
        self.permalink = new_permalink
        @new_permalink = true
      end
    end

    after :save do
      if @new_permalink && self.children?
        self.children.each { |child| child.save }
        @new_permalink = false
      end
    end

    # Validations
    validates_is_unique :permalink

    # Default order
    default_scope(:default).update(:order => [:position]) 

    # Associations 
    belongs_to  :parent,    :model => "Page",   :child_key => [:parent_id]
    has n,      :children,  :model => "Page",   :child_key => [:parent_id]

    # Some named_scopes
    def self.published
      all(:published_at.not => nil)
    end

    def self.roots
      all(:parent_id => 0)
    end

    def self.recent(number=1)
      all(:order => [:created_at.desc], :limit => number)
    end

    def self.random(number=1)
      #not currently working - now way to get random records in dm
      #all(:order => ['RAND()'], :limit => number)
    end

    #returns the level of the page, 1 = root
    def level
      level,page = 1, self
      level,page = level.next, page.parent while page.parent
      level
    end

    def ancestors
      page, pages = self, []
      pages << page = page.parent while page.parent
      pages
    end

    # Returns the root node of the tree.
    def root
      page = self
      page = page.parent while page.parent
      page
    end

    def self_and_siblings
      Page.all(:parent_id => self.parent_id)
    end

    def siblings
      Page.all(:parent_id => self.parent_id,:id.not => self.id)
    end

    # Returns a page's permalink based on its title
    def slug
      title.downcase.gsub(/\W/,'-').squeeze('-').chomp('-')
    end

    # Returns a summary of the page
    def summary
      text = self.content[0,400]
    end

    #useful paths for the page
    def path
      "/" + self.permalink
    end

    def edit_path
      "/admin/page/" + self.id.to_s
    end

    def delete_path
      "/admin/page/#{self.id}/delete"
    end

    def new_path
      "/admin/new/page"
    end

    def new_child_path
      "/admin/new/page?section=" + self.id.to_s
    end

    def new_sibling_path
      "/admin/new/page?section=" + self.parent_id.to_s
    end

    #test if a page is a root page
    def root?
      parent_id == nil
    end

    #test if a page is published or not
    def published?
      true unless published_at.nil?
    end

    #test if a page is a draft or not
    def draft?
      published_at.nil?
    end

    #test if a page has children or not
    def children?
      !self.children.empty?
    end
    
    def to_s
      "#{title} ==> #{permalink}"
    end
  end  
  
  DataMapper.auto_upgrade!
end