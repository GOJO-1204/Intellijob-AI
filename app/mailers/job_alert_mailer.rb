class JobAlertMailer < ApplicationMailer
  def new_matches(user, applications)
    @user = user
    @applications = applications
    mail(to: user.email, subject: "#{applications.size} new job matches for you")
  end
end
