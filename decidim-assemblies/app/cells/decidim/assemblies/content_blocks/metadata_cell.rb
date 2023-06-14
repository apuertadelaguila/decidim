# frozen_string_literal: true

module Decidim
  module Assemblies
    module ContentBlocks
      class MetadataCell < Decidim::ContentBlocks::ParticipatorySpaceMetadataCell
        private

        def metadata_items = %w(meta_scope developer_group local_area target participatory_scope participatory_structure area_name)

        def space_presenter = AssemblyPresenter

        def translations_scope = "decidim.assemblies.assemblies.description"
      end
    end
  end
end
