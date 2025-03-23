# frozen_string_literal: true

require "uri"

module Factorix
  module ModPortal
    # Data types for ModPortal API
    module Types
      # Common data types
      Pagination = Data.define(:page, :page_count, :page_size, :count, :links)

      PaginationLinks = Data.define(:first, :prev, :next, :last)

      Release = Data.define(:version, :released_at, :download_url, :file_name, :sha1, :info_json)

      License = Data.define(:description)

      ModEntry = Data.define(
        :name,
        :title,
        :owner,
        :summary,
        :downloads_count,
        :category,
        :thumbnail,
        :score,
        :latest_release,
        :releases
      )

      Mod = Data.define(
        :name,
        :title,
        :owner,
        :summary,
        :downloads_count,
        :category,
        :thumbnail,
        :score,
        :releases
      )

      ModWithDetails = Data.define(
        :name,
        :title,
        :owner,
        :summary,
        :downloads_count,
        :category,
        :thumbnail,
        :score,
        :releases,
        :created_at,
        :updated_at,
        :last_highlighted_at,
        :description,
        :homepage,
        :source_url,
        :tags,
        :license,
        :deprecated,
        :changelog,
        :github_path
      )

      ModList = Data.define(:results, :pagination)
    end
  end
end
