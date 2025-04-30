# frozen_string_literal: true

# system "bin/rails db:fixtures:load"

# Issue(id=1)を取得
issue = Issue.find_by(id: 1)
unless issue
  puts "Issue with id=1 not found."
  exit
end

# ユーザーを30人追加
users = []
10.times do |i|
  user = User.create!(
    login: "user#{i + 1}",
    firstname: "First#{i + 1}",
    lastname: "Last#{i + 1}",
    mail: "user#{i + 1}@example.com",
    password: "password",
    password_confirmation: "password"
  )
  users << user
end
puts "30 users created."

# コメントを50個作成
journals = []
50.times do |i|
  journal = issue.journals.create!(
    user: users[i % users.size], # 順番にユーザーを割り当てる
    notes: "This is comment #{i + 1}."
  )
  journals << journal
end
puts "50 comments created."

# Issue(id=1)に30個のリアクションを追加
users.each do |user|
  Reaction.create!(
    user: user,
    reactable: issue
  )
end
puts "30 reactions added to the issue."

# コメントにそれぞれ30個のリアクションを追加
journals.each do |journal|
  users.each do |user|
    Reaction.create!(
      user: user,
      reactable: journal
    )
  end
end
puts "30 reactions added to each comment."