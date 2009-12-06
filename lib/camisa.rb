$: << File.dirname(__FILE__) unless $:.include? File.dirname(__FILE__)

require 'rubygems'
require 'trellis'
require 'rdiscount'
require 'db'

include Trellis
  
module Camisa
    
  class Camisa < Application
    home :show_page
    persistent :user
    
    directories = ['/styles', '/javascript', '/images', '/html']
    if ENV['RACK_ENV'] == 'production'
      map_static directories, 'html'
    else
      map_static directories
      logger.level = DEBUG
    end
    
    # App Settings
    SITE_NAME = "CaMiSa"
    USER_NAME = "admin"
    PASSWORD  = "vanilla"
    
    # helper methods
    def admin?
      @user
    end
    
    def protected!
      #stop [ 401, 'You do not have permission to see this page.' ] unless admin?
    end
    
    def user
      @user = false unless @user
      @user
    end
    
    def link_to(url,text,opts={})
      attributes = ""
      opts.each { |key,value| attributes << key.to_s << "=\"" << value << "\" "}
      %[<a href="#{url}" #{attributes}>#{text}</a>]
    end
    
    def shakedown(text)
      text.gsub!(/(?:%\s*)(\w+)(?:\s*[(\r\n)%])/) do |match|
        if @site_page && @site_page.respond_to?($1.to_sym)
          @site_page.send($1.to_sym).to_s
        else
          match
        end
      end
      RDiscount.new(text).to_html
    end
    
    def section_selected(page, parent)
      (page.parent_id == parent.id) ? "selected" : ""
    end
    
    def position_selected(page, position)
      (position == page.position) ? "selected" : ""
    end
    
    def published?(page)
      page.published? ? "checked" : ""
    end
    
    def show_title(page)
      page.show_title ? "checked" : ""
    end
    
    def updated_at(page)
      page.updated_at ? page.updated_at.strftime("<p>Last updated at %I:%M%p on %d %B %Y</p>") : ""
    end
    
    partial :page, %[
      <li id="page_@{ @site_page.id }@" class="page">
        <span class="camisa-page-status">@{ @site_page.published? ? @site_page.updated_at.strftime("%d %b %y") : "DRAFT" }@</span>
        @!{ link_to @site_page.path, @site_page.title }@

        <?rb if admin? ?>
          <div class="camisa-buttons">
            @!{ link_to @site_page.edit_path, "EDIT", {:class, "camisa-edit-button"} }@
            @!{ link_to @site_page.new_child_path,"+ PAGE", {:class, "camisa-add-button"} }@
            @!{ link_to @site_page.delete_path,"DELETE", {:class, "camisa-delete-button"} }@
          </div>
        <?rb end ?>

        <?rb unless @site_page.children.empty? ?>
          <ul>
            <?rb children = admin? ? @site_page.children : @site_page.children.published ?>
            <?rb children.each do |child| ?>
              @!{render_partial(:page, {:site_page, child})}@
            <?rb end ?>
          </ul>
        <?rb end ?>
      </li>
    ], :format => :eruby
    
    partial :page_form, %[
      <div>
      <fieldset id="page-content">
        <legend>Page Content</legend>
        <label for="title" class="hidden">Title</label>
        <input type="text" name="page[title]" id="title" value="@{ @site_page.title }@" />
        <input type="checkbox" name="show_title" id="show_title" value="true" checked="@{ show_title(@site_page)}@" />
        <label for="show_title">show/hide title</label>
        <label for="content" class="hidden">Content</label>
        <textarea rows="28" cols="80" name="page[content]" id="content">@{ @site_page.content }@</textarea>
      </fieldset>
      <fieldset id="page-info">
        <legend>Page Info</legend>
        <label for="parent_id">Section:
        <select id="parent_id" name="page[parent_id]">
          <option value="">Main Section</option>
          <?rb (Model::Page.all - [@site_page]).each do |parent| ?>
            <option value="@{ parent.id }@" selected="@{ section_selected(@site_page, parent) }@">
              @{ parent.title }@
            </option>
          <?rb end ?>
        </select>
        </label>
        <label for="position">Position:
          <select id="position" name="page[position]">
          <?rb 1.upto(@site_page.siblings.size.next) do |position| ?>
            <option value="@{ position }@" selected="@{ position_selected(@site_page, position) }@">
              @{position.to_s}@
            </option>
          <?rb end ?>
          </select>
        </label>
        <label for="publish">Publish this page:
          <input type="checkbox" name="publish" id="publish" value="true" checked="@{ published?(@site_page) }@">
        </label>

        <input type="submit" value="Save" class="camisa-button">
        or <a href="/admin/pages" class="cancel">cancel</a>

        @!{ updated_at(@site_page) }@
      </fieldset>
      </div>
    ], :format => :eruby
    
    layout :main, %[
      <html xml:lang="en" lang="en" xmlns:trellis="http://trellisframework.org/schema/trellis_1_0_0.xsd" xmlns="http://www.w3.org/1999/xhtml">
      <head>
      	<meta content="text/html; charset=utf-8" http-equiv="Content-Type" />
        <link rel="stylesheet" type="text/css" href="/styles/camisa.css" />
        <title>@{@page_name}@</title>
      </head>
      <body>
        <h1>@{Camisa::Camisa::SITE_NAME}@</h1>
        <?rb if admin? ?>
        	<div id="camisa-dashboard">
           	<h2>Logged in as @{@application.user}@</h2>
           	<ul class="camisa-buttons">
             	<li><a href="/admin/pages">Pages</a></li>
             	<li><a href="/admin/login/events/logout">Logout</a></li>
           	</ul>
        	</div>
        <?rb end ?>
        @!{@body}@
      </body>
      </html>
     ], :format => :eruby
  end

  # -- Login --
  # Poor man's session based login/logout
  class Login < Trellis::Page
    route '/admin/login'
  
    def on_submit_from_login
      if params[:login_name] == Camisa::USER_NAME && params[:login_password] == Camisa::PASSWORD
        @application.user = Camisa::USER_NAME
      end
      redirect "/admin/pages"
    end
    
    def on_logout
      @application.user = false
      self
    end
    
    template %[
      <trellis:form tid="login" method="post" class="camisa-login">
  	    <label for="name">Username:</label>
  	    <trellis:text_field tid="name" id="name" />
  	    <label for="password">Password:</label>
  	    <trellis:text_field tid="password" id="password" />
  	    <trellis:submit tid="add" value="Login">
      </trellis:form>   
    ], :format => :html, :layout => :main
  end
   
  # -- Show Page --
  # Displays the content pages
  class ShowPage < Trellis::Page
    route '/:permalink'
    
    def get
      @site_page = @permalink ? Model::Page.first(:permalink => @permalink) : Model::Page.roots.published.first
      @site_page ? self : redirect("/admin/pages")
    end
  
    template %[
      <div>
        <?rb if @site_page.show_title ?>
          <h2>@{@site_page.title}@</h2>
        <?rb end ?>

        @!{ shakedown(@site_page.content).gsub('h1>','h3>').gsub('h2>','h4>') }@

        <?rb if admin? ?>
          <ul class="camisa-buttons">
            <li>@!{ link_to @site_page.edit_path,"Edit", {:class, "camisa-edit-button"} }@</li>
            <li>@!{ link_to @site_page.new_sibling_path,"+ Sibling",{:class, "camisa-add-button"} }@</li>
            <li>@!{ link_to @site_page.new_child_path,"+ Child",{:class, "camisa-add-button"} }@</li>
            <li>@!{ link_to @site_page.delete_path,"Delete",{:class, "camisa-delete-button"} }@</li>
          </ul>
        <?rb end ?>
      </div>
     ], :format => :eruby, :layout => :main
  end
  
  # -- DashBoard Page --
  class Pages < Trellis::Page
    route '/admin/pages'

    def get
      @site_pages = @application.admin? ? Model::Page.roots : Model::Page.roots.published
      self
    end
    
    template %[
      <div>     
        <h2>Sitemap</h2>
        <?rb if admin? ?>
          @!{ link_to("/admin/new/page", "+ page", { :class, "camisa-button" }) }@
        <?rb end ?>
        
        <?rb if @site_pages ?>
          <ul id="pages" class="camisa-pages">
          <?rb @site_pages.each do |site_page| ?>
            <!-- @!{site_page.title}@ -->
            @!{ render_partial(:page, {:site_page, site_page}) }@
          <?rb end ?>
          </ul>
        <?rb else ?>
          <p>There are no pages yet!</p>
        <?rb end ?>
      </div>
    ], :format => :eruby, :layout => :main
  end

  # -- New CMS Page --
  class NewPage < Trellis::Page
    route '/admin/new/page'
    
    def get
      @site_page = Model::Page.new(:parent_id => params[:section])
      self
    end
    
    def on_submit_from_new
      @site_page = Model::Page.new(params[:page])
      @site_page.show_title = false unless params[:show_title]
      @site_page.published_at = params[:publish] ?  Time.now : nil
      if @site_page.save
        redirect @site_page.path
      else
        redirect "/admin/pages"
      end
    end
        
    template %[
      <trellis:form tid="new" method="post" class="camisa">
         @!{ render_partial(:page_form, {:site_page, @site_page}) }@
      </trellis:form>
    ], :format => :eruby, :layout => :main
  end

  # -- Edit CMS Page --
  class EditPage < Trellis::Page
    route '/admin/page/:id'
    
    def get
      @site_page = Model::Page.get(@id)
      @site_page ? self : redirect("/admin/pages")
    end
    
    def on_submit_from_edit
      site_page = Model::Page.get(@id)
      site_page.show_title = false unless params[:show_title]
      #site_page.published_at = params[:publish] ?  Time.now : nil    
      
      if site_page.update(params[:page])
        redirect site_page.path
      else
        redirect "/admin/pages"
      end
    end
    
    template %[
      <trellis:form tid="edit" method="post" class="camisa">
         @!{ render_partial(:page_form, {:site_page, @site_page}) }@
      </trellis:form> 
    ], :format => :eruby, :layout => :main
  end  
  
  # -- Delete CMS Page --
  class DeletePage < Trellis::Page
    route '/admin/page/:id/delete'
    
    def get
      @site_page = Model::Page.get(@id)
      self
    end
    
    def on_submit_from_delete
      site_page = Model::Page.get(@id)
      site_page.children.destroy! if site_page.children
      site_page.destroy
      redirect "/admin/pages"
    end
    
    template %[
      <h2>@{ @site_page.title }@</h2>
      <h3>Are you sure you want to delete this page?</h3>
      <trellis:form tid="delete" method="post" class="camisa">
        <input type="submit" value="Delete" class="camisa-button">
       or @!{ link_to "/admin/pages", "Cancel" }@
      </trellis:form>
    ], :format => :eruby, :layout => :main
  end
  
  if __FILE__ == $PROGRAM_NAME
    web_app = Camisa.new
    web_app.start 3000
  end
end