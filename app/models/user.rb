class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_one :profile, dependent: :destroy
  has_many :job_applications, dependent: :destroy
  has_many :jobs, through: :job_applications

  after_create { create_profile! }
end
