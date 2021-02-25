# frozen_string_literal: true

class Project < ApplicationRecord
  has_many :comments, as: :commentable
  has_many :tasks
end
