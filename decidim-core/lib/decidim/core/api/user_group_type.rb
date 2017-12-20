# frozen_string_literal: true

module Decidim
  # This type represents a UserGroup
  UserGroupType = GraphQL::ObjectType.define do
    name "UserGroup"
    description "A user group"

    interfaces [
      Decidim::AuthorInterface
    ]

    field :id, !types.ID, "The user group's id"

    field :name, !types.String, "The user group's name"

    field :nickname, !types.String, "User groups have no nickname" do
      resolve ->(obj, _args, _ctx) { UserGroupPresenter.new(obj).nickname }
    end

    field :avatarUrl, !types.String, "The user's avatar url" do
      resolve ->(obj, _args, _ctx) { UserGroupPresenter.new(obj).avatar_url }
    end

    field :isVerified, !types.Boolean, "Whether the user group is verified or not", property: :verified?

    field :deleted, !types.Boolean, "Whether the user group's has been deleted or not" do
      resolve ->(obj, _args, _ctx) { UserGroupPresenter.new(obj).deleted? }
    end

    field :isUser, !types.Boolean, "User groups are not users" do
      resolve ->(_obj, _args, _ctx) { false }
    end
  end
end
