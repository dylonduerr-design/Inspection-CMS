class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  enum role: { inspector: 0, qc: 1 }

  has_many :reports, dependent: :destroy       
  has_many :imported_reports, dependent: :destroy
end
