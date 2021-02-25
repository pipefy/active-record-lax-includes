# frozen_string_literal: true

class Task < ApplicationRecord
  has_many :comments, as: :commentable
  belongs_to :project
end
